import { useEffect, useMemo, useState } from 'react';
import { Link } from 'react-router';
import { useLiabilities } from '../hooks/useLiabilities';
import StatCard from '../components/StatCard';
import { Scale, Flame, Snowflake, CalendarClock, TrendingDown, ExternalLink } from 'lucide-react';

const fmt = (n) => `৳${Math.round(Number(n || 0)).toLocaleString()}`;
const SETTINGS_KEY = 'debt_payoff_settings_v1';

function loadSettings() {
  try {
    return { strategy: 'avalanche', extraMonthly: 0, ...JSON.parse(localStorage.getItem(SETTINGS_KEY) || '{}') };
  } catch {
    return { strategy: 'avalanche', extraMonthly: 0 };
  }
}

// Snowball (smallest balance first) / avalanche (highest rate first) payoff
// simulation: each month, every debt gets its minimum payment; whatever
// extra is available (user's extra + payments freed up by cleared debts)
// goes entirely to the current top-priority debt.
function simulatePayoff(debts, strategy, extraMonthly) {
  let working = debts.map(d => ({ ...d, balance: Number(d.remaining_balance), paidOffMonth: null }));
  const order = strategy === 'snowball'
    ? [...working].sort((a, b) => a.balance - b.balance)
    : [...working].sort((a, b) => Number(b.interest_rate || 0) - Number(a.interest_rate || 0));

  let month = 0;
  let totalInterest = 0;
  let freedMinPayments = 0;
  const cap = 600; // 50 years safety cap
  while (order.some(d => d.balance > 0.5) && month < cap) {
    month++;
    let pool = Number(extraMonthly) + freedMinPayments;
    for (const d of order) {
      if (d.balance <= 0.5) continue;
      const monthlyRate = Number(d.interest_rate || 0) / 12 / 100;
      const interest = d.balance * monthlyRate;
      totalInterest += interest;
      let payment = Number(d.min_payment) || Math.max(d.balance * 0.03, d.balance / 12);
      payment = Math.min(payment, d.balance + interest);
      d.balance = d.balance + interest - payment;
      if (d.balance <= 0.5) {
        d.balance = 0;
        d.paidOffMonth = month;
        freedMinPayments += payment;
      }
    }
    // Throw the whole pool at the top-priority remaining debt.
    const target = order.find(d => d.balance > 0.5);
    if (target && pool > 0) {
      const applied = Math.min(pool, target.balance);
      target.balance -= applied;
      if (target.balance <= 0.5) {
        target.balance = 0;
        target.paidOffMonth = month;
        freedMinPayments += (Number(target.min_payment) || 0);
      }
    }
  }
  return { months: month, totalInterest, order };
}

export default function DebtPayoff() {
  const { liabilities, loading, updateLiability } = useLiabilities();
  const [settings, setSettings] = useState(loadSettings);

  useEffect(() => { localStorage.setItem(SETTINGS_KEY, JSON.stringify(settings)); }, [settings]);

  const debts = useMemo(
    () => liabilities.filter(l => !l.counterparty && l.type !== 'loan_given' && Number(l.remaining_balance) > 0),
    [liabilities]
  );

  const baseline = useMemo(() => debts.length ? simulatePayoff(debts, settings.strategy, 0) : null, [debts, settings.strategy]);
  const withExtra = useMemo(
    () => debts.length && settings.extraMonthly > 0 ? simulatePayoff(debts, settings.strategy, settings.extraMonthly) : null,
    [debts, settings.strategy, settings.extraMonthly]
  );

  const totalDebt = debts.reduce((s, d) => s + Number(d.remaining_balance), 0);
  const totalMinPayment = debts.reduce((s, d) => s + (Number(d.min_payment) || Math.max(Number(d.remaining_balance) * 0.03, Number(d.remaining_balance) / 12)), 0);

  const handleMinPayment = async (debt, value) => {
    try {
      await updateLiability(debt.id, { min_payment: value === '' ? null : parseFloat(value) });
    } catch (err) {
      alert('Error saving minimum payment: ' + err.message);
    }
  };

  if (loading) return <div className="text-foreground/50 p-6">Loading debts...</div>;

  return (
    <div className="space-y-6 animate-in">
      <div>
        <h1 className="text-2xl font-bold text-foreground">Debt Payoff Planner</h1>
        <p className="text-foreground/40 text-sm mt-1">Snowball or avalanche your loans, credit cards and installments to debt-free.</p>
      </div>

      {debts.length === 0 ? (
        <div className="text-center py-12 border border-foreground/5 rounded-2xl bg-white/[0.02]">
          <Scale className="mx-auto text-foreground/20 mb-4" size={48} />
          <h3 className="text-foreground/60 font-medium">No active debts</h3>
          <p className="text-foreground/40 text-sm mt-1">Loans and credit cards from <Link to="/liabilities" className="text-cyan-400 hover:underline">Liabilities</Link> with a remaining balance show up here.</p>
        </div>
      ) : (
        <>
          <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
            <StatCard title="Total Debt" value={fmt(totalDebt)} icon={Scale} gradient={["#f87171", "#ef4444"]} iconBg="bg-red-500/10" />
            <StatCard title="Total Min. Payment/mo" value={fmt(totalMinPayment)} icon={CalendarClock} gradient={["#f59e0b", "#d97706"]} iconBg="bg-amber-500/10" />
            <StatCard title="Debt-Free In" value={`${(withExtra || baseline).months} mo`} icon={TrendingDown} gradient={["#34d399", "#10b981"]} iconBg="bg-emerald-500/10" />
          </div>

          <div className="bg-card border border-foreground/10 rounded-2xl p-6 flex flex-wrap items-end gap-4">
            <div>
              <label className="block text-sm text-foreground/60 mb-1.5">Strategy</label>
              <div className="flex gap-2">
                <button onClick={() => setSettings(s => ({ ...s, strategy: 'avalanche' }))} className={`flex items-center gap-1.5 px-4 py-2.5 rounded-xl text-sm font-medium border transition-all ${settings.strategy === 'avalanche' ? 'bg-red-500/15 border-red-500/40 text-red-400' : 'bg-foreground/5 border-foreground/10 text-white/50'}`}>
                  <Flame size={15} /> Avalanche (highest rate first)
                </button>
                <button onClick={() => setSettings(s => ({ ...s, strategy: 'snowball' }))} className={`flex items-center gap-1.5 px-4 py-2.5 rounded-xl text-sm font-medium border transition-all ${settings.strategy === 'snowball' ? 'bg-cyan-500/15 border-cyan-500/40 text-cyan-400' : 'bg-foreground/5 border-foreground/10 text-white/50'}`}>
                  <Snowflake size={15} /> Snowball (smallest balance first)
                </button>
              </div>
            </div>
            <div>
              <label className="block text-sm text-foreground/60 mb-1.5">Extra Monthly Payment (৳)</label>
              <input type="number" step="0.01" value={settings.extraMonthly} onChange={e => setSettings(s => ({ ...s, extraMonthly: parseFloat(e.target.value) || 0 }))} className="w-48 bg-muted border border-foreground/10 rounded-xl px-4 py-2.5 text-foreground focus:outline-none focus:border-cyan-500/50" />
            </div>
          </div>

          {withExtra && baseline && (
            <div className="bg-emerald-500/[0.07] border border-emerald-500/20 rounded-2xl p-5 flex items-start gap-3">
              <TrendingDown className="text-emerald-400 shrink-0 mt-0.5" size={20} />
              <p className="text-sm text-foreground/70">
                With {fmt(settings.extraMonthly)}/month extra, you'll be debt-free in{' '}
                <strong className="text-emerald-400">{withExtra.months} months</strong> instead of {baseline.months}, saving{' '}
                <strong className="text-emerald-400">{fmt(baseline.totalInterest - withExtra.totalInterest)}</strong> in interest.
              </p>
            </div>
          )}

          <div className="bg-card border border-foreground/10 rounded-2xl overflow-hidden">
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead>
                  <tr className="bg-foreground/5 border-b border-foreground/10">
                    <th className="text-left py-3 px-5 text-foreground/60 font-medium">Order</th>
                    <th className="text-left py-3 px-5 text-foreground/60 font-medium">Debt</th>
                    <th className="text-right py-3 px-5 text-foreground/60 font-medium">Balance</th>
                    <th className="text-right py-3 px-5 text-foreground/60 font-medium">Rate</th>
                    <th className="text-right py-3 px-5 text-foreground/60 font-medium">Min. Payment</th>
                    <th className="text-right py-3 px-5 text-foreground/60 font-medium">Paid Off In</th>
                  </tr>
                </thead>
                <tbody>
                  {(withExtra || baseline).order.map((d, i) => (
                    <tr key={d.id} className="border-b border-foreground/5 hover:bg-white/[0.02]">
                      <td className="py-3 px-5 text-foreground/40">#{i + 1}</td>
                      <td className="py-3 px-5 text-foreground font-medium">{d.name}</td>
                      <td className="py-3 px-5 text-right text-foreground">{fmt(d.remaining_balance)}</td>
                      <td className="py-3 px-5 text-right text-foreground/60">{d.interest_rate || 0}%</td>
                      <td className="py-3 px-5 text-right">
                        <input
                          type="number" step="0.01" placeholder={fmt(Math.max(Number(d.remaining_balance) * 0.03, Number(d.remaining_balance) / 12))}
                          defaultValue={d.min_payment ?? ''}
                          onBlur={e => handleMinPayment(d, e.target.value)}
                          className="w-28 bg-muted border border-foreground/10 rounded-lg px-2.5 py-1.5 text-foreground text-right text-xs focus:outline-none focus:border-cyan-500/50"
                        />
                      </td>
                      <td className="py-3 px-5 text-right text-emerald-400 font-medium">{d.paidOffMonth ? `Month ${d.paidOffMonth}` : '—'}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
            <div className="px-5 py-3 border-t border-foreground/5 flex items-center justify-between text-xs text-foreground/40">
              <span>Blank minimum payments default to ~3% of balance for the simulation — set them for accuracy.</span>
              <Link to="/liabilities" className="flex items-center gap-1 text-cyan-400 hover:underline shrink-0 ml-4">
                Log a payment <ExternalLink size={12} />
              </Link>
            </div>
          </div>
        </>
      )}
    </div>
  );
}

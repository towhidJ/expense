import { useMemo, useState } from 'react';
import { useEntityTable } from '../hooks/useEntityTable';
import StatCard from '../components/StatCard';
import { Calculator, Save, Trash2, ChevronDown, Wallet, CalendarClock, TrendingDown } from 'lucide-react';

const fmt = (n) => `৳${Math.round(Number(n || 0)).toLocaleString()}`;

// Standard reducing-balance EMI amortization, with an optional flat extra
// monthly payment applied on top of the EMI every month.
function buildSchedule(principal, annualRate, tenureMonths, extraMonthly = 0) {
  const r = annualRate / 12 / 100;
  const n = tenureMonths;
  const emi = r === 0 ? principal / n : (principal * r * Math.pow(1 + r, n)) / (Math.pow(1 + r, n) - 1);

  const rows = [];
  let balance = principal;
  let month = 0;
  while (balance > 0.5 && month < n * 3) {
    month++;
    const interest = balance * r;
    let principalPaid = emi - interest + extraMonthly;
    if (principalPaid > balance) principalPaid = balance;
    balance -= principalPaid;
    rows.push({ month, payment: interest + principalPaid, interest, principal: principalPaid, balance: Math.max(balance, 0) });
    if (balance <= 0.5) break;
  }
  const totalInterest = rows.reduce((s, r2) => s + r2.interest, 0);
  const totalPayment = rows.reduce((s, r2) => s + r2.payment, 0);
  return { emi, rows, totalInterest, totalPayment, months: rows.length };
}

export default function Emi() {
  const { rows: scenarios, loading, addRow, deleteRow } = useEntityTable('emi_scenarios');
  const [principal, setPrincipal] = useState('500000');
  const [rate, setRate] = useState('12');
  const [tenure, setTenure] = useState('36');
  const [extra, setExtra] = useState('0');
  const [showAll, setShowAll] = useState(false);
  const [name, setName] = useState('');
  const [saving, setSaving] = useState(false);

  const P = parseFloat(principal) || 0;
  const R = parseFloat(rate) || 0;
  const N = parseInt(tenure) || 0;
  const E = parseFloat(extra) || 0;

  const base = useMemo(() => (P > 0 && N > 0 ? buildSchedule(P, R, N) : null), [P, R, N]);
  const withExtra = useMemo(() => (P > 0 && N > 0 && E > 0 ? buildSchedule(P, R, N, E) : null), [P, R, N, E]);

  const handleSave = async (e) => {
    e.preventDefault();
    if (!base) return;
    setSaving(true);
    try {
      await addRow({
        name: name.trim() || `Loan of ${fmt(P)}`,
        principal: P,
        interest_rate: R,
        tenure_months: N,
        start_date: new Date().toISOString().split('T')[0]
      });
      setName('');
    } catch (err) {
      alert('Error saving scenario: ' + err.message);
    }
    setSaving(false);
  };

  const loadScenario = (s) => {
    setPrincipal(String(s.principal));
    setRate(String(s.interest_rate));
    setTenure(String(s.tenure_months));
    setExtra('0');
  };

  return (
    <div className="space-y-6 animate-in">
      <div>
        <h1 className="text-2xl font-bold text-white">EMI Calculator</h1>
        <p className="text-white/40 text-sm mt-1">Work out a loan's monthly payment, amortization schedule and prepayment savings.</p>
      </div>

      <div className="bg-[#1a1a2e] border border-white/10 rounded-2xl p-6">
        <form onSubmit={handleSave} className="grid grid-cols-1 sm:grid-cols-4 gap-4">
          <div>
            <label className="block text-sm text-white/60 mb-1">Loan Amount (৳)</label>
            <input type="number" step="0.01" value={principal} onChange={e => setPrincipal(e.target.value)} className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-cyan-500/50" />
          </div>
          <div>
            <label className="block text-sm text-white/60 mb-1">Annual Interest Rate (%)</label>
            <input type="number" step="0.01" value={rate} onChange={e => setRate(e.target.value)} className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-cyan-500/50" />
          </div>
          <div>
            <label className="block text-sm text-white/60 mb-1">Tenure (months)</label>
            <input type="number" value={tenure} onChange={e => setTenure(e.target.value)} className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-cyan-500/50" />
          </div>
          <div>
            <label className="block text-sm text-white/60 mb-1">Extra Monthly Payment (৳)</label>
            <input type="number" step="0.01" value={extra} onChange={e => setExtra(e.target.value)} placeholder="Optional" className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-cyan-500/50" />
          </div>
          <div className="sm:col-span-3">
            <label className="block text-sm text-white/60 mb-1">Save as scenario (optional name)</label>
            <input type="text" value={name} onChange={e => setName(e.target.value)} placeholder="e.g. Car loan — City Bank" className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-cyan-500/50" />
          </div>
          <div className="flex items-end">
            <button type="submit" disabled={!base || saving} className="w-full flex items-center justify-center gap-2 bg-cyan-500 hover:bg-cyan-600 text-white px-4 py-2.5 rounded-xl transition-colors shadow-lg shadow-cyan-500/20 disabled:opacity-50">
              <Save size={16} /> Save
            </button>
          </div>
        </form>
      </div>

      {base && (
        <>
          <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
            <StatCard title="Monthly EMI" value={fmt(base.emi)} icon={Wallet} gradient={["#22d3ee", "#06b6d4"]} iconBg="bg-cyan-500/10" />
            <StatCard title="Total Interest" value={fmt(base.totalInterest)} icon={CalendarClock} gradient={["#f87171", "#ef4444"]} iconBg="bg-red-500/10" />
            <StatCard title="Total Payment" value={fmt(base.totalPayment)} icon={Calculator} gradient={["#a78bfa", "#8b5cf6"]} iconBg="bg-purple-500/10" />
          </div>

          {withExtra && (
            <div className="bg-emerald-500/[0.07] border border-emerald-500/20 rounded-2xl p-5 flex items-start gap-3">
              <TrendingDown className="text-emerald-400 shrink-0 mt-0.5" size={20} />
              <p className="text-sm text-white/70">
                Paying an extra <strong className="text-white">{fmt(E)}</strong>/month clears the loan in{' '}
                <strong className="text-emerald-400">{withExtra.months} months</strong> instead of {base.months}, saving{' '}
                <strong className="text-emerald-400">{fmt(base.totalInterest - withExtra.totalInterest)}</strong> in interest.
              </p>
            </div>
          )}

          <div className="bg-[#1a1a2e] border border-white/10 rounded-2xl overflow-hidden">
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead>
                  <tr className="bg-white/5 border-b border-white/10">
                    <th className="text-left py-3 px-5 text-white/60 font-medium">Month</th>
                    <th className="text-right py-3 px-5 text-white/60 font-medium">Payment</th>
                    <th className="text-right py-3 px-5 text-white/60 font-medium">Principal</th>
                    <th className="text-right py-3 px-5 text-white/60 font-medium">Interest</th>
                    <th className="text-right py-3 px-5 text-white/60 font-medium">Balance</th>
                  </tr>
                </thead>
                <tbody>
                  {(showAll ? base.rows : base.rows.slice(0, 12)).map(row => (
                    <tr key={row.month} className="border-b border-white/5 hover:bg-white/[0.02]">
                      <td className="py-2.5 px-5 text-white/70">{row.month}</td>
                      <td className="py-2.5 px-5 text-right text-white">{fmt(row.payment)}</td>
                      <td className="py-2.5 px-5 text-right text-emerald-400/80">{fmt(row.principal)}</td>
                      <td className="py-2.5 px-5 text-right text-red-400/70">{fmt(row.interest)}</td>
                      <td className="py-2.5 px-5 text-right text-white/60">{fmt(row.balance)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
            {base.rows.length > 12 && (
              <button onClick={() => setShowAll(o => !o)} className="w-full flex items-center justify-center gap-1.5 py-3 text-sm text-cyan-400 hover:bg-white/5 transition-colors">
                {showAll ? 'Show less' : `Show all ${base.rows.length} months`} <ChevronDown className={`w-4 h-4 transition-transform ${showAll ? 'rotate-180' : ''}`} />
              </button>
            )}
          </div>
        </>
      )}

      {!loading && scenarios.length > 0 && (
        <div>
          <h2 className="text-white font-semibold mb-3">Saved Scenarios</h2>
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
            {scenarios.map(s => (
              <div key={s.id} className="bg-[#1a1a2e] border border-white/10 rounded-2xl p-5 hover:border-white/20 transition-all">
                <div className="flex justify-between items-start mb-2">
                  <h3 className="text-white font-medium">{s.name}</h3>
                  <button onClick={() => { if (confirm(`Delete "${s.name}"?`)) deleteRow(s.id).catch(err => alert(err.message)); }} className="text-white/30 hover:text-red-400 p-1 rounded-lg hover:bg-red-500/10">
                    <Trash2 size={14} />
                  </button>
                </div>
                <p className="text-white/40 text-xs mb-3">{fmt(s.principal)} · {s.interest_rate}% · {s.tenure_months}mo</p>
                <button onClick={() => loadScenario(s)} className="text-xs bg-cyan-500/15 text-cyan-400 hover:bg-cyan-500/25 px-3 py-1.5 rounded-lg font-medium transition-colors">
                  Load into calculator
                </button>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}

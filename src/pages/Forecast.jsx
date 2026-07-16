import { useState, useMemo } from 'react';
import { useCashflowForecast } from '../hooks/useCashflowForecast';
import { useAccounts } from '../context/AccountContext';
import StatCard from '../components/StatCard';
import ChartCard from '../components/ChartCard';
import { Wallet, TrendingUp, TrendingDown, LineChart, AlertTriangle, Repeat } from 'lucide-react';
import { AreaChart, Area, XAxis, YAxis, Tooltip, CartesianGrid, ResponsiveContainer, ReferenceLine } from 'recharts';

const fmt = (n) => `৳${Math.round(Number(n || 0)).toLocaleString()}`;

const CustomTooltip = ({ active, payload, label }) => {
  if (active && payload && payload.length) {
    return (
      <div className="bg-popover border border-border rounded-xl p-3 shadow-xl text-popover-foreground">
        <p className="text-muted-foreground text-xs mb-1">{label}</p>
        {payload.map((p, i) => (
          <p key={i} className="text-sm font-medium" style={{ color: p.color }}>
            {p.name}: ৳{Math.round(p.value).toLocaleString()}
          </p>
        ))}
      </div>
    );
  }
  return null;
};

export default function Forecast() {
  const { history, averages, recurringMonthly, recurring, loading } = useCashflowForecast();
  const { accounts } = useAccounts();
  const [adjIncome, setAdjIncome] = useState('');
  const [adjExpense, setAdjExpense] = useState('');

  const currentBalance = useMemo(
    () => accounts.reduce((s, a) => s + Number(a.current_balance || 0), 0),
    [accounts]
  );

  const projection = useMemo(() => {
    const income = averages.income + (parseFloat(adjIncome) || 0);
    const expense = averages.expense + (parseFloat(adjExpense) || 0);
    const net = income - expense;
    const rows = [{ name: 'Now', balance: currentBalance, income: null, expense: null, net: null }];
    let balance = currentBalance;
    const now = new Date();
    for (let i = 1; i <= 6; i++) {
      const d = new Date(now.getFullYear(), now.getMonth() + i, 1);
      balance += net;
      rows.push({
        name: d.toLocaleDateString('en-US', { month: 'short', year: '2-digit' }),
        income, expense, net, balance
      });
    }
    return rows;
  }, [averages, adjIncome, adjExpense, currentBalance]);

  const firstNegative = projection.find(r => r.balance < 0);
  const monthlyNet = averages.income - averages.expense + (parseFloat(adjIncome) || 0) - (parseFloat(adjExpense) || 0);

  if (loading) return <div className="text-white/50 p-6">Building your forecast...</div>;

  return (
    <div className="space-y-6 animate-in">
      <div>
        <h1 className="text-2xl font-bold text-white">Cashflow Forecast</h1>
        <p className="text-white/40 text-sm mt-1">
          Where your balance is heading over the next 6 months, based on your last {averages.sampleSize || 1} month{(averages.sampleSize || 1) > 1 ? 's' : ''} of activity.
        </p>
      </div>

      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        <StatCard title="Current Balance" value={fmt(currentBalance)} icon={Wallet} gradient={["#22d3ee", "#06b6d4"]} iconBg="bg-cyan-500/10" />
        <StatCard title="Avg Monthly Income" value={fmt(averages.income)} icon={TrendingUp} gradient={["#34d399", "#10b981"]} iconBg="bg-emerald-500/10" />
        <StatCard title="Avg Monthly Expense" value={fmt(averages.expense)} icon={TrendingDown} gradient={["#f87171", "#ef4444"]} iconBg="bg-red-500/10" />
        <StatCard
          title="Projected Monthly Net"
          value={`${monthlyNet >= 0 ? '+' : '−'}${fmt(Math.abs(monthlyNet))}`}
          icon={LineChart}
          gradient={monthlyNet >= 0 ? ["#34d399", "#10b981"] : ["#f87171", "#ef4444"]}
          iconBg={monthlyNet >= 0 ? 'bg-emerald-500/10' : 'bg-red-500/10'}
        />
      </div>

      {firstNegative && (
        <div className="flex items-start gap-3 bg-red-500/10 border border-red-500/20 rounded-2xl p-4">
          <AlertTriangle className="text-red-400 shrink-0 mt-0.5" size={20} />
          <div>
            <p className="text-red-400 font-medium text-sm">Balance projected to go negative in {firstNegative.name}</p>
            <p className="text-white/50 text-xs mt-1">
              At the current rate you'd be short by {fmt(Math.abs(firstNegative.balance))}. Consider cutting expenses or adding income before then.
            </p>
          </div>
        </div>
      )}

      <ChartCard title="Projected Balance" subtitle="Next 6 months at your current income/expense rate">
        <ResponsiveContainer width="100%" height={300}>
          <AreaChart data={projection}>
            <defs>
              <linearGradient id="forecastFill" x1="0" y1="0" x2="0" y2="1">
                <stop offset="0%" stopColor="#8b5cf6" stopOpacity={0.35} />
                <stop offset="100%" stopColor="#8b5cf6" stopOpacity={0} />
              </linearGradient>
            </defs>
            <CartesianGrid strokeDasharray="3 3" stroke="#ffffff08" />
            <XAxis dataKey="name" tick={{ fill: '#ffffff40', fontSize: 12 }} axisLine={false} tickLine={false} />
            <YAxis tick={{ fill: '#ffffff40', fontSize: 12 }} axisLine={false} tickLine={false} width={80} />
            <Tooltip content={<CustomTooltip />} />
            <ReferenceLine y={0} stroke="#ef4444" strokeDasharray="4 4" />
            <Area type="monotone" dataKey="balance" name="Balance" stroke="#8b5cf6" strokeWidth={2}
              fill="url(#forecastFill)" dot={{ r: 3, fill: '#8b5cf6', strokeWidth: 0 }} />
          </AreaChart>
        </ResponsiveContainer>
      </ChartCard>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <div className="lg:col-span-2 bg-[#1a1a2e] border border-white/10 rounded-2xl overflow-hidden">
          <div className="p-5 border-b border-white/10">
            <h3 className="text-white font-semibold">Month by Month</h3>
          </div>
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="bg-white/5 border-b border-white/10">
                  <th className="text-left py-3 px-5 text-white/60 font-medium">Month</th>
                  <th className="text-right py-3 px-5 text-white/60 font-medium">Income</th>
                  <th className="text-right py-3 px-5 text-white/60 font-medium">Expense</th>
                  <th className="text-right py-3 px-5 text-white/60 font-medium">Net</th>
                  <th className="text-right py-3 px-5 text-white/60 font-medium">Ending Balance</th>
                </tr>
              </thead>
              <tbody>
                {projection.slice(1).map(row => (
                  <tr key={row.name} className="border-b border-white/5 hover:bg-white/[0.02] transition-colors">
                    <td className="py-3 px-5 text-white font-medium">{row.name}</td>
                    <td className="py-3 px-5 text-right text-emerald-400">{fmt(row.income)}</td>
                    <td className="py-3 px-5 text-right text-red-400">{fmt(row.expense)}</td>
                    <td className={`py-3 px-5 text-right font-medium ${row.net >= 0 ? 'text-emerald-400' : 'text-red-400'}`}>
                      {row.net >= 0 ? '+' : '−'}{fmt(Math.abs(row.net))}
                    </td>
                    <td className={`py-3 px-5 text-right font-semibold ${row.balance >= 0 ? 'text-white' : 'text-red-400'}`}>
                      {fmt(row.balance)}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>

        <div className="space-y-6">
          <div className="bg-[#1a1a2e] border border-white/10 rounded-2xl p-5">
            <h3 className="text-white font-semibold mb-1">What-if Adjustments</h3>
            <p className="text-xs text-white/40 mb-4">Add expected changes on top of your averages (e.g. a raise, new rent).</p>
            <div className="space-y-3">
              <div>
                <label className="block text-sm text-white/60 mb-1">Extra monthly income</label>
                <input
                  type="number" step="100" value={adjIncome}
                  onChange={e => setAdjIncome(e.target.value)}
                  className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-emerald-500/50"
                  placeholder="0"
                />
              </div>
              <div>
                <label className="block text-sm text-white/60 mb-1">Extra monthly expense</label>
                <input
                  type="number" step="100" value={adjExpense}
                  onChange={e => setAdjExpense(e.target.value)}
                  className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-red-500/50"
                  placeholder="0"
                />
              </div>
            </div>
          </div>

          <div className="bg-[#1a1a2e] border border-white/10 rounded-2xl p-5">
            <h3 className="text-white font-semibold mb-1 flex items-center gap-2"><Repeat size={16} className="text-cyan-400" /> Fixed Commitments</h3>
            <p className="text-xs text-white/40 mb-4">
              Active recurring items, normalized per month. Already included in your averages — shown here so you know what's locked in.
            </p>
            <div className="flex justify-between text-sm mb-3">
              <span className="text-white/50">Recurring income</span>
              <span className="text-emerald-400 font-medium">{fmt(recurringMonthly.income)}/mo</span>
            </div>
            <div className="flex justify-between text-sm mb-3">
              <span className="text-white/50">Recurring expense</span>
              <span className="text-red-400 font-medium">{fmt(recurringMonthly.expense)}/mo</span>
            </div>
            {recurring.length > 0 ? (
              <div className="space-y-1.5 mt-3 pt-3 border-t border-white/5">
                {recurring.map((r, i) => (
                  <div key={i} className="flex justify-between text-xs">
                    <span className="text-white/50 truncate mr-2">{r.title} <span className="text-white/25">({r.frequency})</span></span>
                    <span className={r.type === 'income' ? 'text-emerald-400' : 'text-red-400'}>{fmt(r.amount)}</span>
                  </div>
                ))}
              </div>
            ) : (
              <p className="text-xs text-white/30 mt-2">No active recurring items.</p>
            )}
          </div>
        </div>
      </div>

      <ChartCard title="Recent History" subtitle="The months your forecast is based on">
        <ResponsiveContainer width="100%" height={240}>
          <AreaChart data={history}>
            <defs>
              <linearGradient id="histIncome" x1="0" y1="0" x2="0" y2="1">
                <stop offset="0%" stopColor="#10b981" stopOpacity={0.3} />
                <stop offset="100%" stopColor="#10b981" stopOpacity={0} />
              </linearGradient>
              <linearGradient id="histExpense" x1="0" y1="0" x2="0" y2="1">
                <stop offset="0%" stopColor="#ef4444" stopOpacity={0.3} />
                <stop offset="100%" stopColor="#ef4444" stopOpacity={0} />
              </linearGradient>
            </defs>
            <CartesianGrid strokeDasharray="3 3" stroke="#ffffff08" />
            <XAxis dataKey="name" tick={{ fill: '#ffffff40', fontSize: 12 }} axisLine={false} tickLine={false} />
            <YAxis tick={{ fill: '#ffffff40', fontSize: 12 }} axisLine={false} tickLine={false} width={80} />
            <Tooltip content={<CustomTooltip />} />
            <Area type="monotone" dataKey="income" name="Income" stroke="#10b981" strokeWidth={2} fill="url(#histIncome)" dot={{ r: 2, fill: '#10b981', strokeWidth: 0 }} />
            <Area type="monotone" dataKey="expense" name="Expense" stroke="#ef4444" strokeWidth={2} fill="url(#histExpense)" dot={{ r: 2, fill: '#ef4444', strokeWidth: 0 }} />
          </AreaChart>
        </ResponsiveContainer>
      </ChartCard>
    </div>
  );
}

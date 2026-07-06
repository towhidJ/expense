import { useMemo } from 'react';
import { useEntity } from '../context/EntityContext';
import { useTransactions } from '../hooks/useTransactions';
import { useCategories } from '../hooks/useCategories';
import { useBudgets } from '../hooks/useBudgets';
import { useAccounts } from '../context/AccountContext';
import { useAssets } from '../hooks/useAssets';
import { useInvestments } from '../hooks/useInvestments';
import { useLiabilities } from '../hooks/useLiabilities';
import { useRecurring } from '../hooks/useRecurring';
import StatCard from '../components/StatCard';
import ChartCard from '../components/ChartCard';
import TransactionList from '../components/TransactionList';
import BudgetCard from '../components/BudgetCard';
import { Shield, Bike, Landmark, Target, CalendarClock } from 'lucide-react';
import { PieChart, Pie, Cell, ResponsiveContainer, BarChart, Bar, XAxis, YAxis, Tooltip, CartesianGrid } from 'recharts';

const CHART_COLORS = ['#06b6d4', '#8b5cf6', '#f59e0b', '#ef4444', '#10b981', '#ec4899', '#6366f1', '#f97316'];

const CustomTooltip = ({ active, payload, label }) => {
  if (active && payload && payload.length) {
    return (
      <div className="bg-popover border border-border rounded-xl p-3 shadow-xl text-popover-foreground">
        <p className="text-muted-foreground text-xs mb-1">{label}</p>
        {payload.map((p, i) => (
          <p key={i} className="text-sm font-medium" style={{ color: p.color }}>
            {p.name}: ৳{p.value.toLocaleString()}
          </p>
        ))}
      </div>
    );
  }
  return null;
};

export default function Dashboard() {
  const { currentEntity } = useEntity();
  
  const { transactions } = useTransactions();
  useCategories(); // seeds default categories for new workspaces
  const { budgets } = useBudgets();
  const { accounts } = useAccounts();
  const { assets } = useAssets();
  const { investments } = useInvestments();
  const { liabilities } = useLiabilities();
  const { recurring } = useRecurring();

  // Upcoming recurring in next 30 days
  const upcomingRecurring = useMemo(() => {
    const today = new Date();
    const in30 = new Date();
    in30.setDate(today.getDate() + 30);
    return recurring
      .filter(r => r.is_active && new Date(r.next_run_date) <= in30)
      .sort((a, b) => new Date(a.next_run_date) - new Date(b.next_run_date))
      .slice(0, 5);
  }, [recurring]);

  const now = new Date();
  const currentMonth = now.getMonth();
  const currentYear = now.getFullYear();

  // NET WORTH CALCULATION
  const totalCash = accounts.reduce((sum, a) => sum + Number(a.current_balance || 0), 0);
  const totalAssetsValue = assets.reduce((sum, a) => sum + Number(a.current_value || a.value || 0), 0);
  const totalInvestmentsValue = investments.reduce((sum, i) => sum + Number(i.current_value || 0), 0);
  const activeLiabilities = liabilities.filter(l => Number(l.remaining_balance) > 0);
  // Money you lent out (loan_given) is a receivable — it adds to net worth
  const totalReceivables = activeLiabilities.filter(l => l.type === 'loan_given').reduce((sum, l) => sum + Number(l.remaining_balance || 0), 0);
  const totalLiabilities = activeLiabilities.filter(l => l.type !== 'loan_given').reduce((sum, l) => sum + Number(l.remaining_balance || 0), 0);

  const netWorth = totalCash + totalAssetsValue + totalInvestmentsValue + totalReceivables - totalLiabilities;

  const stats = useMemo(() => {
    const monthTx = transactions.filter(t => {
      const d = new Date(t.date);
      return d.getMonth() === currentMonth && d.getFullYear() === currentYear;
    });
    const totalIncome = monthTx.filter(t => t.type === 'income').reduce((s, t) => s + t.amount, 0);
    const totalExpense = monthTx.filter(t => t.type === 'expense').reduce((s, t) => s + t.amount, 0);
    const balance = totalIncome - totalExpense;
    const savingsRate = totalIncome > 0 ? ((totalIncome - totalExpense) / totalIncome * 100) : 0;
    return { totalIncome, totalExpense, balance, savingsRate };
  }, [transactions, currentMonth, currentYear]);

  const categoryExpenses = useMemo(() => {
    const monthTx = transactions.filter(t => {
      const d = new Date(t.date);
      return t.type === 'expense' && d.getMonth() === currentMonth && d.getFullYear() === currentYear;
    });
    const map = {};
    monthTx.forEach(t => {
      const name = t.categories?.name || 'Other';
      map[name] = (map[name] || 0) + t.amount;
    });
    return Object.entries(map).map(([name, value]) => ({ name, value })).sort((a, b) => b.value - a.value);
  }, [transactions, currentMonth, currentYear]);

  const monthlyTrend = useMemo(() => {
    const months = [];
    for (let i = 5; i >= 0; i--) {
      const d = new Date(currentYear, currentMonth - i, 1);
      const m = d.getMonth();
      const y = d.getFullYear();
      const label = d.toLocaleString('default', { month: 'short' });
      const monthTx = transactions.filter(t => {
        const td = new Date(t.date);
        return td.getMonth() === m && td.getFullYear() === y;
      });
      const income = monthTx.filter(t => t.type === 'income').reduce((s, t) => s + t.amount, 0);
      const expense = monthTx.filter(t => t.type === 'expense').reduce((s, t) => s + t.amount, 0);
      months.push({ name: label, income, expense });
    }
    return months;
  }, [transactions, currentMonth, currentYear]);

  const budgetData = useMemo(() => {
    return budgets.map(b => {
      const spent = transactions
        .filter(t => {
          const d = new Date(t.date);
          return t.type === 'expense' && t.category_id === b.category_id && d.getMonth() + 1 === b.month && d.getFullYear() === b.year;
        })
        .reduce((s, t) => s + t.amount, 0);
      return { budget: b, spent };
    });
  }, [budgets, transactions]);

  return (
    <div className="space-y-6 animate-in">
      <div>
        <h1 className="text-2xl font-bold tracking-tight">Financial Dashboard</h1>
        <p className="text-muted-foreground text-sm mt-1">
          {currentEntity?.name || 'Personal'} Workspace Overview
        </p>
      </div>

      {/* Net Worth Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        <StatCard
          title="Net Worth"
          value={`৳${netWorth.toLocaleString()}`}
          icon={Target}
          gradient={['#06b6d4', '#8b5cf6']}
          iconBg="bg-cyan-500/10"
        />
        <StatCard
          title="Cash Position"
          value={`৳${totalCash.toLocaleString()}`}
          icon={Landmark}
          gradient={['#10b981', '#06b6d4']}
          iconBg="bg-emerald-500/10"
        />
        <StatCard
          title="Assets & Investments"
          value={`৳${(totalAssetsValue + totalInvestmentsValue).toLocaleString()}`}
          icon={Bike}
          gradient={['#f59e0b', '#ec4899']}
          iconBg="bg-orange-500/10"
        />
        <StatCard
          title="Total Liabilities"
          value={`৳${totalLiabilities.toLocaleString()}`}
          icon={Shield}
          gradient={['#ef4444', '#f97316']}
          iconBg="bg-red-500/10"
        />
      </div>

      {/* Income/Expense Stat Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
        <div className="bg-card border border-border rounded-2xl p-5">
          <p className="text-muted-foreground text-xs">Monthly Income</p>
          <p className="text-xl font-semibold text-emerald-500 mt-1">৳{stats.totalIncome.toLocaleString()}</p>
        </div>
        <div className="bg-card border border-border rounded-2xl p-5">
          <p className="text-muted-foreground text-xs">Monthly Expenses</p>
          <p className="text-xl font-semibold text-destructive mt-1">৳{stats.totalExpense.toLocaleString()}</p>
        </div>
        <div className="bg-card border border-border rounded-2xl p-5">
          <p className="text-muted-foreground text-xs">Savings Rate (Month)</p>
          <p className="text-xl font-semibold text-primary mt-1">{stats.savingsRate.toFixed(1)}%</p>
        </div>
      </div>

      {/* Charts */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <ChartCard title="Income vs Expenses" subtitle="Last 6 months">
          <ResponsiveContainer width="100%" height={280}>
            <BarChart data={monthlyTrend} barGap={8}>
              <CartesianGrid strokeDasharray="3 3" stroke="#ffffff08" />
              <XAxis dataKey="name" tick={{ fill: '#ffffff40', fontSize: 12 }} axisLine={false} tickLine={false} />
              <YAxis tick={{ fill: '#ffffff40', fontSize: 12 }} axisLine={false} tickLine={false} />
              <Tooltip content={<CustomTooltip />} />
              <Bar dataKey="income" fill="#10b981" radius={[6, 6, 0, 0]} name="Income" />
              <Bar dataKey="expense" fill="#ef4444" radius={[6, 6, 0, 0]} name="Expense" />
            </BarChart>
          </ResponsiveContainer>
        </ChartCard>

        <ChartCard title="Spending by Category" subtitle="This month">
          {categoryExpenses.length > 0 ? (
            <div className="flex flex-col sm:flex-row items-center gap-6">
              <div className="w-full sm:w-1/2 shrink-0">
                <ResponsiveContainer width="100%" height={240}>
                <PieChart>
                  <Pie
                    data={categoryExpenses}
                    cx="50%"
                    cy="50%"
                    innerRadius="55%"
                    outerRadius="90%"
                    dataKey="value"
                    stroke="none"
                  >
                    {categoryExpenses.map((_, i) => (
                      <Cell key={i} fill={CHART_COLORS[i % CHART_COLORS.length]} />
                    ))}
                  </Pie>
                </PieChart>
                </ResponsiveContainer>
              </div>
              <div className="flex-1 w-full min-w-0 space-y-2">
                {categoryExpenses.slice(0, 5).map((c, i) => (
                  <div key={c.name} className="flex items-center gap-2">
                    <div className="w-3 h-3 rounded-full" style={{ backgroundColor: CHART_COLORS[i % CHART_COLORS.length] }} />
                    <span className="text-xs text-muted-foreground flex-1 truncate">{c.name}</span>
                    <span className="text-xs font-medium">৳{c.value.toLocaleString()}</span>
                  </div>
                ))}
              </div>
            </div>
          ) : (
            <div className="flex items-center justify-center h-60 text-muted-foreground text-sm">No expense data this month</div>
          )}
        </ChartCard>
      </div>

      {/* Budget Progress */}
      {budgetData.length > 0 && (
        <ChartCard title="Budget Progress" subtitle="This month">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            {budgetData.map(({ budget, spent }) => (
              <BudgetCard key={budget.id} budget={budget} spent={spent} />
            ))}
          </div>
        </ChartCard>
      )}

      {/* Bottom Row */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Recent Transactions */}
        <ChartCard title="Recent Transactions" subtitle="Latest entries">
          <TransactionList transactions={transactions.slice(0, 7)} showActions={false} />
        </ChartCard>

        {/* Active Debts */}
        <ChartCard title="Active Debts & Dues" subtitle="Liabilities needing attention">
          <div className="space-y-4">
            {liabilities.filter(l => l.remaining_balance > 0).slice(0, 5).map(liability => {
              const progress = liability.principal > 0 ? Math.min(((liability.principal - liability.remaining_balance) / liability.principal) * 100, 100) : 0;
              return (
                <div key={liability.id} className="bg-white/5 border border-white/10 rounded-xl p-4">
                  <div className="flex justify-between items-center mb-2">
                    <div>
                      <p className="text-sm font-medium text-foreground">{liability.name}</p>
                      <p className="text-xs text-muted-foreground capitalize">{liability.type.replace('_', ' ')}</p>
                    </div>
                    <div className="text-right">
                      <p className={`text-sm font-semibold ${liability.type === 'loan_given' ? 'text-emerald-500' : 'text-destructive'}`}>
                        ৳{liability.remaining_balance.toLocaleString()}
                      </p>
                      <p className="text-xs text-muted-foreground">Remaining</p>
                    </div>
                  </div>
                  <div className="h-1.5 w-full bg-background/50 rounded-full overflow-hidden">
                    <div className={`h-full ${liability.type === 'loan_given' ? 'bg-emerald-500' : 'bg-destructive'} rounded-full`} style={{ width: `${100 - progress}%` }} />
                  </div>
                </div>
              );
            })}
            {liabilities.filter(l => l.remaining_balance > 0).length === 0 && (
              <div className="text-center py-8 text-muted-foreground text-sm">
                No active debts. You're all clear!
              </div>
            )}
          </div>
        </ChartCard>
      </div>

      {/* Upcoming Recurring */}
      {upcomingRecurring.length > 0 && (
        <ChartCard title="Upcoming Payments" subtitle="Recurring in next 30 days">
          <div className="space-y-3">
            {upcomingRecurring.map(item => {
              const isExpense = item.type === 'expense';
              const isOverdue = new Date(item.next_run_date) < new Date();
              return (
                <div key={item.id} className="flex items-center justify-between py-2.5 border-b border-white/5 last:border-0">
                  <div className="flex items-center gap-3">
                    <div className={`w-8 h-8 rounded-lg flex items-center justify-center text-sm ${isExpense ? 'bg-red-500/10' : 'bg-emerald-500/10'}`}>
                      {item.categories?.icon || <CalendarClock size={14} className={isExpense ? 'text-red-400' : 'text-emerald-400'} />}
                    </div>
                    <div>
                      <p className="text-sm font-medium text-white">{item.title}</p>
                      <p className={`text-xs ${isOverdue ? 'text-orange-400 font-medium' : 'text-white/40'}`}>
                        {isOverdue ? '⚠️ Overdue · ' : ''}{new Date(item.next_run_date).toLocaleDateString()} · {item.frequency}
                      </p>
                    </div>
                  </div>
                  <span className={`text-sm font-semibold ${isExpense ? 'text-red-400' : 'text-emerald-400'}`}>
                    {isExpense ? '-' : '+'}৳{item.amount.toLocaleString()}
                  </span>
                </div>
              );
            })}
          </div>
        </ChartCard>
      )}
    </div>
  );
}

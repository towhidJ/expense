import { useMemo } from 'react';
import { CalendarClock, PiggyBank, HandCoins, AlertTriangle } from 'lucide-react';
import ChartCard from './ChartCard';

const DAYS_AHEAD = 30;

// One consolidated "what needs paying" panel: recurring transactions,
// recurring savings installments (DPS etc.) and liability due dates, sorted
// by date with overdue first, plus budgets that are ≥80% spent.
export default function UpcomingPanel({ recurring, recurringSavings, liabilities, budgetData }) {
  const { items, overdueCount } = useMemo(() => {
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const horizon = new Date(today);
    horizon.setDate(horizon.getDate() + DAYS_AHEAD);

    const list = [];

    (recurring || [])
      .filter(r => r.is_active && r.next_run_date && new Date(r.next_run_date) <= horizon)
      .forEach(r => list.push({
        id: `rec-${r.id}`,
        date: new Date(r.next_run_date),
        label: r.title,
        sub: `Recurring · ${r.frequency}`,
        amount: Number(r.amount || 0),
        incoming: r.type === 'income',
        icon: r.categories?.icon || null,
        fallbackIcon: CalendarClock
      }));

    (recurringSavings || [])
      .filter(s => s.is_active && s.next_run_date && new Date(s.next_run_date) <= horizon)
      .forEach(s => list.push({
        id: `sav-${s.id}`,
        date: new Date(s.next_run_date),
        label: s.title,
        sub: `Savings installment · ${s.frequency}`,
        amount: Number(s.amount || 0),
        incoming: false,
        icon: null,
        fallbackIcon: PiggyBank
      }));

    (liabilities || [])
      .filter(l => Number(l.remaining_balance) > 0 && l.due_date && new Date(l.due_date) <= horizon)
      .forEach(l => list.push({
        id: `lia-${l.id}`,
        date: new Date(l.due_date),
        label: l.name,
        sub: l.type === 'loan_given' ? 'Loan you gave — due back' : `Due · ${String(l.type).replace('_', ' ')}`,
        amount: Number(l.remaining_balance || 0),
        incoming: l.type === 'loan_given',
        icon: null,
        fallbackIcon: HandCoins
      }));

    list.sort((a, b) => a.date - b.date);
    return {
      items: list.slice(0, 8),
      overdueCount: list.filter(i => i.date < today).length
    };
  }, [recurring, recurringSavings, liabilities]);

  const budgetAlerts = useMemo(() => (
    (budgetData || [])
      .map(({ budget, spent }) => ({ budget, spent, pct: budget.amount > 0 ? (spent / budget.amount) * 100 : 0 }))
      .filter(b => b.pct >= 80)
      .sort((a, b) => b.pct - a.pct)
  ), [budgetData]);

  if (items.length === 0 && budgetAlerts.length === 0) return null;

  const today = new Date();
  today.setHours(0, 0, 0, 0);

  return (
    <ChartCard
      title="Reminders & Upcoming"
      subtitle={overdueCount > 0
        ? `${overdueCount} overdue · next ${DAYS_AHEAD} days`
        : `Next ${DAYS_AHEAD} days`}
    >
      <div className="space-y-3">
        {budgetAlerts.length > 0 && (
          <div className="flex flex-wrap gap-2 pb-1">
            {budgetAlerts.map(({ budget, pct }) => (
              <span
                key={budget.id}
                className={`inline-flex items-center gap-1.5 text-xs px-2.5 py-1 rounded-lg border ${
                  pct >= 100
                    ? 'bg-red-500/10 text-red-400 border-red-500/20'
                    : 'bg-orange-500/10 text-orange-400 border-orange-500/20'
                }`}
              >
                <AlertTriangle size={12} />
                {budget.categories?.name || 'Budget'}: {pct.toFixed(0)}% {pct >= 100 ? 'over budget' : 'used'}
              </span>
            ))}
          </div>
        )}

        {items.map(item => {
          const isOverdue = item.date < today;
          const Icon = item.fallbackIcon;
          return (
            <div key={item.id} className="flex items-center justify-between py-2.5 border-b border-foreground/5 last:border-0">
              <div className="flex items-center gap-3 min-w-0">
                <div className={`w-8 h-8 rounded-lg flex items-center justify-center text-sm shrink-0 ${
                  isOverdue ? 'bg-red-500/10' : item.incoming ? 'bg-emerald-500/10' : 'bg-foreground/5'
                }`}>
                  {item.icon || <Icon size={14} className={isOverdue ? 'text-red-400' : item.incoming ? 'text-emerald-400' : 'text-foreground/50'} />}
                </div>
                <div className="min-w-0">
                  <p className="text-sm font-medium text-foreground truncate">{item.label}</p>
                  <p className={`text-xs ${isOverdue ? 'text-red-400 font-medium' : 'text-muted-foreground'}`}>
                    {isOverdue ? '⚠️ Overdue · ' : ''}{item.date.toLocaleDateString()} · {item.sub}
                  </p>
                </div>
              </div>
              <span className={`text-sm font-semibold shrink-0 ml-3 ${item.incoming ? 'text-emerald-400' : 'text-red-400'}`}>
                {item.incoming ? '+' : '-'}৳{item.amount.toLocaleString()}
              </span>
            </div>
          );
        })}
        {items.length === 0 && (
          <p className="text-muted-foreground text-sm py-2">Nothing due in the next {DAYS_AHEAD} days.</p>
        )}
      </div>
    </ChartCard>
  );
}

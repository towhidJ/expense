import { useMemo } from 'react';

// Spent-vs-limit for each budget, matching the budget's own category/month/
// year and, since v30, its family_member_id scope: a per-member budget only
// counts that member's transactions, a household budget (member_id NULL)
// only counts unattributed ones — so a member-scoped and a household budget
// for the same category/month never double-count each other's spend.
// Was duplicated identically in Budgets.jsx and Dashboard.jsx; consolidated
// here so both stay in sync (and so finance_notifications' server-side check
// can describe the same rule in one place).
export function computeBudgetSpend(budgets, transactions) {
  return budgets.map(b => {
    const spent = transactions
      .filter(t => {
        const d = new Date(t.date);
        return t.type === 'expense' && t.category_id === b.category_id
          && d.getMonth() + 1 === b.month && d.getFullYear() === b.year
          && (t.family_member_id || null) === (b.family_member_id || null);
      })
      .reduce((s, t) => s + t.amount, 0);
    return { budget: b, spent };
  });
}

export function useBudgetSpend(budgets, transactions) {
  return useMemo(() => computeBudgetSpend(budgets, transactions), [budgets, transactions]);
}

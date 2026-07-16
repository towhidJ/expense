import { useState, useEffect, useCallback, useMemo } from 'react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../context/AuthContext';
import { useEntity } from '../context/EntityContext';

const monthKey = (d) => `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`;
const monthName = (d) => d.toLocaleDateString('en-US', { month: 'short', year: '2-digit' });

// Data layer for the cashflow forecast: trailing per-month income/expense
// totals plus the active recurring commitments. Recurring items auto-post
// into transactions, so the trailing averages already include them — the
// recurring numbers are surfaced separately as info, never added on top.
export function useCashflowForecast() {
  const { user } = useAuth();
  const { currentEntity } = useEntity();
  const [transactions, setTransactions] = useState([]);
  const [recurring, setRecurring] = useState([]);
  const [loading, setLoading] = useState(true);

  const fetchData = useCallback(async () => {
    if (!user || !currentEntity) return;
    setLoading(true);
    const start = new Date();
    start.setDate(1);
    start.setMonth(start.getMonth() - 6);
    const startStr = start.toISOString().split('T')[0];

    const [{ data: txData, error: txError }, { data: recData, error: recError }] = await Promise.all([
      supabase
        .from('transactions')
        .select('type, amount, date')
        .eq('user_id', user.id)
        .eq('entity_id', currentEntity.id)
        .gte('date', startStr),
      supabase
        .from('recurring_transactions')
        .select('title, type, amount, frequency, next_run_date, is_active')
        .eq('user_id', user.id)
        .eq('entity_id', currentEntity.id)
        .eq('is_active', true)
    ]);

    if (txError) console.error('Error fetching transactions for forecast:', txError);
    else setTransactions(txData || []);
    if (recError) console.error('Error fetching recurring for forecast:', recError);
    else setRecurring(recData || []);
    setLoading(false);
  }, [user, currentEntity]);

  useEffect(() => {
    fetchData();
  }, [fetchData]);

  // Last 7 calendar months (6 past + current), each with income/expense totals.
  const history = useMemo(() => {
    const months = [];
    const now = new Date();
    for (let i = 6; i >= 0; i--) {
      const d = new Date(now.getFullYear(), now.getMonth() - i, 1);
      months.push({ key: monthKey(d), name: monthName(d), income: 0, expense: 0 });
    }
    const index = new Map(months.map(m => [m.key, m]));
    for (const tx of transactions) {
      const m = index.get(tx.date?.slice(0, 7));
      if (!m) continue;
      if (tx.type === 'income') m.income += Number(tx.amount);
      else if (tx.type === 'expense') m.expense += Number(tx.amount);
    }
    return months;
  }, [transactions]);

  // Average over up to the last 3 FULL months that have any activity; the
  // current partial month would drag the average down, so it's excluded
  // unless it's all we have.
  const averages = useMemo(() => {
    const fullMonths = history.slice(0, -1).filter(m => m.income > 0 || m.expense > 0);
    const sample = fullMonths.slice(-3);
    const base = sample.length ? sample : history.slice(-1);
    const income = base.reduce((s, m) => s + m.income, 0) / base.length;
    const expense = base.reduce((s, m) => s + m.expense, 0) / base.length;
    return { income, expense, sampleSize: sample.length ? sample.length : 0 };
  }, [history]);

  // Normalized monthly total of active recurring items (info only).
  const recurringMonthly = useMemo(() => {
    const factor = { daily: 30.44, weekly: 4.35, monthly: 1, yearly: 1 / 12 };
    let income = 0, expense = 0;
    for (const r of recurring) {
      const monthly = Number(r.amount) * (factor[r.frequency] || 1);
      if (r.type === 'income') income += monthly;
      else expense += monthly;
    }
    return { income, expense };
  }, [recurring]);

  return { history, averages, recurringMonthly, recurring, loading, fetchData };
}

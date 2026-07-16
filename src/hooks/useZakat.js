import { useState, useEffect, useCallback, useMemo } from 'react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../context/AuthContext';
import { useEntity } from '../context/EntityContext';

// Pulls the zakatable pieces of the balance sheet: savings balance,
// investments, receivables (loan_given) and outstanding debts.
// Cash comes from AccountContext on the page itself.
export function useZakat() {
  const { user } = useAuth();
  const { currentEntity } = useEntity();
  const [savingsEntries, setSavingsEntries] = useState([]);
  const [investments, setInvestments] = useState([]);
  const [liabilities, setLiabilities] = useState([]);
  const [loading, setLoading] = useState(true);

  const fetchData = useCallback(async () => {
    if (!user || !currentEntity) return;
    setLoading(true);
    const [savRes, invRes, liaRes] = await Promise.all([
      supabase.from('savings').select('type, amount')
        .eq('user_id', user.id).eq('entity_id', currentEntity.id),
      supabase.from('investments').select('name, type, invested_amount, current_value')
        .eq('user_id', user.id).eq('entity_id', currentEntity.id),
      supabase.from('liabilities').select('name, counterparty, type, remaining_balance')
        .eq('user_id', user.id).eq('entity_id', currentEntity.id)
    ]);
    if (savRes.error) console.error('Error fetching savings for zakat:', savRes.error);
    else setSavingsEntries(savRes.data || []);
    if (invRes.error) console.error('Error fetching investments for zakat:', invRes.error);
    else setInvestments(invRes.data || []);
    if (liaRes.error) console.error('Error fetching liabilities for zakat:', liaRes.error);
    else setLiabilities(liaRes.data || []);
    setLoading(false);
  }, [user, currentEntity]);

  useEffect(() => {
    fetchData();
  }, [fetchData]);

  const savingsBalance = useMemo(
    () => savingsEntries.reduce((s, e) => s + (e.type === 'deposit' ? 1 : -1) * Number(e.amount), 0),
    [savingsEntries]
  );

  const investmentsValue = useMemo(
    () => investments.reduce((s, i) => s + Number(i.current_value || i.invested_amount || 0), 0),
    [investments]
  );

  // Money people owe you (strong debts are zakatable).
  const receivables = useMemo(
    () => liabilities.filter(l => l.type === 'loan_given')
      .reduce((s, l) => s + Math.max(0, Number(l.remaining_balance)), 0),
    [liabilities]
  );

  // Debts you owe — deductible from zakatable wealth.
  const debts = useMemo(
    () => liabilities.filter(l => l.type !== 'loan_given')
      .reduce((s, l) => s + Math.max(0, Number(l.remaining_balance)), 0),
    [liabilities]
  );

  return { savingsBalance, investmentsValue, investments, receivables, debts, loading };
}

import { useState, useEffect, useCallback } from 'react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../context/AuthContext';
import { useEntity } from '../context/EntityContext';

// Annualized return from a single lump-sum invested_amount/current_value/
// purchase_date — accurate for one-time purchases (stocks, fdr, crypto,
// one-time mutual_funds), but misleading for a recurring-contribution type
// like dps (a fixed monthly deposit isn't a lump sum on purchase_date), so
// callers should show the DPS caveat alongside this number. Full XIRR (which
// needs a per-contribution cash-flow history) is a separate, later feature.
export function calculateCAGR(investment) {
  const invested = Number(investment.invested_amount);
  const current = Number(investment.current_value);
  if (!invested || invested <= 0 || !investment.purchase_date) return null;
  const daysHeld = (Date.now() - new Date(investment.purchase_date).getTime()) / 86400000;
  if (daysHeld <= 0) return null;
  return (Math.pow(current / invested, 365 / daysHeld) - 1) * 100;
}

// Full XIRR from a cash-flow history (investment_contributions, v29) —
// accurate for recurring-contribution types like dps, unlike calculateCAGR's
// single lump-sum approximation. Newton's method, matching this codebase's
// client-side analytics convention (nothing iterative lives in PL/pgSQL
// here). contributions: [{date, amount, type}], amount positive = money in.
// Includes a synthetic final "sell everything today" cash flow using
// current_value so the return reflects the investment's current worth.
export function calculateXIRR(investment, contributions) {
  if (!contributions || contributions.length === 0) return null;
  const flows = contributions.map(c => ({
    date: new Date(c.date),
    amount: c.type === 'withdrawal' ? -Math.abs(Number(c.amount)) : Math.abs(Number(c.amount))
  }));
  flows.push({ date: new Date(), amount: Number(investment.current_value) });
  flows.sort((a, b) => a.date - b.date);

  const t0 = flows[0].date.getTime();
  const years = flows.map(f => (f.date.getTime() - t0) / (365 * 86400000));
  const npv = (rate) => flows.reduce((s, f, i) => s + f.amount / Math.pow(1 + rate, years[i]), 0);
  const dnpv = (rate) => flows.reduce((s, f, i) =>
    s + (years[i] === 0 ? 0 : -years[i] * f.amount / Math.pow(1 + rate, years[i] + 1)), 0);

  let rate = 0.1;
  for (let i = 0; i < 50; i++) {
    const d = dnpv(rate);
    if (Math.abs(d) < 1e-9) break;
    const next = rate - npv(rate) / d;
    if (!Number.isFinite(next)) return null;
    if (Math.abs(next - rate) < 1e-7) { rate = next; break; }
    rate = next;
  }
  return Number.isFinite(rate) ? rate * 100 : null;
}

export function useInvestments() {
  const { user } = useAuth();
  const { currentEntity } = useEntity();
  const [investments, setInvestments] = useState([]);
  const [loading, setLoading] = useState(true);

  const fetchInvestments = useCallback(async () => {
    if (!user || !currentEntity) return;
    setLoading(true);
    const { data, error } = await supabase
      .from('investments')
      .select('*')
      .eq('user_id', user.id)
      .eq('entity_id', currentEntity.id)
      .order('created_at', { ascending: false });

    if (error) {
      console.error('Error fetching investments:', error);
    } else {
      setInvestments(data || []);
    }
    setLoading(false);
  }, [user, currentEntity]);

  useEffect(() => {
    fetchInvestments();
  }, [fetchInvestments]);

  const addInvestment = async (investment) => {
    const { data, error } = await supabase
      .from('investments')
      .insert({ ...investment, user_id: user.id, entity_id: currentEntity.id })
      .select()
      .single();
    if (error) throw error;
    setInvestments([data, ...investments]);
    return data;
  };

  const updateInvestment = async (id, updates) => {
    const { data, error } = await supabase
      .from('investments')
      .update(updates)
      .eq('id', id)
      .eq('user_id', user.id)
      .select()
      .single();
    if (error) throw error;
    setInvestments(investments.map(i => i.id === id ? data : i));
    return data;
  };

  const deleteInvestment = async (id) => {
    const { error } = await supabase
      .from('investments')
      .delete()
      .eq('id', id)
      .eq('user_id', user.id);
    if (error) throw error;
    setInvestments(investments.filter(i => i.id !== id));
  };

  // ---- Contribution history for full XIRR (v29) ----

  const fetchContributions = async (investmentId) => {
    const { data, error } = await supabase
      .from('investment_contributions')
      .select('*')
      .eq('investment_id', investmentId)
      .order('date', { ascending: true });
    if (error) throw error;
    return data || [];
  };

  const addContribution = async (investmentId, { date, amount, type }) => {
    const { error } = await supabase.from('investment_contributions').insert({
      investment_id: investmentId, user_id: user.id, date, amount, type: type || 'contribution'
    });
    if (error) throw error;
  };

  const deleteContribution = async (id) => {
    const { error } = await supabase.from('investment_contributions').delete().eq('id', id);
    if (error) throw error;
  };

  return {
    investments, loading, fetchInvestments, addInvestment, updateInvestment, deleteInvestment,
    fetchContributions, addContribution, deleteContribution
  };
}

import { useState, useEffect, useCallback } from 'react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../context/AuthContext';
import { useEntity } from '../context/EntityContext';

export function useBudgets() {
  const { user } = useAuth();
  const { currentEntity } = useEntity();
  const [budgets, setBudgets] = useState([]);
  const [loading, setLoading] = useState(true);

  const fetchBudgets = useCallback(async (month, year) => {
    if (!user || !currentEntity) return;
    setLoading(true);
    const m = month || new Date().getMonth() + 1;
    const y = year || new Date().getFullYear();
    const { data, error } = await supabase
      .from('budgets')
      .select('*, categories(name, icon, color), family_members(name)')
      .eq('user_id', user.id)
      .eq('entity_id', currentEntity.id)
      .eq('month', m)
      .eq('year', y);
    if (error) console.error('Error fetching budgets:', error);
    else setBudgets(data || []);
    setLoading(false);
  }, [user, currentEntity]);

  const addBudget = async (budget) => {
    const { error } = await supabase.from('budgets').insert({
      ...budget,
      user_id: user.id,
      entity_id: currentEntity.id
    });
    if (error) throw error;
    await fetchBudgets(budget.month, budget.year);
  };

  const updateBudget = async (id, updates) => {
    const { error } = await supabase
      .from('budgets')
      .update(updates)
      .eq('id', id)
      .eq('user_id', user.id);
    if (error) throw error;
    await fetchBudgets();
  };

  const deleteBudget = async (id) => {
    const { error } = await supabase
      .from('budgets')
      .delete()
      .eq('id', id)
      .eq('user_id', user.id);
    if (error) throw error;
    await fetchBudgets();
  };

  useEffect(() => {
    if (user) fetchBudgets();
  }, [user, fetchBudgets]);

  return { budgets, loading, fetchBudgets, addBudget, updateBudget, deleteBudget };
}

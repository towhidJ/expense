import { useState, useEffect, useCallback } from 'react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../context/AuthContext';
import { useEntity } from '../context/EntityContext';

export function useRecurring() {
  const { user } = useAuth();
  const { currentEntity } = useEntity();
  const [recurring, setRecurring] = useState([]);
  const [loading, setLoading] = useState(true);

  const fetchRecurring = useCallback(async () => {
    if (!user || !currentEntity) return;
    setLoading(true);
    const { data, error } = await supabase
      .from('recurring_transactions')
      .select('*, categories(name, icon), accounts(name)')
      .eq('user_id', user.id)
      .eq('entity_id', currentEntity.id)
      .order('next_run_date', { ascending: true });

    if (error) {
      console.error('Error fetching recurring transactions:', error);
    } else {
      setRecurring(data || []);
    }
    setLoading(false);
  }, [user, currentEntity]);

  useEffect(() => {
    fetchRecurring();
  }, [fetchRecurring]);

  const addRecurring = async (transaction) => {
    const { data, error } = await supabase
      .from('recurring_transactions')
      .insert({ ...transaction, user_id: user.id, entity_id: currentEntity.id })
      .select()
      .single();
    if (error) throw error;
    await fetchRecurring();
    return data;
  };

  const updateRecurring = async (id, updates) => {
    const { data, error } = await supabase
      .from('recurring_transactions')
      .update(updates)
      .eq('id', id)
      .eq('user_id', user.id)
      .select()
      .single();
    if (error) throw error;
    await fetchRecurring();
    return data;
  };

  const deleteRecurring = async (id) => {
    const { error } = await supabase
      .from('recurring_transactions')
      .delete()
      .eq('id', id)
      .eq('user_id', user.id);
    if (error) throw error;
    setRecurring(recurring.filter(r => r.id !== id));
  };

  return { recurring, loading, fetchRecurring, addRecurring, updateRecurring, deleteRecurring };
}

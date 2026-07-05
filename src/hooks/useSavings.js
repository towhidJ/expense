import { useState, useEffect, useCallback } from 'react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../context/AuthContext';
import { useEntity } from '../context/EntityContext';
import { useAccounts } from '../context/AccountContext';

export function useSavings() {
  const { user } = useAuth();
  const { currentEntity } = useEntity();
  const { fetchAccounts } = useAccounts();
  const [savings, setSavings] = useState([]);
  const [loading, setLoading] = useState(true);

  const fetchSavings = useCallback(async () => {
    if (!user || !currentEntity) return;
    setLoading(true);
    const { data, error } = await supabase
      .from('savings')
      .select('*, accounts(name)')
      .eq('user_id', user.id)
      .eq('entity_id', currentEntity.id)
      .order('date', { ascending: false });

    if (error) {
      console.error('Error fetching savings:', error);
    } else {
      setSavings(data || []);
    }
    setLoading(false);
  }, [user, currentEntity]);

  const addSaving = async (entry) => {
    if (entry.account_id) {
      // RPC inserts the entry and adjusts the account balance atomically
      const { error } = await supabase.rpc('process_saving', {
        p_user_id: user.id,
        p_entity_id: currentEntity.id,
        p_account_id: entry.account_id,
        p_type: entry.type,
        p_amount: entry.amount,
        p_date: entry.date,
        p_purpose: entry.purpose || null,
        p_notes: entry.notes || null
      });
      if (error) throw error;
    } else {
      const { error } = await supabase.from('savings').insert({
        ...entry,
        account_id: null,
        user_id: user.id,
        entity_id: currentEntity.id
      });
      if (error) throw error;
    }
    await Promise.all([fetchSavings(), fetchAccounts()]);
  };

  const deleteSaving = async (id) => {
    // RPC restores the account balance before removing the row
    const { error } = await supabase.rpc('delete_saving_with_balance', {
      p_user_id: user.id,
      p_saving_id: id
    });
    if (error) throw error;
    await Promise.all([fetchSavings(), fetchAccounts()]);
  };

  useEffect(() => {
    if (user) fetchSavings();
  }, [user, fetchSavings]);

  return { savings, loading, fetchSavings, addSaving, deleteSaving };
}

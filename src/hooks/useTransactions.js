import { useState, useEffect, useCallback } from 'react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../context/AuthContext';
import { useEntity } from '../context/EntityContext';

export function useTransactions() {
  const { user } = useAuth();
  const { currentEntity } = useEntity();
  const [transactions, setTransactions] = useState([]);
  const [loading, setLoading] = useState(true);

  const fetchTransactions = useCallback(async (filters = {}) => {
    if (!user || !currentEntity) return;
    setLoading(true);
    let query = supabase
      .from('transactions')
      .select('*, categories(name, icon, color), accounts(name)')
      .eq('user_id', user.id)
      .eq('entity_id', currentEntity.id)
      .order('date', { ascending: false });

    if (filters.type) query = query.eq('type', filters.type);
    if (filters.category_id) query = query.eq('category_id', filters.category_id);
    if (filters.asset_id) query = query.eq('asset_id', filters.asset_id);
    if (filters.startDate) query = query.gte('date', filters.startDate);
    if (filters.endDate) query = query.lte('date', filters.endDate);

    const { data, error } = await query;
    if (error) console.error('Error fetching transactions:', error);
    else setTransactions(data || []);
    setLoading(false);
  }, [user]);

  const addTransaction = async (transaction) => {
    if (transaction.account_id) {
      // Use the RPC to automatically update account balances
      const { error } = await supabase.rpc('process_transaction', {
        p_user_id: user.id,
        p_entity_id: currentEntity.id,
        p_account_id: transaction.account_id,
        p_category_id: transaction.category_id,
        p_asset_id: transaction.asset_id || null,
        p_type: transaction.type,
        p_amount: transaction.amount,
        p_date: transaction.date,
        p_description: transaction.description || ''
      });
      if (error) throw error;
    } else {
      const { error } = await supabase.from('transactions').insert({
        ...transaction,
        user_id: user.id,
        entity_id: currentEntity.id
      });
      if (error) throw error;
    }
    await fetchTransactions();
  };

  const updateTransaction = async (id, updates) => {
    const { error } = await supabase
      .from('transactions')
      .update(updates)
      .eq('id', id)
      .eq('user_id', user.id);
    if (error) throw error;
    await fetchTransactions();
  };

  const deleteTransaction = async (id) => {
    const { error } = await supabase
      .from('transactions')
      .delete()
      .eq('id', id)
      .eq('user_id', user.id);
    if (error) throw error;
    await fetchTransactions();
  };

  useEffect(() => {
    if (user) fetchTransactions();
  }, [user, fetchTransactions]);

  return { transactions, loading, fetchTransactions, addTransaction, updateTransaction, deleteTransaction };
}

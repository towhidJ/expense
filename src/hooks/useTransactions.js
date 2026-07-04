import { useState, useEffect, useCallback } from 'react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../context/AuthContext';
import { useEntity } from '../context/EntityContext';
import { useAccounts } from '../context/AccountContext';

export function useTransactions() {
  const { user } = useAuth();
  const { currentEntity } = useEntity();
  const { fetchAccounts } = useAccounts();
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
  }, [user, currentEntity]);

  const addTransaction = async (transaction) => {
    let newId;
    if (transaction.account_id) {
      // Use the RPC to automatically update account balances
      const { data, error } = await supabase.rpc('process_transaction', {
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
      newId = data; // process_transaction returns the new transaction id
    } else {
      const { data, error } = await supabase.from('transactions').insert({
        ...transaction,
        user_id: user.id,
        entity_id: currentEntity.id
      }).select('id').single();
      if (error) throw error;
      newId = data?.id;
    }
    await Promise.all([fetchTransactions(), fetchAccounts()]);
    return newId;
  };

  const updateTransaction = async (id, updates) => {
    // RPC reverses the old row's balance effect and applies the new one
    const { error } = await supabase.rpc('update_transaction_with_balance', {
      p_user_id: user.id,
      p_transaction_id: id,
      p_account_id: updates.account_id || null,
      p_category_id: updates.category_id,
      p_asset_id: updates.asset_id || null,
      p_type: updates.type,
      p_amount: updates.amount,
      p_date: updates.date,
      p_description: updates.description || ''
    });
    if (error) throw error;
    await Promise.all([fetchTransactions(), fetchAccounts()]);
  };

  const deleteTransaction = async (id) => {
    // RPC restores the account balance before removing the row
    const { error } = await supabase.rpc('delete_transaction_with_balance', {
      p_user_id: user.id,
      p_transaction_id: id
    });
    if (error) throw error;
    await Promise.all([fetchTransactions(), fetchAccounts()]);
  };

  useEffect(() => {
    if (user) fetchTransactions();
  }, [user, fetchTransactions]);

  return { transactions, loading, fetchTransactions, addTransaction, updateTransaction, deleteTransaction };
}

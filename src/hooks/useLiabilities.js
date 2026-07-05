import { useState, useEffect, useCallback } from 'react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../context/AuthContext';
import { useEntity } from '../context/EntityContext';

export function useLiabilities() {
  const { user } = useAuth();
  const { currentEntity } = useEntity();
  const [liabilities, setLiabilities] = useState([]);
  const [repayments, setRepayments] = useState([]);
  const [loading, setLoading] = useState(true);

  const fetchLiabilities = useCallback(async () => {
    if (!user || !currentEntity) return;
    setLoading(true);
    const { data, error } = await supabase
      .from('liabilities')
      .select('*')
      .eq('user_id', user.id)
      .eq('entity_id', currentEntity.id)
      .order('created_at', { ascending: false });

    if (error) {
      console.error('Error fetching liabilities:', error);
    } else {
      setLiabilities(data || []);
    }

    // Fetch repayments
    const { data: repData, error: repError } = await supabase
      .from('loan_repayments')
      .select('*, accounts(name)')
      .eq('user_id', user.id)
      .eq('entity_id', currentEntity.id)
      .order('date', { ascending: false });

    if (repError) {
      console.error('Error fetching loan repayments:', repError);
    } else {
      setRepayments(repData || []);
    }

    setLoading(false);
  }, [user, currentEntity]);

  useEffect(() => {
    fetchLiabilities();
  }, [fetchLiabilities]);

  const addLiability = async (liability) => {
    const received_type = liability.received_type || 'cash';
    
    // Create base liability object matching DB schema
    const newLiability = {
      user_id: user.id,
      entity_id: currentEntity.id,
      name: liability.name,
      type: liability.type,
      principal: liability.principal,
      interest_rate: liability.interest_rate || 0,
      due_date: liability.due_date || null,
      remaining_balance: liability.remaining_balance,
      notes: liability.notes || ''
    };

    let liabilityData;

    // If account_id is provided and type is cash, we use the RPC to also add money to the account
    if (received_type === 'cash' && liability.account_id) {
      const { data, error } = await supabase.rpc('process_new_loan', {
        p_user_id: user.id,
        p_entity_id: currentEntity.id,
        p_name: liability.name,
        p_type: liability.type,
        p_principal: liability.principal,
        p_interest_rate: liability.interest_rate || 0,
        p_due_date: liability.due_date || null,
        p_notes: liability.notes || '',
        p_account_id: liability.account_id
      });
      if (error) throw error;
      await fetchLiabilities();
      return data;
    } else {
      // Insert liability directly
      const { data, error } = await supabase
        .from('liabilities')
        .insert(newLiability)
        .select()
        .single();
      if (error) throw error;
      liabilityData = data;
      setLiabilities([data, ...liabilities]);
    }

    // Handle Asset Creation for EMI
    if (received_type === 'asset' && liability.asset_name) {
      const { error: assetError } = await supabase
        .from('assets')
        .insert({
          user_id: user.id,
          entity_id: currentEntity.id,
          name: liability.asset_name,
          type: liability.asset_type || 'Other',
          value: liability.principal,
          purchase_date: liability.due_date || new Date().toISOString().split('T')[0],
          purchase_value: liability.principal,
          current_value: liability.principal
        });
      if (assetError) console.error("Error creating asset:", assetError);
    }

    // Handle Expense Creation for Baki
    if (received_type === 'expense' && liability.expense_category_id) {
      const { error: expError } = await supabase
        .from('transactions')
        .insert({
          user_id: user.id,
          entity_id: currentEntity.id,
          category_id: liability.expense_category_id,
          type: 'expense',
          amount: liability.principal,
          date: liability.due_date || new Date().toISOString().split('T')[0],
          description: `Credit Purchase: ${liability.name}`
        });
      if (expError) console.error("Error creating expense:", expError);
    }

    return liabilityData;
  };

  const updateLiability = async (id, updates) => {
    const dbUpdates = { ...updates };
    delete dbUpdates.account_id;
    delete dbUpdates.received_type;
    delete dbUpdates.asset_name;
    delete dbUpdates.asset_type;
    delete dbUpdates.expense_category_id;
    if (!dbUpdates.due_date) dbUpdates.due_date = null; // '' is invalid for a DATE column

    const { data, error } = await supabase
      .from('liabilities')
      .update(dbUpdates)
      .eq('id', id)
      .eq('user_id', user.id)
      .select()
      .single();
    if (error) throw error;
    setLiabilities(liabilities.map(l => l.id === id ? data : l));
    return data;
  };

  const deleteLiability = async (id) => {
    const { error } = await supabase
      .from('liabilities')
      .delete()
      .eq('id', id)
      .eq('user_id', user.id);
    if (error) throw error;
    setLiabilities(liabilities.filter(l => l.id !== id));
  };

  const repayLiability = async (liabilityId, accountId, amount, date, notes) => {
    const { data, error } = await supabase.rpc('process_loan_repayment', {
      p_user_id: user.id,
      p_entity_id: currentEntity.id,
      p_liability_id: liabilityId,
      p_account_id: accountId,
      p_amount: amount,
      p_date: date,
      p_notes: notes
    });
    if (error) throw error;
    await fetchLiabilities();
    return data;
  };

  const increaseLiability = async (liabilityId, amount, expenseCategoryId, date, description) => {
    const l = liabilities.find(x => x.id === liabilityId);
    if (!l) throw new Error("Liability not found");
    
    const newPrincipal = Number(l.principal) + Number(amount);
    const newRemaining = Number(l.remaining_balance) + Number(amount);
    
    const { error: updateError } = await supabase
      .from('liabilities')
      .update({ principal: newPrincipal, remaining_balance: newRemaining })
      .eq('id', liabilityId)
      .eq('user_id', user.id);
      
    if (updateError) throw updateError;
    
    if (expenseCategoryId) {
      const { error: expError } = await supabase
        .from('transactions')
        .insert({
          user_id: user.id,
          entity_id: currentEntity.id,
          category_id: expenseCategoryId,
          type: 'expense',
          amount: amount,
          date: date || new Date().toISOString().split('T')[0],
          description: description || `Added due to ${l.name}`
        });
      if (expError) console.error("Error creating expense:", expError);
    }
    
    await fetchLiabilities();
  };

  return { liabilities, repayments, loading, fetchLiabilities, addLiability, updateLiability, deleteLiability, repayLiability, increaseLiability };
}

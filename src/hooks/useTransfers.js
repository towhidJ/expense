import { useState, useEffect, useCallback } from 'react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../context/AuthContext';
import { useEntity } from '../context/EntityContext';

export function useTransfers() {
  const { user } = useAuth();
  const { currentEntity } = useEntity();
  const [transfers, setTransfers] = useState([]);
  const [loading, setLoading] = useState(true);

  const fetchTransfers = useCallback(async () => {
    if (!user || !currentEntity) return;
    setLoading(true);
    
    // We fetch transfers and join with accounts to get the names
    const { data, error } = await supabase
      .from('transfers')
      .select(`
        *,
        from_account:from_account_id(name),
        to_account:to_account_id(name)
      `)
      .eq('user_id', user.id)
      .eq('entity_id', currentEntity.id)
      .order('date', { ascending: false });

    if (error) {
      console.error('Error fetching transfers:', error);
    } else {
      setTransfers(data || []);
    }
    setLoading(false);
  }, [user, currentEntity]);

  useEffect(() => {
    fetchTransfers();
  }, [fetchTransfers]);

  const addTransfer = async (transfer) => {
    // Call the RPC function defined in migration v3
    const { data, error } = await supabase.rpc('process_transfer', {
      p_user_id: user.id,
      p_entity_id: currentEntity.id,
      p_from_account: transfer.from_account_id,
      p_to_account: transfer.to_account_id,
      p_amount: transfer.amount,
      p_date: transfer.date,
      p_notes: transfer.notes
    });

    if (error) throw error;
    await fetchTransfers();
    return data;
  };

  return { transfers, loading, fetchTransfers, addTransfer };
}

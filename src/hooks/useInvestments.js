import { useState, useEffect, useCallback } from 'react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../context/AuthContext';
import { useEntity } from '../context/EntityContext';

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

  return { investments, loading, fetchInvestments, addInvestment, updateInvestment, deleteInvestment };
}

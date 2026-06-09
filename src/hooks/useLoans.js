import { useState, useEffect, useCallback } from 'react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../context/AuthContext';

export function useLoans() {
  const { user } = useAuth();
  const [loans, setLoans] = useState([]);
  const [loading, setLoading] = useState(true);

  const fetchLoans = useCallback(async () => {
    if (!user) return;
    setLoading(true);
    const { data, error } = await supabase
      .from('loans')
      .select('*')
      .eq('user_id', user.id)
      .order('created_at', { ascending: false });
    if (error) console.error('Error fetching loans:', error);
    else setLoans(data || []);
    setLoading(false);
  }, [user]);

  const addLoan = async (loan) => {
    const { error } = await supabase.from('loans').insert({
      ...loan,
      user_id: user.id
    });
    if (error) throw error;
    await fetchLoans();
  };

  const updateLoan = async (id, updates) => {
    const { error } = await supabase
      .from('loans')
      .update(updates)
      .eq('id', id)
      .eq('user_id', user.id);
    if (error) throw error;
    await fetchLoans();
  };

  const deleteLoan = async (id) => {
    const { error } = await supabase
      .from('loans')
      .delete()
      .eq('id', id)
      .eq('user_id', user.id);
    if (error) throw error;
    await fetchLoans();
  };

  useEffect(() => {
    if (user) fetchLoans();
  }, [user, fetchLoans]);

  return { loans, loading, fetchLoans, addLoan, updateLoan, deleteLoan };
}

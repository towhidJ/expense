import { useState, useEffect, useCallback } from 'react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../context/AuthContext';

export function useDues() {
  const { user } = useAuth();
  const [dues, setDues] = useState([]);
  const [loading, setLoading] = useState(true);

  const fetchDues = useCallback(async () => {
    if (!user) return;
    setLoading(true);
    const { data, error } = await supabase
      .from('dues')
      .select('*')
      .eq('user_id', user.id)
      .order('due_date', { ascending: true });
    if (error) console.error('Error fetching dues:', error);
    else setDues(data || []);
    setLoading(false);
  }, [user]);

  const addDue = async (due) => {
    const { error } = await supabase.from('dues').insert({
      ...due,
      user_id: user.id
    });
    if (error) throw error;
    await fetchDues();
  };

  const updateDue = async (id, updates) => {
    const { error } = await supabase
      .from('dues')
      .update(updates)
      .eq('id', id)
      .eq('user_id', user.id);
    if (error) throw error;
    await fetchDues();
  };

  const deleteDue = async (id) => {
    const { error } = await supabase
      .from('dues')
      .delete()
      .eq('id', id)
      .eq('user_id', user.id);
    if (error) throw error;
    await fetchDues();
  };

  useEffect(() => {
    if (user) fetchDues();
  }, [user, fetchDues]);

  return { dues, loading, fetchDues, addDue, updateDue, deleteDue };
}

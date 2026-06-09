import { useState, useEffect, useCallback } from 'react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../context/AuthContext';
import { useEntity } from '../context/EntityContext';

export function useGoals() {
  const { user } = useAuth();
  const { currentEntity } = useEntity();
  const [goals, setGoals] = useState([]);
  const [loading, setLoading] = useState(true);

  const fetchGoals = useCallback(async () => {
    if (!user || !currentEntity) return;
    setLoading(true);
    const { data, error } = await supabase
      .from('goals')
      .select('*')
      .eq('user_id', user.id)
      .eq('entity_id', currentEntity.id)
      .order('created_at', { ascending: false });

    if (error) {
      console.error('Error fetching goals:', error);
    } else {
      setGoals(data || []);
    }
    setLoading(false);
  }, [user, currentEntity]);

  useEffect(() => {
    fetchGoals();
  }, [fetchGoals]);

  const addGoal = async (goal) => {
    const { data, error } = await supabase
      .from('goals')
      .insert({ ...goal, user_id: user.id, entity_id: currentEntity.id })
      .select()
      .single();
    if (error) throw error;
    setGoals([data, ...goals]);
    return data;
  };

  const updateGoal = async (id, updates) => {
    const { data, error } = await supabase
      .from('goals')
      .update(updates)
      .eq('id', id)
      .eq('user_id', user.id)
      .select()
      .single();
    if (error) throw error;
    setGoals(goals.map(g => g.id === id ? data : g));
    return data;
  };

  const deleteGoal = async (id) => {
    const { error } = await supabase
      .from('goals')
      .delete()
      .eq('id', id)
      .eq('user_id', user.id);
    if (error) throw error;
    setGoals(goals.filter(g => g.id !== id));
  };

  return { goals, loading, fetchGoals, addGoal, updateGoal, deleteGoal };
}

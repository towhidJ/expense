import { useState, useEffect, useCallback } from 'react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../context/AuthContext';
import { useEntity } from '../context/EntityContext';

export function useFamily() {
  const { user } = useAuth();
  const { currentEntity } = useEntity();
  const [members, setMembers] = useState([]);
  const [loading, setLoading] = useState(true);

  const fetchMembers = useCallback(async () => {
    // Only fetch if current entity is 'family' or just fetch all for the user
    // Depending on logic, family members could belong to personal or family entity. Let's filter by currentEntity
    if (!user || !currentEntity) return;
    setLoading(true);
    const { data, error } = await supabase
      .from('family_members')
      .select('*')
      .eq('user_id', user.id)
      .eq('entity_id', currentEntity.id)
      .order('created_at', { ascending: false });

    if (error) {
      console.error('Error fetching family members:', error);
    } else {
      setMembers(data || []);
    }
    setLoading(false);
  }, [user, currentEntity]);

  useEffect(() => {
    fetchMembers();
  }, [fetchMembers]);

  const addMember = async (member) => {
    const { data, error } = await supabase
      .from('family_members')
      .insert({ ...member, user_id: user.id, entity_id: currentEntity.id })
      .select()
      .single();
    if (error) throw error;
    setMembers([data, ...members]);
    return data;
  };

  const updateMember = async (id, updates) => {
    const { data, error } = await supabase
      .from('family_members')
      .update(updates)
      .eq('id', id)
      .eq('user_id', user.id)
      .select()
      .single();
    if (error) throw error;
    setMembers(members.map(m => m.id === id ? data : m));
    return data;
  };

  const deleteMember = async (id) => {
    const { error } = await supabase
      .from('family_members')
      .delete()
      .eq('id', id)
      .eq('user_id', user.id);
    if (error) throw error;
    setMembers(members.filter(m => m.id !== id));
  };

  return { members, loading, fetchMembers, addMember, updateMember, deleteMember };
}

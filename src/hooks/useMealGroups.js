import { useState, useEffect, useCallback } from 'react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../context/AuthContext';

// Meal groups (mess) are shared across users and NOT entity-scoped: the group
// itself is the scope, membership is checked by RLS (see migration v16).
export function useMealGroups() {
  const { user } = useAuth();
  const [memberships, setMemberships] = useState([]);
  const [activeGroupId, setActiveGroupId] = useState(() => localStorage.getItem('meal_active_group') || null);
  const [loading, setLoading] = useState(true);

  const fetchMemberships = useCallback(async () => {
    if (!user) return;
    setLoading(true);
    const { data, error } = await supabase
      .from('meal_group_members')
      .select('*, meal_groups(*)')
      .eq('user_id', user.id)
      .in('status', ['pending', 'approved'])
      .order('created_at', { ascending: true });
    if (error) console.error('Error fetching meal groups:', error);
    setMemberships(data || []);
    setLoading(false);
  }, [user]);

  useEffect(() => {
    fetchMemberships();
  }, [fetchMemberships]);

  const approved = memberships.filter(m => m.status === 'approved');
  const pending = memberships.filter(m => m.status === 'pending');
  const activeMembership =
    approved.find(m => m.group_id === activeGroupId) || approved[0] || null;

  const switchGroup = (groupId) => {
    setActiveGroupId(groupId);
    localStorage.setItem('meal_active_group', groupId);
  };

  const createGroup = async (name, displayName) => {
    const { data: groupId, error } = await supabase.rpc('create_meal_group', {
      p_name: name,
      p_display_name: displayName || null
    });
    if (error) throw error;
    await fetchMemberships();
    switchGroup(groupId);
    return groupId;
  };

  const joinByCode = async (code, displayName) => {
    const { data: groupId, error } = await supabase.rpc('join_meal_group', {
      p_code: code,
      p_display_name: displayName || null
    });
    if (error) throw error;
    await fetchMemberships();
    return groupId;
  };

  const leaveGroup = async (groupId) => {
    const { error } = await supabase.rpc('leave_meal_group', { p_group_id: groupId });
    if (error) throw error;
    if (activeGroupId === groupId) {
      localStorage.removeItem('meal_active_group');
      setActiveGroupId(null);
    }
    await fetchMemberships();
  };

  return {
    memberships,
    approved,
    pending,
    activeMembership,
    loading,
    fetchMemberships,
    switchGroup,
    createGroup,
    joinByCode,
    leaveGroup
  };
}

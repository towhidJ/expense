import { useState, useEffect, useCallback } from 'react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../context/AuthContext';
import { useEntity } from '../context/EntityContext';

// Generic entity-scoped CRUD for simple tables (insurance_policies,
// utility_bills, rental_units, split_events, …). For anything that moves
// money, keep using the dedicated RPC-backed hooks.
export function useEntityTable(table, { select = '*', orderBy = 'created_at', ascending = false } = {}) {
  const { user } = useAuth();
  const { currentEntity } = useEntity();
  const [rows, setRows] = useState([]);
  const [loading, setLoading] = useState(true);

  const fetchRows = useCallback(async () => {
    if (!user || !currentEntity) return;
    setLoading(true);
    const { data, error } = await supabase
      .from(table)
      .select(select)
      .eq('user_id', user.id)
      .eq('entity_id', currentEntity.id)
      .order(orderBy, { ascending });
    if (error) console.error(`Error fetching ${table}:`, error);
    else setRows(data || []);
    setLoading(false);
  }, [user, currentEntity, table, select, orderBy, ascending]);

  useEffect(() => {
    fetchRows();
  }, [fetchRows]);

  const addRow = async (row) => {
    const { data, error } = await supabase
      .from(table)
      .insert({ ...row, user_id: user.id, entity_id: currentEntity.id })
      .select()
      .single();
    if (error) throw error;
    await fetchRows();
    return data;
  };

  const updateRow = async (id, updates) => {
    const { data, error } = await supabase
      .from(table)
      .update(updates)
      .eq('id', id)
      .eq('user_id', user.id)
      .select()
      .single();
    if (error) throw error;
    await fetchRows();
    return data;
  };

  const deleteRow = async (id) => {
    const { error } = await supabase
      .from(table)
      .delete()
      .eq('id', id)
      .eq('user_id', user.id);
    if (error) throw error;
    setRows(prev => prev.filter(r => r.id !== id));
  };

  return { rows, loading, fetchRows, addRow, updateRow, deleteRow };
}

import { useState, useEffect, useCallback } from 'react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../context/AuthContext';
import { useEntity } from '../context/EntityContext';

export function useAssets() {
  const { user } = useAuth();
  const { currentEntity } = useEntity();
  const [assets, setAssets] = useState([]);
  const [loading, setLoading] = useState(true);

  const fetchAssets = useCallback(async () => {
    if (!user || !currentEntity) return;
    setLoading(true);
    const { data, error } = await supabase
      .from('assets')
      .select('*')
      .eq('user_id', user.id)
      .eq('entity_id', currentEntity.id)
      .order('purchase_date', { ascending: false });
    
    if (error) {
      console.error('Error fetching assets:', error);
    } else {
      setAssets(data || []);
    }
    setLoading(false);
  }, [user, currentEntity]);

  const addAsset = async (asset) => {
    const { error } = await supabase.from('assets').insert({
      ...asset,
      user_id: user.id,
      entity_id: currentEntity.id
    });
    if (error) throw error;
    await fetchAssets();
  };

  const updateAsset = async (id, updates) => {
    const { error } = await supabase
      .from('assets')
      .update(updates)
      .eq('id', id)
      .eq('user_id', user.id);
    if (error) throw error;
    await fetchAssets();
  };

  const deleteAsset = async (id) => {
    // Unlink transactions first — the FK on transactions.asset_id blocks
    // deleting an asset that still has linked expenses
    const { error: unlinkError } = await supabase
      .from('transactions')
      .update({ asset_id: null })
      .eq('asset_id', id)
      .eq('user_id', user.id);
    if (unlinkError) throw unlinkError;

    const { error } = await supabase
      .from('assets')
      .delete()
      .eq('id', id)
      .eq('user_id', user.id);
    if (error) throw error;
    await fetchAssets();
  };

  useEffect(() => {
    if (user) fetchAssets();
  }, [user, fetchAssets]);

  return { assets, loading, fetchAssets, addAsset, updateAsset, deleteAsset };
}

import { useState, useEffect, useCallback } from 'react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../context/AuthContext';
import { useEntity } from '../context/EntityContext';

// Monthly net-worth series for the current entity. The dashboard calls
// recordSnapshot with the numbers it just computed; the current month is
// upserted (so it keeps refreshing until the month ends) and past months
// stay frozen — a timeline with no cron job.
export function useNetWorthSnapshots() {
  const { user } = useAuth();
  const { currentEntity } = useEntity();
  const [snapshots, setSnapshots] = useState([]);

  const fetchSnapshots = useCallback(async () => {
    if (!user || !currentEntity) return;
    const { data, error } = await supabase
      .from('net_worth_snapshots')
      .select('*')
      .eq('user_id', user.id)
      .eq('entity_id', currentEntity.id)
      .order('year', { ascending: true })
      .order('month', { ascending: true })
      .limit(24);
    if (error) {
      console.error('Error fetching net worth snapshots:', error);
    } else {
      setSnapshots(data || []);
    }
  }, [user, currentEntity]);

  useEffect(() => {
    fetchSnapshots();
  }, [fetchSnapshots]);

  const recordSnapshot = useCallback(async ({ cash, assets, investments, receivables, liabilities, netWorth }) => {
    if (!user || !currentEntity) return;
    const now = new Date();
    const { error } = await supabase.from('net_worth_snapshots').upsert(
      {
        user_id: user.id,
        entity_id: currentEntity.id,
        year: now.getFullYear(),
        month: now.getMonth() + 1,
        cash, assets, investments, receivables, liabilities,
        net_worth: netWorth,
        captured_at: now.toISOString()
      },
      { onConflict: 'user_id,entity_id,year,month' }
    );
    if (error) {
      console.error('Error recording net worth snapshot:', error);
    } else {
      await fetchSnapshots();
    }
  }, [user, currentEntity, fetchSnapshots]);

  return { snapshots, recordSnapshot };
}

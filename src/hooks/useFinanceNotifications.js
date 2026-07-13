import { useState, useEffect, useCallback } from 'react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../context/AuthContext';

// Budget-overspend / bill-due alerts (v28), server-generated daily by
// check_budget_and_bill_alerts() via pg_cron. Same shape and read/mark-read
// pattern as the meal module's meal_notifications (useMealData.js).
export function useFinanceNotifications() {
  const { user } = useAuth();
  const [notifications, setNotifications] = useState([]);
  const [loading, setLoading] = useState(true);

  const fetchNotifications = useCallback(async () => {
    if (!user) return;
    setLoading(true);
    const { data, error } = await supabase
      .from('finance_notifications')
      .select('*')
      .eq('user_id', user.id)
      .order('created_at', { ascending: false })
      .limit(50);
    if (error) console.error('Error fetching finance notifications:', error);
    setNotifications(data || []);
    setLoading(false);
  }, [user]);

  useEffect(() => { fetchNotifications(); }, [fetchNotifications]);

  const markAllRead = async () => {
    const unread = notifications.filter(n => !n.is_read);
    if (unread.length === 0) return;
    const { error } = await supabase.from('finance_notifications')
      .update({ is_read: true }).in('id', unread.map(n => n.id));
    if (error) throw error;
    await fetchNotifications();
  };

  const deleteNotification = async (id) => {
    const { error } = await supabase.from('finance_notifications').delete().eq('id', id);
    if (error) throw error;
    await fetchNotifications();
  };

  return { notifications, loading, fetchNotifications, markAllRead, deleteNotification };
}

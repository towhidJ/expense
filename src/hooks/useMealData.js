import { useState, useEffect, useCallback } from 'react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../context/AuthContext';

const pad = (n) => String(n).padStart(2, '0');

// All data for one meal group in one month. Month math (meal rate, balances)
// comes from the get_meal_month_summary RPC so web and mobile always agree.
export function useMealData(groupId, year, month) {
  const { user } = useAuth();
  const [group, setGroup] = useState(null);
  const [members, setMembers] = useState([]);
  const [entries, setEntries] = useState([]);
  const [deposits, setDeposits] = useState([]);
  const [expenses, setExpenses] = useState([]);
  const [dutyTypes, setDutyTypes] = useState([]);
  const [dutyAssignments, setDutyAssignments] = useState([]);
  const [advances, setAdvances] = useState([]);
  const [holidays, setHolidays] = useState([]);
  const [requests, setRequests] = useState([]);
  const [notices, setNotices] = useState([]);
  const [shoppingItems, setShoppingItems] = useState([]);
  const [sharedExpenses, setSharedExpenses] = useState([]);
  const [notifications, setNotifications] = useState([]);
  const [summary, setSummary] = useState(null);
  const [paymentInfo, setPaymentInfo] = useState(null);
  const [stockItems, setStockItems] = useState([]);
  const [rotationOrders, setRotationOrders] = useState([]);
  const [loading, setLoading] = useState(true);

  const start = `${year}-${pad(month)}-01`;
  const end = month === 12 ? `${year + 1}-01-01` : `${year}-${pad(month + 1)}-01`;

  const fetchGroup = useCallback(async () => {
    if (!groupId) return;
    const { data, error } = await supabase
      .from('meal_groups').select('*').eq('id', groupId).single();
    if (error) console.error('Error fetching meal group:', error);
    setGroup(data || null);
  }, [groupId]);

  const fetchMembers = useCallback(async () => {
    if (!groupId) return;
    const { data, error } = await supabase
      .from('meal_group_members')
      .select('*')
      .eq('group_id', groupId)
      .order('created_at', { ascending: true });
    if (error) console.error('Error fetching meal members:', error);
    setMembers(data || []);
  }, [groupId]);

  const fetchEntries = useCallback(async () => {
    if (!groupId) return;
    const { data, error } = await supabase
      .from('meal_entries')
      .select('*')
      .eq('group_id', groupId)
      .gte('date', start)
      .lt('date', end);
    if (error) console.error('Error fetching meal entries:', error);
    setEntries(data || []);
  }, [groupId, start, end]);

  const fetchDeposits = useCallback(async () => {
    if (!groupId) return;
    const { data, error } = await supabase
      .from('meal_deposits')
      .select('*')
      .eq('group_id', groupId)
      .gte('date', start)
      .lt('date', end)
      .order('date', { ascending: false })
      .order('created_at', { ascending: false });
    if (error) console.error('Error fetching meal deposits:', error);
    setDeposits(data || []);
  }, [groupId, start, end]);

  const fetchExpenses = useCallback(async () => {
    if (!groupId) return;
    const { data, error } = await supabase
      .from('meal_expenses')
      .select('*')
      .eq('group_id', groupId)
      .gte('date', start)
      .lt('date', end)
      .order('date', { ascending: false })
      .order('created_at', { ascending: false });
    if (error) console.error('Error fetching meal expenses:', error);
    setExpenses(data || []);
  }, [groupId, start, end]);

  const fetchDutyTypes = useCallback(async () => {
    if (!groupId) return;
    const { data, error } = await supabase
      .from('meal_duty_types')
      .select('*')
      .eq('group_id', groupId)
      .order('sort_order', { ascending: true });
    if (error) console.error('Error fetching duty types:', error);
    setDutyTypes(data || []);
  }, [groupId]);

  const fetchDutyAssignments = useCallback(async () => {
    if (!groupId) return;
    const { data, error } = await supabase
      .from('meal_duty_assignments')
      .select('*')
      .eq('group_id', groupId)
      .gte('date', start)
      .lt('date', end);
    if (error) console.error('Error fetching duty assignments:', error);
    setDutyAssignments(data || []);
  }, [groupId, start, end]);

  // Advances (জামানত) are lifetime, not month-scoped
  const fetchAdvances = useCallback(async () => {
    if (!groupId) return;
    const { data, error } = await supabase
      .from('meal_advances')
      .select('*')
      .eq('group_id', groupId)
      .order('date', { ascending: false })
      .order('created_at', { ascending: false });
    if (error) console.error('Error fetching meal advances:', error);
    setAdvances(data || []);
  }, [groupId]);

  const fetchHolidays = useCallback(async () => {
    if (!groupId) return;
    const { data, error } = await supabase
      .from('meal_holidays')
      .select('*')
      .eq('group_id', groupId)
      .gte('date', start)
      .lt('date', end)
      .order('date', { ascending: true });
    if (error) console.error('Error fetching meal holidays:', error);
    setHolidays(data || []);
  }, [groupId, start, end]);

  const fetchRequests = useCallback(async () => {
    if (!groupId) return;
    const { data, error } = await supabase
      .from('meal_requests')
      .select('*')
      .eq('group_id', groupId)
      .gte('date', start)
      .lt('date', end)
      .order('date', { ascending: false })
      .order('created_at', { ascending: false });
    if (error) console.error('Error fetching meal requests:', error);
    setRequests(data || []);
  }, [groupId, start, end]);

  // Notices are group-wide, not month-scoped
  const fetchNotices = useCallback(async () => {
    if (!groupId) return;
    const { data, error } = await supabase
      .from('meal_notices')
      .select('*')
      .eq('group_id', groupId)
      .order('pinned', { ascending: false })
      .order('created_at', { ascending: false });
    if (error) console.error('Error fetching meal notices:', error);
    setNotices(data || []);
  }, [groupId]);

  // Active shopping list = rows not yet converted into an expense
  const fetchShopping = useCallback(async () => {
    if (!groupId) return;
    const { data, error } = await supabase
      .from('meal_shopping_items')
      .select('*')
      .eq('group_id', groupId)
      .is('expense_id', null)
      .order('created_at', { ascending: true });
    if (error) console.error('Error fetching shopping items:', error);
    setShoppingItems(data || []);
  }, [groupId]);

  const fetchShared = useCallback(async () => {
    if (!groupId) return;
    const { data, error } = await supabase
      .from('meal_shared_expenses')
      .select('*, meal_shared_expense_shares(*)')
      .eq('group_id', groupId)
      .gte('date', start)
      .lt('date', end)
      .order('date', { ascending: false })
      .order('created_at', { ascending: false });
    if (error) console.error('Error fetching shared expenses:', error);
    setSharedExpenses(data || []);
  }, [groupId, start, end]);

  const fetchNotifications = useCallback(async () => {
    if (!groupId || !user) return;
    const { data, error } = await supabase
      .from('meal_notifications')
      .select('*')
      .eq('group_id', groupId)
      .eq('user_id', user.id)
      .order('created_at', { ascending: false })
      .limit(50);
    if (error) console.error('Error fetching notifications:', error);
    setNotifications(data || []);
  }, [groupId, user]);

  const fetchSummary = useCallback(async () => {
    if (!groupId) return;
    const { data, error } = await supabase.rpc('get_meal_month_summary', {
      p_group_id: groupId,
      p_year: year,
      p_month: month
    });
    if (error) console.error('Error fetching meal summary:', error);
    setSummary(data || null);
  }, [groupId, year, month]);

  // bKash/Nagad payment info (v23) — one row per group, may not exist yet
  const fetchPaymentInfo = useCallback(async () => {
    if (!groupId) return;
    const { data, error } = await supabase
      .from('meal_group_payment_info').select('*').eq('group_id', groupId).maybeSingle();
    if (error) console.error('Error fetching payment info:', error);
    setPaymentInfo(data || null);
  }, [groupId]);

  // Stock/inventory tracker (v27)
  const fetchStockItems = useCallback(async () => {
    if (!groupId) return;
    const { data, error } = await supabase
      .from('meal_stock_items').select('*').eq('group_id', groupId).order('name', { ascending: true });
    if (error) console.error('Error fetching stock items:', error);
    setStockItems(data || []);
  }, [groupId]);

  // Duty rotation order (v26)
  const fetchRotationOrders = useCallback(async () => {
    if (!groupId || dutyTypes.length === 0) { setRotationOrders([]); return; }
    const { data, error } = await supabase
      .from('meal_duty_rotation_order')
      .select('*')
      .in('duty_type_id', dutyTypes.map(t => t.id))
      .order('sort_order', { ascending: true });
    if (error) console.error('Error fetching rotation order:', error);
    setRotationOrders(data || []);
  }, [groupId, dutyTypes]);

  const fetchAll = useCallback(async () => {
    setLoading(true);
    await Promise.all([
      fetchGroup(), fetchMembers(), fetchEntries(), fetchDeposits(),
      fetchExpenses(), fetchDutyTypes(), fetchDutyAssignments(),
      fetchAdvances(), fetchHolidays(), fetchRequests(), fetchNotices(),
      fetchShopping(), fetchShared(), fetchNotifications(), fetchSummary(),
      fetchPaymentInfo(), fetchStockItems()
    ]);
    setLoading(false);
  }, [fetchGroup, fetchMembers, fetchEntries, fetchDeposits, fetchExpenses,
      fetchDutyTypes, fetchDutyAssignments, fetchAdvances, fetchHolidays,
      fetchRequests, fetchNotices, fetchShopping, fetchShared,
      fetchNotifications, fetchSummary, fetchPaymentInfo, fetchStockItems]);

  useEffect(() => { fetchRotationOrders(); }, [fetchRotationOrders]);

  useEffect(() => {
    fetchAll();
  }, [fetchAll]);

  // ---- Meal entries (RPC: member edits own row, manager edits anyone's) ----

  const upsertEntry = async (memberId, date, counts) => {
    const { error } = await supabase.rpc('upsert_meal_entry', {
      p_group_id: groupId,
      p_member_id: memberId,
      p_date: date,
      p_breakfast: counts.breakfast ?? 0,
      p_lunch: counts.lunch ?? 0,
      p_dinner: counts.dinner ?? 0,
      p_guest_breakfast: counts.guest_breakfast ?? 0,
      p_guest_lunch: counts.guest_lunch ?? 0,
      p_guest_dinner: counts.guest_dinner ?? 0
    });
    if (error) throw error;
    await Promise.all([fetchEntries(), fetchSummary()]);
  };

  // ---- Deposits (manager only, enforced by RLS) ----

  const addDeposit = async ({ member_id, amount, date, note }) => {
    const { error } = await supabase.from('meal_deposits').insert({
      group_id: groupId, member_id, amount, date,
      note: note || null, added_by: user.id
    });
    if (error) throw error;
    await Promise.all([fetchDeposits(), fetchSummary()]);
  };

  const updateDeposit = async (id, { member_id, amount, date, note }) => {
    const { error } = await supabase.from('meal_deposits')
      .update({ member_id, amount, date, note: note || null })
      .eq('id', id);
    if (error) throw error;
    await Promise.all([fetchDeposits(), fetchSummary()]);
  };

  const deleteDeposit = async (id) => {
    const { error } = await supabase.from('meal_deposits').delete().eq('id', id);
    if (error) throw error;
    await Promise.all([fetchDeposits(), fetchSummary()]);
  };

  // ---- Expenses (any member adds; author or manager edits) ----

  // Upload one receipt image/file to the public documents bucket under the
  // group's folder; returns { url, path } to store on the expense row.
  const uploadReceipt = async (file) => {
    const safe = file.name.replace(/[^a-zA-Z0-9._-]/g, '_');
    const path = `meal/${groupId}/${Date.now()}_${safe}`;
    const { error } = await supabase.storage
      .from('documents')
      .upload(path, file, { cacheControl: '3600', upsert: false });
    if (error) throw error;
    const { data } = supabase.storage.from('documents').getPublicUrl(path);
    return { url: data.publicUrl, path };
  };

  const addExpense = async ({ expense_type, amount, date, note, spent_by, items, attachment_url, attachment_path }) => {
    const { error } = await supabase.from('meal_expenses').insert({
      group_id: groupId, expense_type, amount, date,
      note: note || null, spent_by: spent_by || null, added_by: user.id,
      items: items || [],
      attachment_url: attachment_url || null,
      attachment_path: attachment_path || null
    });
    if (error) throw error;
    await Promise.all([fetchExpenses(), fetchSummary()]);
  };

  const updateExpense = async (id, { expense_type, amount, date, note, spent_by, items, attachment_url, attachment_path }) => {
    const patch = {
      expense_type, amount, date,
      note: note || null, spent_by: spent_by || null,
      items: items || []
    };
    if (attachment_url !== undefined) {
      patch.attachment_url = attachment_url;
      patch.attachment_path = attachment_path;
    }
    const { error } = await supabase.from('meal_expenses').update(patch).eq('id', id);
    if (error) throw error;
    await Promise.all([fetchExpenses(), fetchSummary()]);
  };

  const deleteExpense = async (id) => {
    const { error } = await supabase.from('meal_expenses').delete().eq('id', id);
    if (error) throw error;
    await Promise.all([fetchExpenses(), fetchSummary()]);
  };

  // ---- Advances / জামানত (manager only, enforced by RLS) ----

  const addAdvance = async ({ member_id, type, amount, date, note }) => {
    const { error } = await supabase.from('meal_advances').insert({
      group_id: groupId, member_id, type, amount, date,
      note: note || null, added_by: user.id
    });
    if (error) throw error;
    await Promise.all([fetchAdvances(), fetchSummary()]);
  };

  // Pay a member's dues from their advance: advance goes down, deposit goes up
  const adjustAdvance = async ({ member_id, amount, date, note }) => {
    const { error } = await supabase.rpc('adjust_meal_advance', {
      p_member_id: member_id, p_amount: amount, p_date: date, p_note: note || null
    });
    if (error) throw error;
    await Promise.all([fetchAdvances(), fetchDeposits(), fetchSummary()]);
  };

  const deleteAdvance = async (id) => {
    const { error } = await supabase.from('meal_advances').delete().eq('id', id);
    if (error) throw error;
    await Promise.all([fetchAdvances(), fetchSummary()]);
  };

  // ---- Holidays / feast days (manager only, enforced by RLS) ----

  const upsertHoliday = async ({ date, title, menu }) => {
    const { error } = await supabase.from('meal_holidays').upsert(
      { group_id: groupId, date, title: title || 'Meal Holiday', menu: menu || null },
      { onConflict: 'group_id,date' }
    );
    if (error) throw error;
    await fetchHolidays();
  };

  const deleteHoliday = async (id) => {
    const { error } = await supabase.from('meal_holidays').delete().eq('id', id);
    if (error) throw error;
    await fetchHolidays();
  };

  // ---- Month close / carry-forward (manager only, enforced by RPC) ----

  const closeMonth = async (note) => {
    const { error } = await supabase.rpc('close_meal_month', {
      p_group_id: groupId, p_year: year, p_month: month, p_note: note || null
    });
    if (error) throw error;
    await fetchSummary();
  };

  const reopenMonth = async () => {
    const { error } = await supabase.rpc('reopen_meal_month', {
      p_group_id: groupId, p_year: year, p_month: month
    });
    if (error) throw error;
    await fetchSummary();
  };

  // ---- Meal off / guest requests (RPCs enforce cutoff + roles) ----

  const submitRequest = async ({ date, type, breakfast, lunch, dinner, note }) => {
    const { error } = await supabase.rpc('submit_meal_request', {
      p_group_id: groupId, p_date: date, p_type: type,
      p_breakfast: breakfast ?? 0, p_lunch: lunch ?? 0, p_dinner: dinner ?? 0,
      p_note: note || null
    });
    if (error) throw error;
    await fetchRequests();
  };

  const cancelRequest = async (id) => {
    const { error } = await supabase.rpc('cancel_meal_request', { p_request_id: id });
    if (error) throw error;
    await fetchRequests();
  };

  // Approving writes the meal entry (off → slots 0, guest → counts added)
  const respondRequest = async (id, approve) => {
    const { error } = await supabase.rpc('respond_meal_request', {
      p_request_id: id, p_approve: approve
    });
    if (error) throw error;
    await Promise.all([fetchRequests(), fetchEntries(), fetchSummary()]);
  };

  // ---- Notice board (manager only, enforced by RLS) ----

  const addNotice = async ({ title, body, pinned }) => {
    const { error } = await supabase.from('meal_notices').insert({
      group_id: groupId, title, body: body || null,
      pinned: !!pinned, created_by: user.id
    });
    if (error) throw error;
    await fetchNotices();
  };

  const updateNotice = async (id, { title, body, pinned }) => {
    const { error } = await supabase.from('meal_notices')
      .update({ title, body: body || null, pinned: !!pinned, updated_at: new Date().toISOString() })
      .eq('id', id);
    if (error) throw error;
    await fetchNotices();
  };

  const deleteNotice = async (id) => {
    const { error } = await supabase.from('meal_notices').delete().eq('id', id);
    if (error) throw error;
    await fetchNotices();
  };

  // ---- Shopping list (any member; delete = author or manager via RLS) ----

  const addShoppingItem = async ({ name, qty }) => {
    const { error } = await supabase.from('meal_shopping_items').insert({
      group_id: groupId, name, qty: qty || null, added_by: user.id
    });
    if (error) throw error;
    await fetchShopping();
  };

  const toggleShoppingItem = async (id, bought) => {
    const { error } = await supabase.from('meal_shopping_items')
      .update({
        is_bought: bought,
        bought_by: bought ? user.id : null,
        bought_at: bought ? new Date().toISOString() : null
      })
      .eq('id', id);
    if (error) throw error;
    await fetchShopping();
  };

  const deleteShoppingItem = async (id) => {
    const { error } = await supabase.from('meal_shopping_items').delete().eq('id', id);
    if (error) throw error;
    await fetchShopping();
  };

  // Turn the ticked-off items into one itemized bazar expense, then archive
  // them from the active list by stamping expense_id.
  const convertShoppingToExpense = async ({ itemIds, amount, date, note }) => {
    const items = shoppingItems
      .filter(it => itemIds.includes(it.id))
      .map(it => ({ name: it.qty ? `${it.name} (${it.qty})` : it.name, amount: null }));
    const { data: expense, error } = await supabase.from('meal_expenses')
      .insert({
        group_id: groupId, expense_type: 'bazar', amount, date,
        note: note || 'From shopping list', added_by: user.id, items
      })
      .select('id')
      .single();
    if (error) throw error;
    const { error: linkError } = await supabase.from('meal_shopping_items')
      .update({ expense_id: expense.id })
      .in('id', itemIds);
    if (linkError) throw linkError;
    await Promise.all([fetchShopping(), fetchExpenses(), fetchSummary()]);
  };

  // ---- Shared bills (rent/wifi/gas — separate from the meal ledger) ----

  const createSharedExpense = async ({ title, amount, date, split_type, shares, note }) => {
    const { error } = await supabase.rpc('create_shared_expense', {
      p_group_id: groupId, p_title: title, p_amount: amount, p_date: date,
      p_split_type: split_type, p_shares: shares, p_note: note || null
    });
    if (error) throw error;
    await fetchShared();
  };

  const toggleSharePaid = async (shareId, paid) => {
    const { error } = await supabase.from('meal_shared_expense_shares')
      .update({ paid, paid_at: paid ? new Date().toISOString() : null })
      .eq('id', shareId);
    if (error) throw error;
    await fetchShared();
  };

  const deleteSharedExpense = async (id) => {
    const { error } = await supabase.from('meal_shared_expenses').delete().eq('id', id);
    if (error) throw error;
    await fetchShared();
  };

  // ---- Notifications (own rows only, enforced by RLS) ----

  const markNotificationsRead = async () => {
    const unread = notifications.filter(n => !n.is_read);
    if (unread.length === 0) return;
    const { error } = await supabase.from('meal_notifications')
      .update({ is_read: true })
      .in('id', unread.map(n => n.id));
    if (error) throw error;
    await fetchNotifications();
  };

  const deleteNotification = async (id) => {
    const { error } = await supabase.from('meal_notifications').delete().eq('id', id);
    if (error) throw error;
    await fetchNotifications();
  };

  // ---- Duty roster (manager only, enforced by RLS) ----

  const addDutyType = async (name) => {
    const maxOrder = dutyTypes.reduce((m, t) => Math.max(m, t.sort_order || 0), 0);
    const { error } = await supabase.from('meal_duty_types').insert({
      group_id: groupId, name, is_builtin: false, sort_order: maxOrder + 1
    });
    if (error) throw error;
    await fetchDutyTypes();
  };

  const updateDutyType = async (id, patch) => {
    const { error } = await supabase.from('meal_duty_types').update(patch).eq('id', id);
    if (error) throw error;
    await fetchDutyTypes();
  };

  const deleteDutyType = async (id) => {
    const { error } = await supabase.from('meal_duty_types').delete().eq('id', id);
    if (error) throw error;
    await Promise.all([fetchDutyTypes(), fetchDutyAssignments()]);
  };

  const assignDuty = async ({ duty_type_id, member_id, date, note }) => {
    const { error } = await supabase.from('meal_duty_assignments').insert({
      group_id: groupId, duty_type_id, member_id, date, note: note || null
    });
    if (error) throw error;
    await fetchDutyAssignments();
  };

  const removeDutyAssignment = async (id) => {
    const { error } = await supabase.from('meal_duty_assignments').delete().eq('id', id);
    if (error) throw error;
    await fetchDutyAssignments();
  };

  // ---- Auto duty rotation (manager only, enforced by RPC — v26) ----

  const setRotationOrder = async (dutyTypeId, memberIds) => {
    const { error } = await supabase.rpc('set_duty_rotation_order', {
      p_duty_type_id: dutyTypeId, p_member_ids: memberIds
    });
    if (error) throw error;
    await fetchRotationOrders();
  };

  const generateDutyRotation = async (dutyTypeId, startDate, days) => {
    const { data, error } = await supabase.rpc('generate_duty_rotation', {
      p_duty_type_id: dutyTypeId, p_start_date: startDate, p_days: days
    });
    if (error) throw error;
    await fetchDutyAssignments();
    return data || [];
  };

  // ---- Members ----

  const respondJoinRequest = async (memberId, approve) => {
    const { error } = await supabase.rpc('respond_meal_join_request', {
      p_member_id: memberId, p_approve: approve
    });
    if (error) throw error;
    await Promise.all([fetchMembers(), fetchSummary()]);
  };

  const removeMember = async (memberId) => {
    const { error } = await supabase.rpc('remove_meal_member', { p_member_id: memberId });
    if (error) throw error;
    await Promise.all([fetchMembers(), fetchSummary()]);
  };

  const setMemberRole = async (memberId, role) => {
    const { error } = await supabase.rpc('set_meal_member_role', {
      p_member_id: memberId, p_role: role
    });
    if (error) throw error;
    await fetchMembers();
  };

  // ---- Settings (manager only, enforced by RLS) ----

  const updateGroup = async (patch) => {
    const { error } = await supabase.from('meal_groups').update(patch).eq('id', groupId);
    if (error) throw error;
    await Promise.all([fetchGroup(), fetchSummary()]);
  };

  const regenerateCode = async () => {
    const { data, error } = await supabase.rpc('regenerate_meal_invite_code', {
      p_group_id: groupId
    });
    if (error) throw error;
    await fetchGroup();
    return data;
  };

  // ---- bKash/Nagad payment info (manager only, enforced by RLS — v23) ----

  const updatePaymentInfo = async ({ bkash_number, nagad_number }) => {
    const { error } = await supabase.from('meal_group_payment_info').upsert(
      { group_id: groupId, bkash_number: bkash_number || null, nagad_number: nagad_number || null, updated_at: new Date().toISOString() },
      { onConflict: 'group_id' }
    );
    if (error) throw error;
    await fetchPaymentInfo();
  };

  // ---- Trend charts + item price history (read-only RPCs — v24, v25) ----

  const fetchTrend = async (monthsBack = 6) => {
    const { data, error } = await supabase.rpc('get_meal_trend', {
      p_group_id: groupId, p_months_back: monthsBack
    });
    if (error) throw error;
    return data || [];
  };

  const fetchItemNames = async () => {
    const { data, error } = await supabase.rpc('get_meal_item_names', { p_group_id: groupId });
    if (error) throw error;
    return (data || []).map(r => r.name);
  };

  const fetchItemPriceHistory = async (itemName) => {
    const { data, error } = await supabase.rpc('get_meal_item_price_history', {
      p_group_id: groupId, p_item_name: itemName
    });
    if (error) throw error;
    return data || [];
  };

  // ---- Stock/inventory tracker (any member; delete = manager — v27) ----

  const addStockItem = async ({ name, quantity, unit, low_stock_threshold, expiry_date }) => {
    const { error } = await supabase.from('meal_stock_items').insert({
      group_id: groupId, name, quantity: Number(quantity) || 0,
      unit: unit || null, low_stock_threshold: low_stock_threshold === '' || low_stock_threshold == null ? null : Number(low_stock_threshold),
      expiry_date: expiry_date || null
    });
    if (error) throw error;
    await fetchStockItems();
  };

  const adjustStock = async (id, delta) => {
    const { error } = await supabase.rpc('adjust_meal_stock', { p_stock_id: id, p_delta: delta });
    if (error) throw error;
    await fetchStockItems();
  };

  const updateStockItem = async (id, patch) => {
    const { error } = await supabase.from('meal_stock_items').update(patch).eq('id', id);
    if (error) throw error;
    await fetchStockItems();
  };

  const deleteStockItem = async (id) => {
    const { error } = await supabase.from('meal_stock_items').delete().eq('id', id);
    if (error) throw error;
    await fetchStockItems();
  };

  return {
    group, members, entries, deposits, expenses,
    dutyTypes, dutyAssignments, advances, holidays, requests, notices,
    shoppingItems, sharedExpenses, notifications, summary, loading,
    paymentInfo, stockItems, rotationOrders,
    fetchAll,
    upsertEntry,
    addDeposit, updateDeposit, deleteDeposit,
    addExpense, updateExpense, deleteExpense, uploadReceipt,
    addAdvance, adjustAdvance, deleteAdvance,
    upsertHoliday, deleteHoliday,
    closeMonth, reopenMonth,
    submitRequest, cancelRequest, respondRequest,
    addNotice, updateNotice, deleteNotice,
    addShoppingItem, toggleShoppingItem, deleteShoppingItem, convertShoppingToExpense,
    createSharedExpense, toggleSharePaid, deleteSharedExpense,
    markNotificationsRead, deleteNotification,
    addDutyType, updateDutyType, deleteDutyType,
    assignDuty, removeDutyAssignment, setRotationOrder, generateDutyRotation,
    respondJoinRequest, removeMember, setMemberRole,
    updateGroup, regenerateCode,
    updatePaymentInfo, fetchTrend, fetchItemNames, fetchItemPriceHistory,
    addStockItem, adjustStock, updateStockItem, deleteStockItem
  };
}

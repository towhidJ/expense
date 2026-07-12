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
  const [summary, setSummary] = useState(null);
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

  const fetchAll = useCallback(async () => {
    setLoading(true);
    await Promise.all([
      fetchGroup(), fetchMembers(), fetchEntries(), fetchDeposits(),
      fetchExpenses(), fetchDutyTypes(), fetchDutyAssignments(),
      fetchAdvances(), fetchHolidays(), fetchSummary()
    ]);
    setLoading(false);
  }, [fetchGroup, fetchMembers, fetchEntries, fetchDeposits, fetchExpenses,
      fetchDutyTypes, fetchDutyAssignments, fetchAdvances, fetchHolidays, fetchSummary]);

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

  return {
    group, members, entries, deposits, expenses,
    dutyTypes, dutyAssignments, advances, holidays, summary, loading,
    fetchAll,
    upsertEntry,
    addDeposit, updateDeposit, deleteDeposit,
    addExpense, updateExpense, deleteExpense, uploadReceipt,
    addAdvance, adjustAdvance, deleteAdvance,
    upsertHoliday, deleteHoliday,
    addDutyType, updateDutyType, deleteDutyType,
    assignDuty, removeDutyAssignment,
    respondJoinRequest, removeMember, setMemberRole,
    updateGroup, regenerateCode
  };
}

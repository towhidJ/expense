import { useState, useEffect, useCallback } from 'react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../context/AuthContext';
import { useEntity } from '../context/EntityContext';

// Invoices + line items. invoice_items has no user_id/entity_id of its own
// (RLS goes through the invoices FK), so this needs its own hook rather
// than useEntityTable — items are replaced wholesale on every save.
export function useInvoices() {
  const { user } = useAuth();
  const { currentEntity } = useEntity();
  const [invoices, setInvoices] = useState([]);
  const [loading, setLoading] = useState(true);

  const fetchInvoices = useCallback(async () => {
    if (!user || !currentEntity) return;
    setLoading(true);
    const { data, error } = await supabase
      .from('invoices')
      .select('*, invoice_items(*)')
      .eq('user_id', user.id)
      .eq('entity_id', currentEntity.id)
      .order('issue_date', { ascending: false });
    if (error) console.error('Error fetching invoices:', error);
    else setInvoices(data || []);
    setLoading(false);
  }, [user, currentEntity]);

  useEffect(() => { fetchInvoices(); }, [fetchInvoices]);

  const saveInvoice = async (invoice, items, existingId = null) => {
    let invoiceId = existingId;
    if (existingId) {
      const { error } = await supabase.from('invoices').update(invoice).eq('id', existingId).eq('user_id', user.id);
      if (error) throw error;
      const { error: delError } = await supabase.from('invoice_items').delete().eq('invoice_id', existingId);
      if (delError) throw delError;
    } else {
      const { data, error } = await supabase
        .from('invoices')
        .insert({ ...invoice, user_id: user.id, entity_id: currentEntity.id })
        .select()
        .single();
      if (error) throw error;
      invoiceId = data.id;
    }
    if (items.length > 0) {
      const { error } = await supabase.from('invoice_items').insert(
        items.map((it, i) => ({ description: it.description, quantity: it.quantity, unit_price: it.unit_price, invoice_id: invoiceId, sort_order: i }))
      );
      if (error) throw error;
    }
    await fetchInvoices();
    return invoiceId;
  };

  const deleteInvoice = async (id) => {
    const { error } = await supabase.from('invoices').delete().eq('id', id).eq('user_id', user.id);
    if (error) throw error;
    setInvoices(prev => prev.filter(i => i.id !== id));
  };

  const markPaid = async (invoiceId, { account_id, category_id, date }) => {
    const invoice = invoices.find(i => i.id === invoiceId);
    const total = (invoice.invoice_items || []).reduce((s, it) => s + Number(it.quantity) * Number(it.unit_price), 0);
    const { data: txId, error } = await supabase.rpc('process_transaction', {
      p_user_id: user.id,
      p_entity_id: currentEntity.id,
      p_account_id: account_id,
      p_category_id: category_id,
      p_asset_id: null,
      p_type: 'income',
      p_amount: total,
      p_date: date,
      p_description: `Invoice ${invoice.invoice_number} — ${invoice.client_name}`
    });
    if (error) throw error;
    const { error: updError } = await supabase
      .from('invoices')
      .update({ status: 'paid', account_id, transaction_id: txId })
      .eq('id', invoiceId)
      .eq('user_id', user.id);
    if (updError) throw updError;
    await fetchInvoices();
  };

  const updateStatus = async (invoiceId, status) => {
    const { error } = await supabase.from('invoices').update({ status }).eq('id', invoiceId).eq('user_id', user.id);
    if (error) throw error;
    await fetchInvoices();
  };

  return { invoices, loading, fetchInvoices, saveInvoice, deleteInvoice, markPaid, updateStatus };
}

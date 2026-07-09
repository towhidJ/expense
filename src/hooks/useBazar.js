import { useState, useEffect, useCallback } from 'react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../context/AuthContext';
import { useEntity } from '../context/EntityContext';

// Bazar (বাজার) ledger: shops are liabilities of type 'shop_due', every
// purchase (cash or due) is a bazar_purchases row + expense transaction,
// and shop payments reuse the loan repayment flow (see migration v14).
export function useBazar() {
  const { user } = useAuth();
  const { currentEntity } = useEntity();
  const [shops, setShops] = useState([]);
  const [purchases, setPurchases] = useState([]);
  const [payments, setPayments] = useState([]);
  const [loading, setLoading] = useState(true);

  const fetchAll = useCallback(async () => {
    if (!user || !currentEntity) return;
    setLoading(true);

    const { data: shopData, error: shopError } = await supabase
      .from('liabilities')
      .select('*')
      .eq('user_id', user.id)
      .eq('entity_id', currentEntity.id)
      .eq('type', 'shop_due')
      .order('created_at', { ascending: true });
    if (shopError) console.error('Error fetching shops:', shopError);
    const shopList = shopData || [];
    setShops(shopList);

    const { data: purchaseData, error: purchaseError } = await supabase
      .from('bazar_purchases')
      .select('*, accounts(name), liabilities(name)')
      .eq('user_id', user.id)
      .eq('entity_id', currentEntity.id)
      .order('date', { ascending: false })
      .order('created_at', { ascending: false });
    if (purchaseError) console.error('Error fetching bazar purchases:', purchaseError);
    setPurchases(purchaseData || []);

    if (shopList.length > 0) {
      const { data: payData, error: payError } = await supabase
        .from('loan_repayments')
        .select('*, accounts(name), liabilities(name)')
        .eq('user_id', user.id)
        .eq('entity_id', currentEntity.id)
        .in('liability_id', shopList.map(s => s.id))
        .order('date', { ascending: false });
      if (payError) console.error('Error fetching shop payments:', payError);
      setPayments(payData || []);
    } else {
      setPayments([]);
    }

    setLoading(false);
  }, [user, currentEntity]);

  useEffect(() => {
    fetchAll();
  }, [fetchAll]);

  const addShop = async ({ name, phone, notes }) => {
    const { data, error } = await supabase
      .from('liabilities')
      .insert({
        user_id: user.id,
        entity_id: currentEntity.id,
        name,
        type: 'shop_due',
        principal: 0,
        remaining_balance: 0,
        phone: phone || null,
        notes: notes || ''
      })
      .select()
      .single();
    if (error) throw error;
    setShops(prev => [...prev, data]);
    return data;
  };

  const updateShop = async (id, { name, phone, notes }) => {
    const { data, error } = await supabase
      .from('liabilities')
      .update({ name, phone: phone || null, notes: notes || '' })
      .eq('id', id)
      .eq('user_id', user.id)
      .select()
      .single();
    if (error) throw error;
    setShops(prev => prev.map(s => s.id === id ? data : s));
    return data;
  };

  const deleteShop = async (id) => {
    const { error } = await supabase
      .from('liabilities')
      .delete()
      .eq('id', id)
      .eq('user_id', user.id);
    if (error) throw error;
    setShops(prev => prev.filter(s => s.id !== id));
  };

  const addPurchase = async ({ payment_type, account_id, shop_id, category_id, amount, date, description }) => {
    const { data: purchaseId, error } = await supabase.rpc('process_bazar_purchase', {
      p_user_id: user.id,
      p_entity_id: currentEntity.id,
      p_category_id: category_id,
      p_amount: amount,
      p_date: date,
      p_description: description || null,
      p_payment_type: payment_type,
      p_account_id: payment_type === 'cash' ? account_id : null,
      p_liability_id: payment_type === 'due' ? shop_id : null
    });
    if (error) throw error;
    // The RPC returns the purchase id; look up the expense transaction it
    // created so invoices can be attached to it.
    const { data: row } = await supabase
      .from('bazar_purchases')
      .select('transaction_id')
      .eq('id', purchaseId)
      .single();
    await fetchAll();
    return { purchaseId, transactionId: row?.transaction_id || null };
  };

  const deletePurchase = async (id) => {
    const { error } = await supabase.rpc('delete_bazar_purchase', {
      p_user_id: user.id,
      p_purchase_id: id
    });
    if (error) throw error;
    await fetchAll();
  };

  const payShop = async ({ shop_id, account_id, amount, date, notes }) => {
    const { data, error } = await supabase.rpc('process_loan_repayment', {
      p_user_id: user.id,
      p_entity_id: currentEntity.id,
      p_liability_id: shop_id,
      p_account_id: account_id,
      p_amount: amount,
      p_date: date,
      p_notes: notes || null
    });
    if (error) throw error;
    await fetchAll();
    return data;
  };

  return { shops, purchases, payments, loading, fetchAll, addShop, updateShop, deleteShop, addPurchase, deletePurchase, payShop };
}

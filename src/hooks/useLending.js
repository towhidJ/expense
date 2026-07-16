import { useState, useEffect, useCallback, useMemo } from 'react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../context/AuthContext';
import { useEntity } from '../context/EntityContext';

// Person-to-person lending (dena-paona). Rows live in the `liabilities` table
// (type loan_given / loan_taken) with `counterparty` set — money movements go
// through the same balance-safe RPCs the Liabilities page uses.
export function useLending() {
  const { user } = useAuth();
  const { currentEntity } = useEntity();
  const [loans, setLoans] = useState([]);
  const [repayments, setRepayments] = useState([]);
  const [loading, setLoading] = useState(true);

  const fetchLending = useCallback(async () => {
    if (!user || !currentEntity) return;
    setLoading(true);
    const [{ data: loanData, error: loanError }, { data: repData, error: repError }] = await Promise.all([
      supabase
        .from('liabilities')
        .select('*')
        .eq('user_id', user.id)
        .eq('entity_id', currentEntity.id)
        .in('type', ['loan_given', 'loan_taken'])
        .not('counterparty', 'is', null)
        .order('created_at', { ascending: false }),
      supabase
        .from('loan_repayments')
        .select('*, accounts(name)')
        .eq('user_id', user.id)
        .eq('entity_id', currentEntity.id)
        .order('date', { ascending: false })
    ]);

    if (loanError) console.error('Error fetching person loans:', loanError);
    else setLoans((loanData || []).filter(l => l.counterparty)); // belt & suspenders on top of the server filter
    if (repError) console.error('Error fetching loan repayments:', repError);
    else setRepayments(repData || []);
    setLoading(false);
  }, [user, currentEntity]);

  useEffect(() => {
    fetchLending();
  }, [fetchLending]);

  // direction: 'given' (ami dilam — cash out) | 'taken' (ami nilam — cash in).
  // With account_id the RPC moves the account balance; without it the loan is
  // recorded as an opening balance (money changed hands before using the app).
  const addLoan = async ({ direction, person, phone, amount, account_id, due_date, notes }) => {
    const type = direction === 'given' ? 'loan_given' : 'loan_taken';
    let loanId;

    if (account_id) {
      const { data, error } = await supabase.rpc('process_new_loan', {
        p_user_id: user.id,
        p_entity_id: currentEntity.id,
        p_name: person,
        p_type: type,
        p_principal: amount,
        p_interest_rate: 0,
        p_due_date: due_date || null,
        p_notes: notes || '',
        p_account_id: account_id
      });
      if (error) throw error;
      loanId = data;
      // process_new_loan predates the counterparty column — tag the row after.
      const { error: tagError } = await supabase
        .from('liabilities')
        .update({ counterparty: person, phone: phone || null })
        .eq('id', loanId)
        .eq('user_id', user.id);
      if (tagError) throw tagError;
    } else {
      const { data, error } = await supabase
        .from('liabilities')
        .insert({
          user_id: user.id,
          entity_id: currentEntity.id,
          name: person,
          counterparty: person,
          phone: phone || null,
          type,
          principal: amount,
          interest_rate: 0,
          due_date: due_date || null,
          remaining_balance: amount,
          notes: notes || ''
        })
        .select()
        .single();
      if (error) throw error;
      loanId = data.id;
    }

    await fetchLending();
    return loanId;
  };

  // Settle (partially or fully) one loan. Direction is handled inside the RPC:
  // loan_given credits the account, loan_taken debits it.
  const settleLoan = async (loanId, accountId, amount, date, notes) => {
    const { data, error } = await supabase.rpc('process_loan_repayment', {
      p_user_id: user.id,
      p_entity_id: currentEntity.id,
      p_liability_id: loanId,
      p_account_id: accountId,
      p_amount: amount,
      p_date: date,
      p_notes: notes || ''
    });
    if (error) throw error;
    await fetchLending();
    return data;
  };

  const updateLoan = async (id, updates) => {
    const dbUpdates = { ...updates };
    if (!dbUpdates.due_date) dbUpdates.due_date = null; // '' is invalid for a DATE column
    const { error } = await supabase
      .from('liabilities')
      .update(dbUpdates)
      .eq('id', id)
      .eq('user_id', user.id);
    if (error) throw error;
    await fetchLending();
  };

  const deleteLoan = async (id) => {
    const { error } = await supabase
      .from('liabilities')
      .delete()
      .eq('id', id)
      .eq('user_id', user.id);
    if (error) throw error;
    setLoans(loans.filter(l => l.id !== id));
  };

  // Group loans + their repayments per person for the ledger view.
  const people = useMemo(() => {
    const map = new Map();
    for (const loan of loans) {
      const key = (loan.counterparty || loan.name).trim().toLowerCase();
      if (!map.has(key)) {
        map.set(key, {
          key,
          name: loan.counterparty || loan.name,
          phone: loan.phone || null,
          loans: [],
          repayments: [],
          receivable: 0, // they owe me (loan_given remaining)
          payable: 0     // I owe them (loan_taken remaining)
        });
      }
      const p = map.get(key);
      p.loans.push(loan);
      if (!p.phone && loan.phone) p.phone = loan.phone;
      if (loan.type === 'loan_given') p.receivable += Number(loan.remaining_balance);
      else p.payable += Number(loan.remaining_balance);
    }
    const loanIndex = new Map(loans.map(l => [l.id, l]));
    for (const rep of repayments) {
      const loan = loanIndex.get(rep.liability_id);
      if (!loan) continue;
      const key = (loan.counterparty || loan.name).trim().toLowerCase();
      map.get(key)?.repayments.push({ ...rep, loan_type: loan.type });
    }
    return [...map.values()]
      .map(p => ({ ...p, net: p.receivable - p.payable }))
      .sort((a, b) => Math.abs(b.net) - Math.abs(a.net));
  }, [loans, repayments]);

  const totals = useMemo(() => {
    const receivable = people.reduce((s, p) => s + p.receivable, 0);
    const payable = people.reduce((s, p) => s + p.payable, 0);
    return { receivable, payable, net: receivable - payable };
  }, [people]);

  return { loans, repayments, people, totals, loading, fetchLending, addLoan, settleLoan, updateLoan, deleteLoan };
}

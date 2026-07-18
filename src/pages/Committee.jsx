import { useMemo, useState } from 'react';
import { useEntityTable } from '../hooks/useEntityTable';
import { useAccounts } from '../context/AccountContext';
import { useCategories } from '../hooks/useCategories';
import { useAuth } from '../context/AuthContext';
import { useEntity } from '../context/EntityContext';
import { supabase } from '../lib/supabase';
import StatCard from '../components/StatCard';
import { Users, Plus, Trash2, HandCoins, Wallet, TrendingUp } from 'lucide-react';

const fmt = (n) => `৳${Math.round(Number(n || 0)).toLocaleString()}`;
const today = () => new Date().toISOString().split('T')[0];
const monthLabel = (d) => new Date(d).toLocaleDateString('en-US', { month: 'long', year: 'numeric' });

function monthRange(startDate, count) {
  const months = [];
  const start = new Date(startDate);
  start.setDate(1);
  const end = new Date();
  end.setDate(1);
  const n = count && count > 0 ? count : Math.max(1, (end.getFullYear() - start.getFullYear()) * 12 + (end.getMonth() - start.getMonth()) + 1);
  for (let i = 0; i < n; i++) {
    const d = new Date(start);
    d.setMonth(d.getMonth() + i);
    months.push(d.toISOString().split('T')[0]);
  }
  return months;
}

export default function Committee() {
  const { user } = useAuth();
  const { currentEntity } = useEntity();
  const { rows: committees, loading, addRow: addCommittee, deleteRow: deleteCommittee } = useEntityTable('committees');
  const { rows: payments, addRow: addPayment, fetchRows: fetchPayments } = useEntityTable('committee_payments');
  const { accounts, fetchAccounts } = useAccounts();
  const { categories } = useCategories();
  const expenseCategories = categories?.filter(c => c.type === 'expense') || [];
  const incomeCategories = categories?.filter(c => c.type === 'income') || [];

  const [activeCommittee, setActiveCommittee] = useState(null);
  const [adding, setAdding] = useState(false);
  const [form, setForm] = useState({ name: '', monthly_amount: '', total_members: '', your_turn_month: '', start_date: today(), notes: '' });
  const [payModal, setPayModal] = useState(null); // { committee, month, entryType }
  const [payForm, setPayForm] = useState({ account_id: '', category_id: '', amount: '', date: today() });

  const shownId = activeCommittee || committees[0]?.id;
  const shown = committees.find(c => c.id === shownId);
  const shownPayments = useMemo(() => payments.filter(p => p.committee_id === shownId), [payments, shownId]);

  const months = shown ? monthRange(shown.start_date, shown.total_members) : [];

  const totalDeposited = payments.filter(p => p.entry_type === 'deposit').reduce((s, p) => s + Number(p.amount), 0);
  const totalReceived = payments.filter(p => p.entry_type === 'payout').reduce((s, p) => s + Number(p.amount), 0);

  const handleAdd = async (e) => {
    e.preventDefault();
    try {
      const c = await addCommittee({
        ...form,
        monthly_amount: parseFloat(form.monthly_amount),
        total_members: form.total_members ? parseInt(form.total_members) : null,
        your_turn_month: form.your_turn_month ? `${form.your_turn_month}-01` : null
      });
      setActiveCommittee(c.id);
      setAdding(false);
      setForm({ name: '', monthly_amount: '', total_members: '', your_turn_month: '', start_date: today(), notes: '' });
    } catch (err) {
      alert('Error saving committee: ' + err.message);
    }
  };

  const openPayModal = (committee, month, entryType) => {
    setPayModal({ committee, month, entryType });
    setPayForm({ account_id: '', category_id: '', amount: entryType === 'deposit' ? String(committee.monthly_amount) : '', date: today() });
  };

  const handlePay = async (e) => {
    e.preventDefault();
    const { committee, month, entryType } = payModal;
    try {
      const { data: txId, error } = await supabase.rpc('process_transaction', {
        p_user_id: user.id,
        p_entity_id: currentEntity.id,
        p_account_id: payForm.account_id,
        p_category_id: payForm.category_id,
        p_asset_id: null,
        p_type: entryType === 'deposit' ? 'expense' : 'income',
        p_amount: Number(payForm.amount),
        p_date: payForm.date,
        p_description: `${committee.name} — ${entryType === 'deposit' ? 'monthly deposit' : 'payout'} (${monthLabel(month)})`
      });
      if (error) throw error;
      await addPayment({
        committee_id: committee.id,
        pay_month: month,
        amount: Number(payForm.amount),
        entry_type: entryType,
        paid_date: payForm.date,
        transaction_id: txId
      });
      await Promise.all([fetchAccounts(), fetchPayments()]);
      setPayModal(null);
    } catch (err) {
      alert(err.code === '23505' ? 'Already recorded for this month.' : 'Error saving payment: ' + err.message);
    }
  };

  if (loading) return <div className="text-white/50 p-6">Loading committees...</div>;

  return (
    <div className="space-y-6 animate-in">
      <div className="flex justify-between items-center">
        <div>
          <h1 className="text-2xl font-bold text-white">Committee / Samity</h1>
          <p className="text-white/40 text-sm mt-1">Rotating savings group deposits and payout.</p>
        </div>
        <button onClick={() => setAdding(true)} className="flex items-center gap-2 bg-purple-500 hover:bg-purple-600 text-white px-4 py-2 rounded-xl transition-colors shadow-lg shadow-purple-500/20">
          <Plus size={18} /> Add Committee
        </button>
      </div>

      {committees.length === 0 && !adding ? (
        <div className="text-center py-12 border border-white/5 rounded-2xl bg-white/[0.02]">
          <Users className="mx-auto text-white/20 mb-4" size={48} />
          <h3 className="text-white/60 font-medium">No committees yet</h3>
          <p className="text-white/40 text-sm mt-1">Add a group savings committee (samity) to track your deposits and payout turn.</p>
        </div>
      ) : (
        <div className="flex gap-2 flex-wrap">
          {committees.map(c => (
            <button key={c.id} onClick={() => setActiveCommittee(c.id)} className={`px-3.5 py-2 rounded-xl text-sm font-medium transition-all border ${shownId === c.id ? 'bg-purple-500/20 text-purple-400 border-purple-500/40' : 'bg-white/5 text-white/40 border-white/10 hover:bg-white/10'}`}>
              👥 {c.name}
            </button>
          ))}
        </div>
      )}

      {adding && (
        <div className="bg-[#1a1a2e] border border-white/10 rounded-2xl p-6">
          <h2 className="text-lg font-semibold text-white mb-4">New Committee</h2>
          <form onSubmit={handleAdd} className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
            <div>
              <label className="block text-sm text-white/60 mb-1">Name</label>
              <input required type="text" value={form.name} onChange={e => setForm({ ...form, name: e.target.value })} placeholder="e.g. Office Samity" className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-purple-500/50" />
            </div>
            <div>
              <label className="block text-sm text-white/60 mb-1">Monthly Amount</label>
              <input required type="number" step="0.01" value={form.monthly_amount} onChange={e => setForm({ ...form, monthly_amount: e.target.value })} className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-purple-500/50" />
            </div>
            <div>
              <label className="block text-sm text-white/60 mb-1">Total Members</label>
              <input type="number" value={form.total_members} onChange={e => setForm({ ...form, total_members: e.target.value })} placeholder="Optional" className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-purple-500/50" />
            </div>
            <div>
              <label className="block text-sm text-white/60 mb-1">Your Payout Month</label>
              <input type="month" value={form.your_turn_month} onChange={e => setForm({ ...form, your_turn_month: e.target.value })} className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-purple-500/50" />
            </div>
            <div>
              <label className="block text-sm text-white/60 mb-1">Start Date</label>
              <input required type="date" value={form.start_date} onChange={e => setForm({ ...form, start_date: e.target.value })} className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-purple-500/50" />
            </div>
            <div className="lg:col-span-3">
              <label className="block text-sm text-white/60 mb-1">Notes</label>
              <input type="text" value={form.notes} onChange={e => setForm({ ...form, notes: e.target.value })} className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-purple-500/50" />
            </div>
            <div className="lg:col-span-3 flex justify-end gap-3">
              <button type="button" onClick={() => setAdding(false)} className="px-5 py-2.5 rounded-xl text-white/60 hover:text-white hover:bg-white/5 transition-colors">Cancel</button>
              <button type="submit" className="bg-purple-500 hover:bg-purple-600 text-white px-6 py-2.5 rounded-xl shadow-lg shadow-purple-500/20 transition-all font-medium">Save Committee</button>
            </div>
          </form>
        </div>
      )}

      {payModal && (
        <div className="fixed inset-0 bg-black/60 backdrop-blur-sm z-50 flex items-center justify-center p-4">
          <div className="bg-[#1a1a2e] border border-white/10 rounded-2xl p-6 w-full max-w-md shadow-2xl">
            <h2 className="text-xl font-semibold text-white mb-2">{payModal.entryType === 'deposit' ? 'Record Deposit' : 'Record Payout'}</h2>
            <p className="text-sm text-white/50 mb-6">{payModal.committee.name} — {monthLabel(payModal.month)}</p>
            <form onSubmit={handlePay} className="space-y-4">
              <div>
                <label className="block text-sm text-white/60 mb-1">Amount</label>
                <input required type="number" step="0.01" value={payForm.amount} onChange={e => setPayForm({ ...payForm, amount: e.target.value })} className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-purple-500/50" />
              </div>
              <div>
                <label className="block text-sm text-white/60 mb-1">{payModal.entryType === 'deposit' ? 'Pay From Account' : 'Deposit To Account'}</label>
                <select required value={payForm.account_id} onChange={e => setPayForm({ ...payForm, account_id: e.target.value })} className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-purple-500/50">
                  <option value="">Select an account...</option>
                  {accounts.map(a => <option key={a.id} value={a.id}>{a.name}</option>)}
                </select>
              </div>
              <div>
                <label className="block text-sm text-white/60 mb-1">Category</label>
                <select required value={payForm.category_id} onChange={e => setPayForm({ ...payForm, category_id: e.target.value })} className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-purple-500/50">
                  <option value="">Select a category...</option>
                  {(payModal.entryType === 'deposit' ? expenseCategories : incomeCategories).map(c => <option key={c.id} value={c.id}>{c.icon} {c.name}</option>)}
                </select>
              </div>
              <div>
                <label className="block text-sm text-white/60 mb-1">Date</label>
                <input required type="date" value={payForm.date} onChange={e => setPayForm({ ...payForm, date: e.target.value })} className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-purple-500/50" />
              </div>
              <div className="flex justify-end gap-3 mt-6">
                <button type="button" onClick={() => setPayModal(null)} className="px-5 py-2.5 rounded-xl text-white/60 hover:text-white hover:bg-white/5 transition-colors">Cancel</button>
                <button type="submit" className="bg-purple-500 hover:bg-purple-600 text-white px-6 py-2.5 rounded-xl shadow-lg shadow-purple-500/20 transition-all font-medium">Confirm</button>
              </div>
            </form>
          </div>
        </div>
      )}

      {shown && (
        <>
          <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
            <StatCard title="Total Deposited" value={fmt(totalDeposited)} icon={Wallet} gradient={["#a78bfa", "#8b5cf6"]} iconBg="bg-purple-500/10" />
            <StatCard title="Total Received" value={fmt(totalReceived)} icon={HandCoins} gradient={["#34d399", "#10b981"]} iconBg="bg-emerald-500/10" />
            <StatCard title="Net Position" value={fmt(totalReceived - totalDeposited)} icon={TrendingUp} gradient={["#22d3ee", "#06b6d4"]} iconBg="bg-cyan-500/10" />
          </div>

          <div className="bg-[#1a1a2e] border border-white/10 rounded-2xl overflow-hidden">
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead>
                  <tr className="bg-white/5 border-b border-white/10">
                    <th className="text-left py-3 px-5 text-white/60 font-medium">Month</th>
                    <th className="text-left py-3 px-5 text-white/60 font-medium">Deposit</th>
                    <th className="text-left py-3 px-5 text-white/60 font-medium">Payout</th>
                  </tr>
                </thead>
                <tbody>
                  {months.map(m => {
                    const deposit = shownPayments.find(p => p.pay_month === m && p.entry_type === 'deposit');
                    const payout = shownPayments.find(p => p.pay_month === m && p.entry_type === 'payout');
                    const isTurn = shown.your_turn_month === m;
                    return (
                      <tr key={m} className="border-b border-white/5 hover:bg-white/[0.02]">
                        <td className="py-3 px-5 text-white font-medium">{monthLabel(m)}{isTurn && <span className="ml-2 text-[10px] uppercase text-amber-400 bg-amber-500/15 px-1.5 py-0.5 rounded">Your turn</span>}</td>
                        <td className="py-3 px-5">
                          {deposit
                            ? <span className="text-emerald-400 text-xs font-medium">✓ {fmt(deposit.amount)}</span>
                            : <button onClick={() => openPayModal(shown, m, 'deposit')} className="text-xs bg-purple-500/15 text-purple-400 hover:bg-purple-500/25 px-3 py-1.5 rounded-lg font-medium">Mark Paid</button>}
                        </td>
                        <td className="py-3 px-5">
                          {payout
                            ? <span className="text-emerald-400 text-xs font-medium">✓ {fmt(payout.amount)}</span>
                            : isTurn && <button onClick={() => openPayModal(shown, m, 'payout')} className="text-xs bg-emerald-500/15 text-emerald-400 hover:bg-emerald-500/25 px-3 py-1.5 rounded-lg font-medium">Record Payout</button>}
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          </div>

          <div className="flex justify-end">
            <button onClick={() => { if (confirm(`Delete "${shown.name}" and all its payment records?`)) deleteCommittee(shown.id).then(() => setActiveCommittee(null)).catch(err => alert(err.message)); }} className="flex items-center gap-1.5 text-xs text-red-400/70 hover:text-red-400">
              <Trash2 size={13} /> Delete committee
            </button>
          </div>
        </>
      )}
    </div>
  );
}

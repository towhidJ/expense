import { useMemo, useState } from 'react';
import { Link } from 'react-router';
import { useEntityTable } from '../hooks/useEntityTable';
import { useAccounts } from '../context/AccountContext';
import { useCategories } from '../hooks/useCategories';
import { useAuth } from '../context/AuthContext';
import { useEntity } from '../context/EntityContext';
import { supabase } from '../lib/supabase';
import StatCard from '../components/StatCard';
import { HandHeart, Plus, Trash2, Sparkles, Wallet } from 'lucide-react';

const fmt = (n) => `৳${Math.round(Number(n || 0)).toLocaleString()}`;
const today = () => new Date().toISOString().split('T')[0];
const CAT_META = {
  zakat: { label: 'Zakat', icon: '☪️' },
  sadaqah: { label: 'Sadaqah', icon: '🤲' },
  other: { label: 'Other', icon: '❤️' }
};

export default function Charity() {
  const { user } = useAuth();
  const { currentEntity } = useEntity();
  const { rows: donations, loading, addRow, deleteRow } = useEntityTable('charity_donations', { orderBy: 'date' });
  const { accounts, fetchAccounts } = useAccounts();
  const { categories } = useCategories();
  const expenseCategories = categories?.filter(c => c.type === 'expense') || [];

  const [adding, setAdding] = useState(false);
  const initialForm = { recipient: '', category: 'sadaqah', amount: '', date: today(), account_id: '', category_id: '', notes: '' };
  const [form, setForm] = useState(initialForm);

  const currentYear = new Date().getFullYear();
  const yearDonations = useMemo(() => donations.filter(d => new Date(d.date).getFullYear() === currentYear), [donations, currentYear]);
  const yearTotal = yearDonations.reduce((s, d) => s + Number(d.amount), 0);
  const zakatTotal = yearDonations.filter(d => d.category === 'zakat').reduce((s, d) => s + Number(d.amount), 0);
  const sadaqahTotal = yearDonations.filter(d => d.category !== 'zakat').reduce((s, d) => s + Number(d.amount), 0);

  const handleAdd = async (e) => {
    e.preventDefault();
    try {
      const { data: txId, error } = await supabase.rpc('process_transaction', {
        p_user_id: user.id,
        p_entity_id: currentEntity.id,
        p_account_id: form.account_id,
        p_category_id: form.category_id,
        p_asset_id: null,
        p_type: 'expense',
        p_amount: Number(form.amount),
        p_date: form.date,
        p_description: `${CAT_META[form.category].label} — ${form.recipient}`
      });
      if (error) throw error;
      await addRow({
        recipient: form.recipient,
        category: form.category,
        amount: parseFloat(form.amount),
        date: form.date,
        account_id: form.account_id,
        transaction_id: txId,
        notes: form.notes || null
      });
      await fetchAccounts();
      setAdding(false);
      setForm(initialForm);
    } catch (err) {
      alert('Error saving donation: ' + err.message);
    }
  };

  if (loading) return <div className="text-white/50 p-6">Loading donations...</div>;

  return (
    <div className="space-y-6 animate-in">
      <div className="flex justify-between items-center">
        <div>
          <h1 className="text-2xl font-bold text-white">Charity / Sadaqah</h1>
          <p className="text-white/40 text-sm mt-1">
            A ledger of what you've given. Use <Link to="/zakat" className="text-cyan-400 hover:underline">Zakat</Link> to calculate what you owe.
          </p>
        </div>
        <button onClick={() => setAdding(true)} className="flex items-center gap-2 bg-emerald-500 hover:bg-emerald-600 text-white px-4 py-2 rounded-xl transition-colors shadow-lg shadow-emerald-500/20">
          <Plus size={18} /> Log Donation
        </button>
      </div>

      <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
        <StatCard title="This Year Total" value={fmt(yearTotal)} icon={HandHeart} gradient={["#34d399", "#10b981"]} iconBg="bg-emerald-500/10" />
        <StatCard title="Zakat Paid" value={fmt(zakatTotal)} icon={Sparkles} gradient={["#a78bfa", "#8b5cf6"]} iconBg="bg-purple-500/10" />
        <StatCard title="Sadaqah / Other" value={fmt(sadaqahTotal)} icon={Wallet} gradient={["#22d3ee", "#06b6d4"]} iconBg="bg-cyan-500/10" />
      </div>

      {adding && (
        <div className="bg-[#1a1a2e] border border-white/10 rounded-2xl p-6">
          <h2 className="text-lg font-semibold text-white mb-4">New Donation</h2>
          <form onSubmit={handleAdd} className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
            <div>
              <label className="block text-sm text-white/60 mb-1">Recipient</label>
              <input required type="text" value={form.recipient} onChange={e => setForm({ ...form, recipient: e.target.value })} placeholder="e.g. Local Madrasa" className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-emerald-500/50" />
            </div>
            <div>
              <label className="block text-sm text-white/60 mb-1">Category</label>
              <select value={form.category} onChange={e => setForm({ ...form, category: e.target.value })} className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-emerald-500/50">
                {Object.entries(CAT_META).map(([k, v]) => <option key={k} value={k}>{v.icon} {v.label}</option>)}
              </select>
            </div>
            <div>
              <label className="block text-sm text-white/60 mb-1">Amount</label>
              <input required type="number" step="0.01" value={form.amount} onChange={e => setForm({ ...form, amount: e.target.value })} className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-emerald-500/50" />
            </div>
            <div>
              <label className="block text-sm text-white/60 mb-1">From Account</label>
              <select required value={form.account_id} onChange={e => setForm({ ...form, account_id: e.target.value })} className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-emerald-500/50">
                <option value="">Select...</option>
                {accounts.map(a => <option key={a.id} value={a.id}>{a.name}</option>)}
              </select>
            </div>
            <div>
              <label className="block text-sm text-white/60 mb-1">Expense Category</label>
              <select required value={form.category_id} onChange={e => setForm({ ...form, category_id: e.target.value })} className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-emerald-500/50">
                <option value="">Select...</option>
                {expenseCategories.map(c => <option key={c.id} value={c.id}>{c.icon} {c.name}</option>)}
              </select>
            </div>
            <div>
              <label className="block text-sm text-white/60 mb-1">Date</label>
              <input required type="date" value={form.date} onChange={e => setForm({ ...form, date: e.target.value })} className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-emerald-500/50" />
            </div>
            <div className="sm:col-span-2 lg:col-span-3">
              <label className="block text-sm text-white/60 mb-1">Notes</label>
              <input type="text" value={form.notes} onChange={e => setForm({ ...form, notes: e.target.value })} className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-emerald-500/50" />
            </div>
            <div className="sm:col-span-2 lg:col-span-3 flex justify-end gap-3">
              <button type="button" onClick={() => setAdding(false)} className="px-5 py-2.5 rounded-xl text-white/60 hover:text-white hover:bg-white/5 transition-colors">Cancel</button>
              <button type="submit" className="bg-emerald-500 hover:bg-emerald-600 text-white px-6 py-2.5 rounded-xl shadow-lg shadow-emerald-500/20 transition-all font-medium">Save Donation</button>
            </div>
          </form>
        </div>
      )}

      <div className="bg-[#1a1a2e] border border-white/10 rounded-2xl overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="bg-white/5 border-b border-white/10">
                <th className="text-left py-3 px-5 text-white/60 font-medium">Date</th>
                <th className="text-left py-3 px-5 text-white/60 font-medium">Recipient</th>
                <th className="text-left py-3 px-5 text-white/60 font-medium">Category</th>
                <th className="text-right py-3 px-5 text-white/60 font-medium">Amount</th>
                <th className="text-right py-3 px-5 text-white/60 font-medium">Actions</th>
              </tr>
            </thead>
            <tbody>
              {donations.map(d => (
                <tr key={d.id} className="border-b border-white/5 hover:bg-white/[0.02]">
                  <td className="py-3 px-5 text-white/70">{new Date(d.date).toLocaleDateString()}</td>
                  <td className="py-3 px-5 text-white">{d.recipient}</td>
                  <td className="py-3 px-5 text-white/60">{CAT_META[d.category]?.icon} {CAT_META[d.category]?.label}</td>
                  <td className="py-3 px-5 text-right text-emerald-400 font-medium">{fmt(d.amount)}</td>
                  <td className="py-3 px-5 text-right">
                    <button onClick={() => { if (confirm('Delete this donation record? (Linked transaction stays.)')) deleteRow(d.id).catch(err => alert(err.message)); }} className="text-white/30 hover:text-red-400 p-1.5 rounded-lg hover:bg-red-500/10">
                      <Trash2 size={14} />
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        {donations.length === 0 && (
          <div className="text-center py-10">
            <HandHeart className="mx-auto text-white/20 mb-3" size={40} />
            <p className="text-white/40 text-sm">No donations logged yet.</p>
          </div>
        )}
      </div>
    </div>
  );
}

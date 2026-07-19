import { useMemo, useState } from 'react';
import { Link } from 'react-router';
import { useFamily } from '../hooks/useFamily';
import { useTransactions } from '../hooks/useTransactions';
import { useEntityTable } from '../hooks/useEntityTable';
import { useAccounts } from '../context/AccountContext';
import { useCategories } from '../hooks/useCategories';
import StatCard from '../components/StatCard';
import { Users, Plus, PiggyBank, Target, Trash2 } from 'lucide-react';

const fmt = (n) => `৳${Math.round(Number(n || 0)).toLocaleString()}`;
const today = () => new Date().toISOString().split('T')[0];

export default function PocketMoney() {
  const { members, loading: membersLoading } = useFamily();
  const { transactions, addTransaction, deleteTransaction } = useTransactions();
  const { rows: allowances, addRow: addAllowance, updateRow: updateAllowance } = useEntityTable('family_allowances');
  const { accounts } = useAccounts();
  const { categories } = useCategories();
  const expenseCategories = categories?.filter(c => c.type === 'expense') || [];

  const [activeMember, setActiveMember] = useState(null);
  const [giving, setGiving] = useState(false);
  const [form, setForm] = useState({ amount: '', account_id: '', category_id: '', date: today(), notes: '' });
  const [targetInput, setTargetInput] = useState('');

  const shownId = activeMember || members[0]?.id;
  const shown = members.find(m => m.id === shownId);
  const allowance = allowances.find(a => a.family_member_id === shownId);

  const memberTx = useMemo(
    () => transactions.filter(t => t.type === 'expense' && t.family_member_id === shownId).sort((a, b) => b.date.localeCompare(a.date)),
    [transactions, shownId]
  );

  const now = new Date();
  const thisMonthTotal = memberTx
    .filter(t => { const d = new Date(t.date); return d.getMonth() === now.getMonth() && d.getFullYear() === now.getFullYear(); })
    .reduce((s, t) => s + Number(t.amount), 0);

  const yearTotal = memberTx.filter(t => new Date(t.date).getFullYear() === now.getFullYear()).reduce((s, t) => s + Number(t.amount), 0);

  const handleGive = async (e) => {
    e.preventDefault();
    try {
      await addTransaction({
        account_id: form.account_id,
        category_id: form.category_id,
        type: 'expense',
        amount: parseFloat(form.amount),
        date: form.date,
        description: form.notes || `Allowance — ${shown.name}`,
        family_member_id: shownId
      });
      setGiving(false);
      setForm({ amount: '', account_id: '', category_id: '', date: today(), notes: '' });
    } catch (err) {
      alert('Error logging allowance: ' + err.message);
    }
  };

  const saveTarget = async () => {
    try {
      if (allowance) await updateAllowance(allowance.id, { monthly_target: targetInput === '' ? null : parseFloat(targetInput) });
      else await addAllowance({ family_member_id: shownId, monthly_target: parseFloat(targetInput) });
    } catch (err) {
      alert('Error saving target: ' + err.message);
    }
  };

  if (membersLoading) return <div className="text-foreground/50 p-6">Loading family members...</div>;

  return (
    <div className="space-y-6 animate-in">
      <div>
        <h1 className="text-2xl font-bold text-foreground">Pocket Money</h1>
        <p className="text-foreground/40 text-sm mt-1">Track allowance given to each family member against a monthly target.</p>
      </div>

      {members.length === 0 ? (
        <div className="text-center py-12 border border-foreground/5 rounded-2xl bg-white/[0.02]">
          <Users className="mx-auto text-foreground/20 mb-4" size={48} />
          <h3 className="text-foreground/60 font-medium">No family members yet</h3>
          <p className="text-foreground/40 text-sm mt-1">Add family members on the <Link to="/family" className="text-cyan-400 hover:underline">Family</Link> page first.</p>
        </div>
      ) : (
        <>
          <div className="flex gap-2 flex-wrap">
            {members.map(m => (
              <button key={m.id} onClick={() => { setActiveMember(m.id); setTargetInput(''); }} className={`px-3.5 py-2 rounded-xl text-sm font-medium transition-all border ${shownId === m.id ? 'bg-pink-500/20 text-pink-400 border-pink-500/40' : 'bg-foreground/5 text-white/40 border-foreground/10 hover:bg-foreground/10'}`}>
                {m.name}
              </button>
            ))}
          </div>

          {shown && (
            <>
              <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
                <StatCard title="This Month" value={fmt(thisMonthTotal)} icon={PiggyBank} gradient={["#f472b6", "#ec4899"]} iconBg="bg-pink-500/10" />
                <StatCard title="Monthly Target" value={allowance?.monthly_target ? fmt(allowance.monthly_target) : '—'} icon={Target} gradient={["#a78bfa", "#8b5cf6"]} iconBg="bg-purple-500/10" />
                <StatCard title="This Year" value={fmt(yearTotal)} icon={Users} gradient={["#22d3ee", "#06b6d4"]} iconBg="bg-cyan-500/10" />
              </div>

              <div className="bg-card border border-foreground/10 rounded-2xl p-5 flex flex-wrap items-end gap-3">
                <div>
                  <label className="block text-sm text-foreground/60 mb-1">Monthly Target for {shown.name}</label>
                  <input type="number" step="0.01" defaultValue={allowance?.monthly_target ?? ''} onChange={e => setTargetInput(e.target.value)} placeholder="৳" className="w-40 bg-muted border border-foreground/10 rounded-xl px-4 py-2.5 text-foreground focus:outline-none focus:border-pink-500/50" />
                </div>
                <button onClick={saveTarget} className="bg-foreground/5 hover:bg-foreground/10 text-foreground px-4 py-2.5 rounded-xl text-sm transition-colors">Save Target</button>
                <button onClick={() => setGiving(true)} className="ml-auto flex items-center gap-2 bg-pink-500 hover:bg-pink-600 text-white px-4 py-2.5 rounded-xl transition-colors shadow-lg shadow-pink-500/20">
                  <Plus size={16} /> Give Allowance
                </button>
              </div>

              {giving && (
                <div className="bg-card border border-foreground/10 rounded-2xl p-6">
                  <h2 className="text-lg font-semibold text-foreground mb-4">Give Allowance — {shown.name}</h2>
                  <form onSubmit={handleGive} className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
                    <div>
                      <label className="block text-sm text-foreground/60 mb-1">Amount</label>
                      <input required type="number" step="0.01" value={form.amount} onChange={e => setForm({ ...form, amount: e.target.value })} className="w-full bg-muted border border-foreground/10 rounded-xl px-4 py-2.5 text-foreground focus:outline-none focus:border-pink-500/50" />
                    </div>
                    <div>
                      <label className="block text-sm text-foreground/60 mb-1">From Account</label>
                      <select required value={form.account_id} onChange={e => setForm({ ...form, account_id: e.target.value })} className="w-full bg-muted border border-foreground/10 rounded-xl px-4 py-2.5 text-foreground focus:outline-none focus:border-pink-500/50">
                        <option value="">Select...</option>
                        {accounts.map(a => <option key={a.id} value={a.id}>{a.name}</option>)}
                      </select>
                    </div>
                    <div>
                      <label className="block text-sm text-foreground/60 mb-1">Category</label>
                      <select required value={form.category_id} onChange={e => setForm({ ...form, category_id: e.target.value })} className="w-full bg-muted border border-foreground/10 rounded-xl px-4 py-2.5 text-foreground focus:outline-none focus:border-pink-500/50">
                        <option value="">Select...</option>
                        {expenseCategories.map(c => <option key={c.id} value={c.id}>{c.icon} {c.name}</option>)}
                      </select>
                    </div>
                    <div>
                      <label className="block text-sm text-foreground/60 mb-1">Date</label>
                      <input required type="date" value={form.date} onChange={e => setForm({ ...form, date: e.target.value })} className="w-full bg-muted border border-foreground/10 rounded-xl px-4 py-2.5 text-foreground focus:outline-none focus:border-pink-500/50" />
                    </div>
                    <div className="sm:col-span-2 lg:col-span-4">
                      <label className="block text-sm text-foreground/60 mb-1">Notes</label>
                      <input type="text" value={form.notes} onChange={e => setForm({ ...form, notes: e.target.value })} className="w-full bg-muted border border-foreground/10 rounded-xl px-4 py-2.5 text-foreground focus:outline-none focus:border-pink-500/50" />
                    </div>
                    <div className="sm:col-span-2 lg:col-span-4 flex justify-end gap-3">
                      <button type="button" onClick={() => setGiving(false)} className="px-5 py-2.5 rounded-xl text-foreground/60 hover:text-foreground hover:bg-foreground/5 transition-colors">Cancel</button>
                      <button type="submit" className="bg-pink-500 hover:bg-pink-600 text-white px-6 py-2.5 rounded-xl shadow-lg shadow-pink-500/20 transition-all font-medium">Save</button>
                    </div>
                  </form>
                </div>
              )}

              <div className="bg-card border border-foreground/10 rounded-2xl overflow-hidden">
                <div className="overflow-x-auto">
                  <table className="w-full text-sm">
                    <thead>
                      <tr className="bg-foreground/5 border-b border-foreground/10">
                        <th className="text-left py-3 px-5 text-foreground/60 font-medium">Date</th>
                        <th className="text-left py-3 px-5 text-foreground/60 font-medium">Notes</th>
                        <th className="text-right py-3 px-5 text-foreground/60 font-medium">Amount</th>
                        <th className="text-right py-3 px-5 text-foreground/60 font-medium">Actions</th>
                      </tr>
                    </thead>
                    <tbody>
                      {memberTx.map(t => (
                        <tr key={t.id} className="border-b border-foreground/5 hover:bg-white/[0.02]">
                          <td className="py-3 px-5 text-foreground/70">{new Date(t.date).toLocaleDateString()}</td>
                          <td className="py-3 px-5 text-foreground/60">{t.description || '—'}</td>
                          <td className="py-3 px-5 text-right text-foreground font-medium">{fmt(t.amount)}</td>
                          <td className="py-3 px-5 text-right">
                            <button onClick={() => { if (confirm('Delete this allowance entry?')) deleteTransaction(t.id).catch(err => alert(err.message)); }} className="text-white/30 hover:text-red-400 p-1.5 rounded-lg hover:bg-red-500/10">
                              <Trash2 size={14} />
                            </button>
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
                {memberTx.length === 0 && (
                  <div className="text-center py-10">
                    <PiggyBank className="mx-auto text-foreground/20 mb-3" size={40} />
                    <p className="text-foreground/40 text-sm">No allowance logged for {shown.name} yet.</p>
                  </div>
                )}
              </div>
            </>
          )}
        </>
      )}
    </div>
  );
}

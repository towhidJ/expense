import { useState } from 'react';
import { Plus, Edit2, Trash2, PiggyBank } from 'lucide-react';
import PaymentQR from './PaymentQR';

const fmt = (n) => `৳${Number(n || 0).toLocaleString()}`;
const todayISO = () => new Date().toISOString().slice(0, 10);

export default function DepositsTab({ deposits, members, isManager, addDeposit, updateDeposit, deleteDeposit, paymentInfo, groupName }) {
  const approvedMembers = members.filter(m => m.status === 'approved');
  const memberName = (id) => members.find(m => m.id === id)?.display_name || 'Unknown';

  const initialForm = { member_id: '', amount: '', date: todayISO(), note: '' };
  const [form, setForm] = useState(initialForm);
  const [isAdding, setIsAdding] = useState(false);
  const [editing, setEditing] = useState(null);

  const total = deposits.reduce((s, d) => s + Number(d.amount), 0);

  const handleSubmit = async (e) => {
    e.preventDefault();
    try {
      const payload = { ...form, amount: Number(form.amount) };
      if (editing) await updateDeposit(editing.id, payload);
      else await addDeposit(payload);
      setIsAdding(false);
      setEditing(null);
      setForm(initialForm);
    } catch (err) {
      console.error(err);
      alert('Error saving deposit: ' + err.message);
    }
  };

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap justify-between items-center gap-3">
        <p className="text-foreground/60 text-sm">
          Total deposits this month: <span className="text-emerald-400 font-semibold">{fmt(total)}</span>
        </p>
        <PaymentQR paymentInfo={paymentInfo} groupName={groupName} amount={form.amount} />
        {isManager && (
          <button
            onClick={() => { setIsAdding(true); setEditing(null); setForm(initialForm); }}
            className="flex items-center gap-2 bg-emerald-500 hover:bg-emerald-600 text-white px-4 py-2 rounded-xl transition-colors shadow-lg shadow-emerald-500/20"
          >
            <Plus size={18} /> Add Deposit
          </button>
        )}
      </div>

      {(isAdding || editing) && (
        <div className="bg-card border border-foreground/10 rounded-2xl p-6">
          <h2 className="text-lg font-semibold text-foreground mb-4">{editing ? 'Edit Deposit' : 'New Deposit'}</h2>
          <form onSubmit={handleSubmit} className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div>
              <label className="block text-sm text-foreground/60 mb-1">Member</label>
              <select required value={form.member_id} onChange={e => setForm({ ...form, member_id: e.target.value })} className="w-full bg-muted border border-foreground/10 rounded-xl px-4 py-2.5 text-foreground focus:outline-none focus:border-emerald-500/50">
                <option value="">Select member</option>
                {approvedMembers.map(m => <option key={m.id} value={m.id}>{m.display_name}</option>)}
              </select>
            </div>
            <div>
              <label className="block text-sm text-foreground/60 mb-1">Amount (৳)</label>
              <input required type="number" min="0.01" step="0.01" value={form.amount} onChange={e => setForm({ ...form, amount: e.target.value })} className="w-full bg-muted border border-foreground/10 rounded-xl px-4 py-2.5 text-foreground focus:outline-none focus:border-emerald-500/50" />
            </div>
            <div>
              <label className="block text-sm text-foreground/60 mb-1">Date</label>
              <input required type="date" value={form.date} onChange={e => setForm({ ...form, date: e.target.value })} className="w-full bg-muted border border-foreground/10 rounded-xl px-4 py-2.5 text-foreground focus:outline-none focus:border-emerald-500/50" />
            </div>
            <div>
              <label className="block text-sm text-foreground/60 mb-1">Note</label>
              <input type="text" value={form.note} onChange={e => setForm({ ...form, note: e.target.value })} className="w-full bg-muted border border-foreground/10 rounded-xl px-4 py-2.5 text-foreground focus:outline-none focus:border-emerald-500/50" placeholder="optional" />
            </div>
            <div className="sm:col-span-2 flex justify-end gap-3 mt-2">
              <button type="button" onClick={() => { setIsAdding(false); setEditing(null); }} className="px-5 py-2.5 rounded-xl text-foreground/60 hover:text-foreground hover:bg-foreground/5 transition-colors">Cancel</button>
              <button type="submit" className="bg-emerald-500 hover:bg-emerald-600 text-white px-6 py-2.5 rounded-xl shadow-lg shadow-emerald-500/20 transition-all font-medium">Save</button>
            </div>
          </form>
        </div>
      )}

      <div className="bg-card border border-foreground/10 rounded-2xl divide-y divide-foreground/5">
        {deposits.map(d => (
          <div key={d.id} className="flex items-center gap-3 px-4 py-3">
            <div className="w-9 h-9 rounded-xl bg-emerald-500/10 text-emerald-400 flex items-center justify-center shrink-0">
              <PiggyBank size={18} />
            </div>
            <div className="flex-1 min-w-0">
              <p className="text-foreground text-sm font-medium truncate">{memberName(d.member_id)}</p>
              <p className="text-foreground/40 text-xs">{d.date}{d.note ? ` · ${d.note}` : ''}</p>
            </div>
            <span className="text-emerald-400 font-semibold">{fmt(d.amount)}</span>
            {isManager && (
              <div className="flex gap-1 ml-2">
                <button onClick={() => { setEditing(d); setIsAdding(false); setForm({ member_id: d.member_id, amount: d.amount, date: d.date, note: d.note || '' }); }} className="p-1.5 rounded-lg bg-muted border border-foreground/10 text-foreground/60 hover:text-cyan-400">
                  <Edit2 size={14} />
                </button>
                <button onClick={() => { if (confirm('Delete this deposit?')) deleteDeposit(d.id).catch(err => alert('Cannot delete: ' + err.message)); }} className="p-1.5 rounded-lg bg-muted border border-foreground/10 text-foreground/60 hover:text-red-400">
                  <Trash2 size={14} />
                </button>
              </div>
            )}
          </div>
        ))}
        {deposits.length === 0 && (
          <div className="px-4 py-10 text-center text-foreground/40 text-sm">
            No deposits this month.{isManager ? ' Add the first one.' : ''}
          </div>
        )}
      </div>
      {!isManager && <p className="text-foreground/30 text-xs">Only the manager records deposits (they receive the cash).</p>}
    </div>
  );
}

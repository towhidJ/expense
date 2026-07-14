import { useState } from 'react';
import { Plus, Trash2 } from 'lucide-react';

const fmt = (n) => `৳${Number(n || 0).toLocaleString()}`;
const todayISO = () => new Date().toISOString().slice(0, 10);

// Contribution/withdrawal history for one investment (v29) — feeds XIRR.
// Shown inline under an investment row in Investments.jsx.
export default function ContributionHistory({ contributions, onAdd, onDelete }) {
  const initialForm = { date: todayISO(), amount: '', type: 'contribution' };
  const [form, setForm] = useState(initialForm);
  const [saving, setSaving] = useState(false);

  const handleAdd = async (e) => {
    e.preventDefault();
    setSaving(true);
    try {
      await onAdd({ date: form.date, amount: Number(form.amount), type: form.type });
      setForm(initialForm);
    } catch (err) {
      alert('Error adding contribution: ' + err.message);
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="space-y-3">
      <p className="text-white/50 text-xs">
        Contribution history feeds an accurate XIRR (needs at least 2 entries) — until then the CAGR estimate above is used.
      </p>
      <div className="divide-y divide-white/5">
        {contributions.map(c => (
          <div key={c.id} className="flex items-center gap-3 py-1.5 text-sm">
            <span className="text-white/50 w-24">{c.date}</span>
            <span className={`flex-1 ${c.type === 'withdrawal' ? 'text-orange-400' : 'text-emerald-400'}`}>
              {c.type === 'withdrawal' ? '−' : '+'}{fmt(c.amount)}
            </span>
            <span className="text-white/30 text-xs capitalize">{c.type}</span>
            <button onClick={() => onDelete(c.id).catch(err => alert(err.message))} className="text-white/30 hover:text-red-400 p-1">
              <Trash2 size={13} />
            </button>
          </div>
        ))}
        {contributions.length === 0 && <p className="text-white/30 text-xs py-2">No contributions logged yet.</p>}
      </div>
      <form onSubmit={handleAdd} className="flex flex-wrap items-end gap-2">
        <div>
          <label className="block text-[11px] text-white/40 mb-1">Date</label>
          <input required type="date" value={form.date} onChange={e => setForm({ ...form, date: e.target.value })} className="bg-[#12122a] border border-white/10 rounded-lg px-3 py-1.5 text-white text-sm focus:outline-none focus:border-cyan-500/50" />
        </div>
        <div>
          <label className="block text-[11px] text-white/40 mb-1">Amount (৳)</label>
          <input required type="number" min="0.01" step="0.01" value={form.amount} onChange={e => setForm({ ...form, amount: e.target.value })} className="w-28 bg-[#12122a] border border-white/10 rounded-lg px-3 py-1.5 text-white text-sm focus:outline-none focus:border-cyan-500/50" />
        </div>
        <div>
          <label className="block text-[11px] text-white/40 mb-1">Type</label>
          <select value={form.type} onChange={e => setForm({ ...form, type: e.target.value })} className="bg-[#12122a] border border-white/10 rounded-lg px-3 py-1.5 text-white text-sm focus:outline-none focus:border-cyan-500/50">
            <option value="contribution">Contribution</option>
            <option value="withdrawal">Withdrawal</option>
          </select>
        </div>
        <button type="submit" disabled={saving} className="flex items-center gap-1.5 bg-cyan-500 hover:bg-cyan-600 text-white px-3 py-1.5 rounded-lg text-sm font-medium disabled:opacity-50">
          <Plus size={14} /> Add
        </button>
      </form>
    </div>
  );
}

import { useState } from 'react';
import { Plus, Trash2, ShieldCheck, ArrowDownLeft, ArrowUpRight, Scale } from 'lucide-react';

const fmt = (n) => `৳${Number(n || 0).toLocaleString()}`;
const todayISO = () => new Date().toISOString().slice(0, 10);

const TYPE_META = {
  taken: { label: 'Advance taken', icon: ArrowDownLeft, cls: 'text-emerald-400 bg-emerald-500/10' },
  returned: { label: 'Advance returned', icon: ArrowUpRight, cls: 'text-orange-400 bg-orange-500/10' },
  adjusted: { label: 'Adjusted to dues', icon: Scale, cls: 'text-purple-400 bg-purple-500/10' }
};

// জামানত (security advance): taken when a member joins, returned when they
// leave, or adjusted against their bokeya (which creates a deposit).
export default function AdvancesSection({ advances, members, isManager, addAdvance, adjustAdvance, deleteAdvance }) {
  const approvedMembers = members.filter(m => m.status === 'approved');
  const memberName = (id) => members.find(m => m.id === id)?.display_name || 'Unknown';

  const balances = {};
  for (const a of advances) {
    balances[a.member_id] = (balances[a.member_id] || 0) +
      (a.type === 'taken' ? Number(a.amount) : -Number(a.amount));
  }
  const totalHeld = Object.values(balances).reduce((s, v) => s + v, 0);

  const initialForm = { member_id: '', type: 'taken', amount: '', date: todayISO(), note: '' };
  const [form, setForm] = useState(initialForm);
  const [isAdding, setIsAdding] = useState(false);
  const [showAll, setShowAll] = useState(false);

  const balanceOf = (memberId) => balances[memberId] || 0;

  const handleSubmit = async (e) => {
    e.preventDefault();
    const amount = Number(form.amount);
    try {
      if (form.type === 'adjusted') {
        await adjustAdvance({ member_id: form.member_id, amount, date: form.date, note: form.note });
      } else {
        if (form.type === 'returned' && amount > balanceOf(form.member_id)) {
          alert(`Return (${fmt(amount)}) is more than the advance balance (${fmt(balanceOf(form.member_id))}).`);
          return;
        }
        await addAdvance({ member_id: form.member_id, type: form.type, amount, date: form.date, note: form.note });
      }
      setIsAdding(false);
      setForm(initialForm);
    } catch (err) {
      console.error(err);
      alert('Error saving advance: ' + err.message);
    }
  };

  const visible = showAll ? advances : advances.slice(0, 6);
  const membersWithBalance = [...approvedMembers.map(m => ({ ...m, adv: balanceOf(m.id) }))]
    .concat(members.filter(m => m.status !== 'approved' && balanceOf(m.id) !== 0).map(m => ({ ...m, adv: balanceOf(m.id) })));

  return (
    <div className="bg-card border border-foreground/10 rounded-2xl p-6 space-y-4">
      <div className="flex flex-wrap justify-between items-center gap-3">
        <div>
          <h3 className="text-foreground font-semibold flex items-center gap-2">
            <ShieldCheck size={18} className="text-emerald-400" /> Advance (জামানত)
          </h3>
          <p className="text-foreground/40 text-xs mt-1">
            Taken when a member joins; returned when they leave, or adjusted against their dues.
            Mess is holding <span className="text-emerald-400 font-medium">{fmt(totalHeld)}</span> in total.
          </p>
        </div>
        {isManager && (
          <button
            onClick={() => { setIsAdding(v => !v); setForm(initialForm); }}
            className="flex items-center gap-2 bg-foreground/5 hover:bg-foreground/10 border border-foreground/10 text-foreground px-4 py-2 rounded-xl text-sm"
          >
            <Plus size={16} /> Advance Entry
          </button>
        )}
      </div>

      {isAdding && isManager && (
        <form onSubmit={handleSubmit} className="grid grid-cols-1 sm:grid-cols-2 gap-4 bg-muted border border-foreground/10 rounded-xl p-4">
          <div>
            <label className="block text-sm text-foreground/60 mb-1">Member</label>
            <select required value={form.member_id} onChange={e => setForm({ ...form, member_id: e.target.value })} className="w-full bg-card border border-foreground/10 rounded-xl px-4 py-2.5 text-foreground focus:outline-none focus:border-emerald-500/50">
              <option value="">Select member</option>
              {members.filter(m => m.status === 'approved' || balanceOf(m.id) > 0).map(m => (
                <option key={m.id} value={m.id}>{m.display_name} (advance: {fmt(balanceOf(m.id))})</option>
              ))}
            </select>
          </div>
          <div>
            <label className="block text-sm text-foreground/60 mb-1">Type</label>
            <select value={form.type} onChange={e => setForm({ ...form, type: e.target.value })} className="w-full bg-card border border-foreground/10 rounded-xl px-4 py-2.5 text-foreground focus:outline-none focus:border-emerald-500/50">
              <option value="taken">Take advance (member gives money)</option>
              <option value="returned">Return advance (member leaving)</option>
              <option value="adjusted">Adjust against dues (bokeya kata)</option>
            </select>
            {form.type === 'adjusted' && (
              <p className="text-purple-400/70 text-xs mt-1">Creates a deposit for the member — their meal balance goes up, advance goes down.</p>
            )}
          </div>
          <div>
            <label className="block text-sm text-foreground/60 mb-1">Amount (৳)</label>
            <input required type="number" min="0.01" step="0.01" value={form.amount} onChange={e => setForm({ ...form, amount: e.target.value })} className="w-full bg-card border border-foreground/10 rounded-xl px-4 py-2.5 text-foreground focus:outline-none focus:border-emerald-500/50" />
          </div>
          <div>
            <label className="block text-sm text-foreground/60 mb-1">Date</label>
            <input required type="date" value={form.date} onChange={e => setForm({ ...form, date: e.target.value })} className="w-full bg-card border border-foreground/10 rounded-xl px-4 py-2.5 text-foreground focus:outline-none focus:border-emerald-500/50" />
          </div>
          <div className="sm:col-span-2">
            <label className="block text-sm text-foreground/60 mb-1">Note</label>
            <input type="text" value={form.note} onChange={e => setForm({ ...form, note: e.target.value })} className="w-full bg-card border border-foreground/10 rounded-xl px-4 py-2.5 text-foreground focus:outline-none focus:border-emerald-500/50" placeholder="optional" />
          </div>
          <div className="sm:col-span-2 flex justify-end gap-3">
            <button type="button" onClick={() => setIsAdding(false)} className="px-5 py-2 rounded-xl text-foreground/60 hover:text-foreground hover:bg-foreground/5">Cancel</button>
            <button type="submit" className="bg-emerald-500 hover:bg-emerald-600 text-white px-6 py-2 rounded-xl font-medium shadow-lg shadow-emerald-500/20">Save</button>
          </div>
        </form>
      )}

      {/* Per-member advance balances */}
      <div className="flex flex-wrap gap-2">
        {membersWithBalance.map(m => (
          <span key={m.id} className={`px-3 py-1.5 rounded-lg border text-xs ${m.adv > 0 ? 'border-emerald-500/30 bg-emerald-500/10 text-emerald-300' : 'border-foreground/10 bg-foreground/5 text-white/40'}`}>
            {m.display_name}{m.status !== 'approved' ? ` (${m.status})` : ''}: {fmt(m.adv)}
          </span>
        ))}
        {membersWithBalance.length === 0 && <span className="text-foreground/40 text-sm">No members yet.</span>}
      </div>

      {/* History */}
      {advances.length > 0 && (
        <div className="divide-y divide-foreground/5 border-t border-foreground/10 pt-2">
          {visible.map(a => {
            const meta = TYPE_META[a.type] || TYPE_META.taken;
            return (
              <div key={a.id} className="flex items-center gap-3 py-2.5">
                <div className={`w-8 h-8 rounded-lg flex items-center justify-center shrink-0 ${meta.cls}`}>
                  <meta.icon size={15} />
                </div>
                <div className="flex-1 min-w-0">
                  <p className="text-foreground text-sm truncate">{memberName(a.member_id)} <span className="text-foreground/40">· {meta.label}</span></p>
                  <p className="text-foreground/40 text-xs">{a.date}{a.note ? ` · ${a.note}` : ''}</p>
                </div>
                <span className={`font-semibold text-sm ${a.type === 'taken' ? 'text-emerald-400' : 'text-orange-400'}`}>
                  {a.type === 'taken' ? '+' : '−'}{fmt(a.amount)}
                </span>
                {isManager && (
                  <button
                    onClick={() => { if (confirm('Delete this advance entry?' + (a.type === 'adjusted' ? ' (The deposit it created will NOT be deleted automatically.)' : ''))) deleteAdvance(a.id).catch(err => alert(err.message)); }}
                    className="p-1.5 rounded-lg bg-muted border border-foreground/10 text-foreground/60 hover:text-red-400"
                  >
                    <Trash2 size={13} />
                  </button>
                )}
              </div>
            );
          })}
          {advances.length > 6 && (
            <button onClick={() => setShowAll(v => !v)} className="w-full text-center text-xs text-foreground/40 hover:text-foreground py-2">
              {showAll ? 'Show less' : `Show all (${advances.length})`}
            </button>
          )}
        </div>
      )}
    </div>
  );
}

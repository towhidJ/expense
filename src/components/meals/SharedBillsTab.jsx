import { useState } from 'react';
import { Plus, Trash2, Receipt, X } from 'lucide-react';

const fmt = (n) => `৳${Number(n || 0).toLocaleString()}`;
const pad = (n) => String(n).padStart(2, '0');
const today = () => {
  const d = new Date();
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
};

// Rent, wifi, gas cylinder — split equally or with custom amounts. This is a
// standalone ledger with per-member paid ticks; it deliberately does NOT feed
// the meal month summary (that pot is for meal-linked fixed costs).
export default function SharedBillsTab({
  sharedExpenses, members, isManager, currentUserId,
  createSharedExpense, toggleSharePaid, deleteSharedExpense
}) {
  const approved = members.filter(m => m.status === 'approved');
  const [open, setOpen] = useState(false);
  const [form, setForm] = useState({
    title: '', amount: '', date: today(), split_type: 'equal', note: '',
    included: {}, custom: {}
  });
  const [saving, setSaving] = useState(false);

  const memberName = (id) => members.find(m => m.id === id)?.display_name || 'Member';

  const openForm = () => {
    const included = {};
    approved.forEach(m => { included[m.id] = true; });
    setForm({ title: '', amount: '', date: today(), split_type: 'equal', note: '', included, custom: {} });
    setOpen(true);
  };

  const buildShares = () => {
    const amount = Number(form.amount);
    if (form.split_type === 'equal') {
      const ids = approved.filter(m => form.included[m.id]).map(m => m.id);
      if (ids.length === 0) return null;
      // last member absorbs the rounding remainder so shares sum exactly
      const base = Math.floor((amount / ids.length) * 100) / 100;
      return ids.map((id, i) => ({
        member_id: id,
        amount: i === ids.length - 1 ? Math.round((amount - base * (ids.length - 1)) * 100) / 100 : base
      }));
    }
    return approved
      .map(m => ({ member_id: m.id, amount: Number(form.custom[m.id]) || 0 }))
      .filter(s => s.amount > 0);
  };

  const customTotal = approved.reduce((sum, m) => sum + (Number(form.custom[m.id]) || 0), 0);

  const handleSave = async (e) => {
    e.preventDefault();
    const shares = buildShares();
    if (!shares || shares.length === 0) {
      alert('Pick at least one member for the split.');
      return;
    }
    setSaving(true);
    try {
      await createSharedExpense({
        title: form.title, amount: Number(form.amount), date: form.date,
        split_type: form.split_type, shares, note: form.note
      });
      setOpen(false);
    } catch (err) {
      console.error(err);
      alert(err.message);
    } finally {
      setSaving(false);
    }
  };

  const act = async (fn) => {
    try {
      await fn();
    } catch (err) {
      console.error(err);
      alert(err.message);
    }
  };

  return (
    <div className="space-y-6">
      {isManager && !open && (
        <button onClick={openForm}
          className="flex items-center gap-2 bg-cyan-500 hover:bg-cyan-600 text-white px-5 py-2.5 rounded-xl shadow-lg shadow-cyan-500/20 font-medium text-sm">
          <Plus size={16} /> New Shared Bill
        </button>
      )}

      {isManager && open && (
        <form onSubmit={handleSave} className="bg-[#1a1a2e] border border-white/10 rounded-2xl p-6 space-y-4">
          <div className="flex items-center justify-between">
            <h3 className="text-white font-semibold">New Shared Bill</h3>
            <button type="button" onClick={() => setOpen(false)} className="text-white/40 hover:text-white"><X size={18} /></button>
          </div>
          <div className="grid sm:grid-cols-3 gap-4">
            <div className="sm:col-span-2">
              <label className="block text-sm text-white/60 mb-1">Title</label>
              <input required type="text" value={form.title} placeholder="Basha bhara — July"
                onChange={e => setForm({ ...form, title: e.target.value })}
                className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-cyan-500/50" />
            </div>
            <div>
              <label className="block text-sm text-white/60 mb-1">Date</label>
              <input required type="date" value={form.date}
                onChange={e => setForm({ ...form, date: e.target.value })}
                className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-cyan-500/50" />
            </div>
          </div>
          <div className="grid sm:grid-cols-3 gap-4">
            <div>
              <label className="block text-sm text-white/60 mb-1">Total amount (৳)</label>
              <input required type="number" min="1" step="0.01" value={form.amount}
                onChange={e => setForm({ ...form, amount: e.target.value })}
                className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-cyan-500/50" />
            </div>
            <div>
              <label className="block text-sm text-white/60 mb-1">Split</label>
              <select value={form.split_type}
                onChange={e => setForm({ ...form, split_type: e.target.value })}
                className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-cyan-500/50 appearance-none cursor-pointer">
                <option value="equal" className="bg-[#12122a]">Equally</option>
                <option value="custom" className="bg-[#12122a]">Custom amounts</option>
              </select>
            </div>
            <div>
              <label className="block text-sm text-white/60 mb-1">Note (optional)</label>
              <input type="text" value={form.note}
                onChange={e => setForm({ ...form, note: e.target.value })}
                className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-cyan-500/50" />
            </div>
          </div>

          <div>
            <p className="text-sm text-white/60 mb-2">
              {form.split_type === 'equal' ? 'Who shares this bill?' : 'Amount per member'}
              {form.split_type === 'custom' && (
                <span className={`ml-2 text-xs ${Math.abs(customTotal - Number(form.amount || 0)) <= 1 ? 'text-emerald-400' : 'text-orange-400'}`}>
                  total {fmt(customTotal)} / {fmt(form.amount || 0)}
                </span>
              )}
            </p>
            <div className="grid sm:grid-cols-2 lg:grid-cols-3 gap-2">
              {approved.map(m => (
                form.split_type === 'equal' ? (
                  <label key={m.id} className={`flex items-center gap-2.5 rounded-xl px-3 py-2.5 text-sm border cursor-pointer ${
                    form.included[m.id] ? 'bg-cyan-500/10 border-cyan-500/30 text-white' : 'bg-[#12122a] border-white/10 text-white/40'
                  }`}>
                    <input type="checkbox" checked={!!form.included[m.id]}
                      onChange={e => setForm({ ...form, included: { ...form.included, [m.id]: e.target.checked } })}
                      className="accent-cyan-500 w-4 h-4" />
                    {m.display_name}
                  </label>
                ) : (
                  <div key={m.id} className="flex items-center gap-2 bg-[#12122a] border border-white/10 rounded-xl px-3 py-1.5">
                    <span className="text-white/60 text-sm flex-1 truncate">{m.display_name}</span>
                    <input type="number" min="0" step="0.01" value={form.custom[m.id] || ''}
                      placeholder="0"
                      onChange={e => setForm({ ...form, custom: { ...form.custom, [m.id]: e.target.value } })}
                      className="w-24 bg-transparent border border-white/10 rounded-lg px-2 py-1.5 text-white text-sm text-right focus:outline-none focus:border-cyan-500/50" />
                  </div>
                )
              ))}
            </div>
          </div>

          <div className="flex justify-end">
            <button type="submit" disabled={saving}
              className="flex items-center gap-2 bg-cyan-500 hover:bg-cyan-600 text-white px-6 py-2.5 rounded-xl shadow-lg shadow-cyan-500/20 font-medium disabled:opacity-50">
              {saving ? 'Saving...' : 'Save Bill'}
            </button>
          </div>
        </form>
      )}

      <div className="space-y-4">
        {sharedExpenses.map(bill => {
          const shares = bill.meal_shared_expense_shares || [];
          const paidCount = shares.filter(s => s.paid).length;
          const paidAmount = shares.reduce((sum, s) => sum + (s.paid ? Number(s.share_amount) : 0), 0);
          return (
            <div key={bill.id} className="bg-[#1a1a2e] border border-white/10 rounded-2xl overflow-hidden">
              <div className="px-5 py-4 border-b border-white/10 flex flex-wrap items-center gap-3">
                <div className="w-9 h-9 rounded-xl bg-purple-500/15 text-purple-400 flex items-center justify-center shrink-0">
                  <Receipt size={16} />
                </div>
                <div className="flex-1 min-w-[180px]">
                  <p className="text-white font-medium">{bill.title}</p>
                  <p className="text-white/40 text-xs">
                    {new Date(bill.date + 'T00:00:00').toLocaleDateString(undefined, { day: 'numeric', month: 'short' })}
                    {' · '}{bill.split_type === 'equal' ? 'equal split' : 'custom split'}
                    {bill.note && <span> · {bill.note}</span>}
                  </p>
                </div>
                <div className="text-right">
                  <p className="text-white font-semibold">{fmt(bill.amount)}</p>
                  <p className={`text-xs ${paidCount === shares.length ? 'text-emerald-400' : 'text-orange-400'}`}>
                    {fmt(paidAmount)} collected · {paidCount}/{shares.length} paid
                  </p>
                </div>
                {isManager && (
                  <button onClick={() => { if (confirm('Delete this bill and its shares?')) act(() => deleteSharedExpense(bill.id)); }}
                    className="p-2 rounded-lg text-white/30 hover:text-red-400 hover:bg-white/5">
                    <Trash2 size={15} />
                  </button>
                )}
              </div>
              <div className="divide-y divide-white/5">
                {shares.map(s => {
                  const mine = members.find(m => m.id === s.member_id)?.user_id === currentUserId;
                  return (
                    <div key={s.id} className="px-5 py-2.5 flex items-center gap-3">
                      <span className="text-white/80 text-sm flex-1">
                        {memberName(s.member_id)}
                        {mine && <span className="text-cyan-400 text-xs ml-1">(you)</span>}
                      </span>
                      <span className="text-white/60 text-sm">{fmt(s.share_amount)}</span>
                      {isManager ? (
                        <label className="flex items-center gap-1.5 cursor-pointer">
                          <input type="checkbox" checked={s.paid}
                            onChange={e => act(() => toggleSharePaid(s.id, e.target.checked))}
                            className="accent-emerald-500 w-4 h-4" />
                          <span className={`text-xs ${s.paid ? 'text-emerald-400' : 'text-white/30'}`}>paid</span>
                        </label>
                      ) : (
                        <span className={`text-xs px-2 py-0.5 rounded-lg border ${
                          s.paid ? 'bg-emerald-500/10 text-emerald-400 border-emerald-500/20' : 'bg-orange-500/10 text-orange-400 border-orange-500/20'
                        }`}>
                          {s.paid ? 'paid' : 'due'}
                        </span>
                      )}
                    </div>
                  );
                })}
              </div>
            </div>
          );
        })}
        {sharedExpenses.length === 0 && (
          <div className="bg-[#1a1a2e] border border-white/10 rounded-2xl p-8 text-center text-white/40 text-sm">
            No shared bills this month.{isManager ? ' Add rent, wifi or gas.' : ''}
          </div>
        )}
      </div>
      <p className="text-white/30 text-xs">
        Shared bills are tracked separately from the meal ledger — they do not affect the meal rate or month balance.
      </p>
    </div>
  );
}

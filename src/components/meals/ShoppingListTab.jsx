import { useState } from 'react';
import { Plus, Trash2, ShoppingCart, X } from 'lucide-react';

const pad = (n) => String(n).padStart(2, '0');
const today = () => {
  const d = new Date();
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
};

// The pre-purchase "ki ki lagbe" list. Anyone adds items, whoever does the
// bazar ticks them off, then converts the ticked items into one itemized
// bazar expense — no double typing.
export default function ShoppingListTab({
  items, members, currentUserId, isManager,
  addShoppingItem, toggleShoppingItem, deleteShoppingItem, convertShoppingToExpense
}) {
  const [form, setForm] = useState({ name: '', qty: '' });
  const [convertOpen, setConvertOpen] = useState(false);
  const [convertForm, setConvertForm] = useState({ amount: '', date: today(), note: '' });
  const [busy, setBusy] = useState(false);

  const toBuy = items.filter(it => !it.is_bought);
  const bought = items.filter(it => it.is_bought);
  const memberName = (userId) =>
    members.find(m => m.user_id === userId)?.display_name || 'Someone';

  const act = async (fn) => {
    try {
      await fn();
    } catch (err) {
      console.error(err);
      alert(err.message);
    }
  };

  const handleAdd = async (e) => {
    e.preventDefault();
    if (!form.name.trim()) return;
    await act(() => addShoppingItem({ name: form.name.trim(), qty: form.qty.trim() }));
    setForm({ name: '', qty: '' });
  };

  const handleConvert = async (e) => {
    e.preventDefault();
    setBusy(true);
    try {
      await convertShoppingToExpense({
        itemIds: bought.map(it => it.id),
        amount: Number(convertForm.amount),
        date: convertForm.date,
        note: convertForm.note
      });
      setConvertOpen(false);
      setConvertForm({ amount: '', date: today(), note: '' });
    } catch (err) {
      console.error(err);
      alert(err.message);
    } finally {
      setBusy(false);
    }
  };

  const Row = ({ it }) => {
    const canDelete = isManager || it.added_by === currentUserId;
    return (
      <div className="px-5 py-3 flex items-center gap-3">
        <input
          type="checkbox"
          checked={it.is_bought}
          onChange={e => act(() => toggleShoppingItem(it.id, e.target.checked))}
          className="accent-emerald-500 w-4 h-4 shrink-0 cursor-pointer"
        />
        <div className="flex-1 min-w-0">
          <p className={`text-sm ${it.is_bought ? 'text-white/40 line-through' : 'text-white'}`}>
            {it.name}{it.qty && <span className="text-white/40"> — {it.qty}</span>}
          </p>
          <p className="text-white/30 text-xs">
            {it.is_bought
              ? `Bought by ${memberName(it.bought_by)}`
              : `Added by ${memberName(it.added_by)}`}
          </p>
        </div>
        {canDelete && (
          <button onClick={() => act(() => deleteShoppingItem(it.id))}
            className="p-1.5 rounded-lg text-white/30 hover:text-red-400 hover:bg-white/5 shrink-0">
            <Trash2 size={14} />
          </button>
        )}
      </div>
    );
  };

  return (
    <div className="space-y-6">
      <form onSubmit={handleAdd} className="bg-[#1a1a2e] border border-white/10 rounded-2xl p-4 flex flex-wrap gap-3">
        <input required type="text" value={form.name} placeholder="Item — e.g. Chal, Soyabean tel"
          onChange={e => setForm({ ...form, name: e.target.value })}
          className="flex-1 min-w-[180px] bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white text-sm focus:outline-none focus:border-cyan-500/50" />
        <input type="text" value={form.qty} placeholder="Qty — 2 kg"
          onChange={e => setForm({ ...form, qty: e.target.value })}
          className="w-32 bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white text-sm focus:outline-none focus:border-cyan-500/50" />
        <button type="submit"
          className="flex items-center gap-2 bg-cyan-500 hover:bg-cyan-600 text-white px-5 py-2.5 rounded-xl shadow-lg shadow-cyan-500/20 font-medium text-sm">
          <Plus size={16} /> Add
        </button>
      </form>

      <div className="bg-[#1a1a2e] border border-white/10 rounded-2xl overflow-hidden">
        <div className="px-5 py-4 border-b border-white/10 flex items-center justify-between">
          <h3 className="text-white font-semibold">To Buy <span className="text-white/30 text-sm font-normal">({toBuy.length})</span></h3>
        </div>
        <div className="divide-y divide-white/5">
          {toBuy.map(it => <Row key={it.id} it={it} />)}
          {toBuy.length === 0 && (
            <p className="px-5 py-8 text-center text-white/40 text-sm">Nothing on the list. Add what the mess needs.</p>
          )}
        </div>
      </div>

      {bought.length > 0 && (
        <div className="bg-[#1a1a2e] border border-white/10 rounded-2xl overflow-hidden">
          <div className="px-5 py-4 border-b border-white/10 flex flex-wrap items-center justify-between gap-3">
            <h3 className="text-white font-semibold">Bought <span className="text-white/30 text-sm font-normal">({bought.length})</span></h3>
            {!convertOpen && (
              <button onClick={() => setConvertOpen(true)}
                className="flex items-center gap-2 px-4 py-2 rounded-xl bg-emerald-500/10 border border-emerald-500/20 text-emerald-400 hover:bg-emerald-500/20 text-sm">
                <ShoppingCart size={15} /> Convert to Expense
              </button>
            )}
          </div>
          {convertOpen && (
            <form onSubmit={handleConvert} className="px-5 py-4 border-b border-white/10 bg-[#12122a]/50 space-y-3">
              <div className="flex items-center justify-between">
                <p className="text-white/60 text-sm">
                  All {bought.length} bought item{bought.length > 1 ? 's' : ''} become one itemized bazar expense.
                </p>
                <button type="button" onClick={() => setConvertOpen(false)} className="text-white/40 hover:text-white"><X size={16} /></button>
              </div>
              <div className="flex flex-wrap gap-3">
                <input required type="number" min="1" step="0.01" value={convertForm.amount} placeholder="Total amount (৳)"
                  onChange={e => setConvertForm({ ...convertForm, amount: e.target.value })}
                  className="w-44 bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white text-sm focus:outline-none focus:border-emerald-500/50" />
                <input required type="date" value={convertForm.date}
                  onChange={e => setConvertForm({ ...convertForm, date: e.target.value })}
                  className="bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white text-sm focus:outline-none focus:border-emerald-500/50" />
                <input type="text" value={convertForm.note} placeholder="Note (optional)"
                  onChange={e => setConvertForm({ ...convertForm, note: e.target.value })}
                  className="flex-1 min-w-[160px] bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white text-sm focus:outline-none focus:border-emerald-500/50" />
                <button type="submit" disabled={busy}
                  className="flex items-center gap-2 bg-emerald-500 hover:bg-emerald-600 text-white px-5 py-2.5 rounded-xl font-medium text-sm disabled:opacity-50">
                  {busy ? 'Saving...' : 'Save Expense'}
                </button>
              </div>
            </form>
          )}
          <div className="divide-y divide-white/5">
            {bought.map(it => <Row key={it.id} it={it} />)}
          </div>
        </div>
      )}
      <p className="text-white/30 text-xs">
        Converting clears these items from the list and files them under Expenses with the item names attached.
      </p>
    </div>
  );
}

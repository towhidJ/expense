import { useState } from 'react';
import ItemListEditor from '../ItemListEditor';
import { Plus, Edit2, Trash2, ShoppingBasket, Zap, HandPlatter, Package, PartyPopper, Paperclip, ChevronDown, ChevronUp } from 'lucide-react';

const fmt = (n) => `৳${Number(n || 0).toLocaleString()}`;
const todayISO = () => new Date().toISOString().slice(0, 10);

const TYPES = {
  bazar: { label: 'Bazar', icon: ShoppingBasket, color: 'text-cyan-400 bg-cyan-500/10' },
  utility: { label: 'Utility', icon: Zap, color: 'text-orange-400 bg-orange-500/10' },
  maid: { label: 'Maid', icon: HandPlatter, color: 'text-purple-400 bg-purple-500/10' },
  feast: { label: 'Feast / Special', icon: PartyPopper, color: 'text-pink-400 bg-pink-500/10' },
  other: { label: 'Other', icon: Package, color: 'text-white/60 bg-white/5' }
};

export default function ExpensesTab({ expenses, members, isManager, currentUserId, addExpense, updateExpense, deleteExpense, uploadReceipt }) {
  const approvedMembers = members.filter(m => m.status === 'approved');
  const memberName = (id) => members.find(m => m.id === id)?.display_name;

  const initialForm = { expense_type: 'bazar', amount: '', date: todayISO(), note: '', spent_by: '' };
  const [form, setForm] = useState(initialForm);
  const [items, setItems] = useState([]);
  const [receiptFile, setReceiptFile] = useState(null);
  const [removeReceipt, setRemoveReceipt] = useState(false);
  const [isAdding, setIsAdding] = useState(false);
  const [editing, setEditing] = useState(null);
  const [saving, setSaving] = useState(false);
  const [expanded, setExpanded] = useState({});

  const totalBazar = expenses.filter(e => e.expense_type === 'bazar').reduce((s, e) => s + Number(e.amount), 0);
  const totalOther = expenses.filter(e => e.expense_type !== 'bazar').reduce((s, e) => s + Number(e.amount), 0);

  const canEdit = (expense) => isManager || expense.added_by === currentUserId;

  const openAdd = () => {
    setIsAdding(true);
    setEditing(null);
    setForm(initialForm);
    setItems([]);
    setReceiptFile(null);
    setRemoveReceipt(false);
  };

  const openEdit = (exp) => {
    setEditing(exp);
    setIsAdding(false);
    setForm({
      expense_type: exp.expense_type, amount: exp.amount, date: exp.date,
      note: exp.note || '', spent_by: exp.spent_by || ''
    });
    setItems(Array.isArray(exp.items) ? exp.items : []);
    setReceiptFile(null);
    setRemoveReceipt(false);
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setSaving(true);
    try {
      const cleanItems = items
        .filter(it => it.name && it.name.trim())
        .map(it => ({ name: it.name.trim(), amount: it.amount === '' || it.amount == null ? null : Number(it.amount) }));

      let attachment;
      if (receiptFile) {
        attachment = await uploadReceipt(receiptFile);
      }

      const payload = { ...form, amount: Number(form.amount), spent_by: form.spent_by || null, items: cleanItems };
      if (attachment) {
        payload.attachment_url = attachment.url;
        payload.attachment_path = attachment.path;
      } else if (editing && removeReceipt) {
        payload.attachment_url = null;
        payload.attachment_path = null;
      }

      if (editing) await updateExpense(editing.id, payload);
      else await addExpense(payload);
      setIsAdding(false);
      setEditing(null);
      setForm(initialForm);
      setItems([]);
      setReceiptFile(null);
    } catch (err) {
      console.error(err);
      alert('Error saving expense: ' + err.message);
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap justify-between items-center gap-3">
        <p className="text-white/60 text-sm">
          Bazar: <span className="text-cyan-400 font-semibold">{fmt(totalBazar)}</span>
          <span className="mx-2 text-white/20">|</span>
          Fixed (utility/maid/feast): <span className="text-orange-400 font-semibold">{fmt(totalOther)}</span>
        </p>
        <button
          onClick={openAdd}
          className="flex items-center gap-2 bg-cyan-500 hover:bg-cyan-600 text-white px-4 py-2 rounded-xl transition-colors shadow-lg shadow-cyan-500/20"
        >
          <Plus size={18} /> Add Expense
        </button>
      </div>

      {(isAdding || editing) && (
        <div className="bg-[#1a1a2e] border border-white/10 rounded-2xl p-6">
          <h2 className="text-lg font-semibold text-white mb-4">{editing ? 'Edit Expense' : 'New Expense'}</h2>
          <form onSubmit={handleSubmit} className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div>
              <label className="block text-sm text-white/60 mb-1">Type</label>
              <select value={form.expense_type} onChange={e => setForm({ ...form, expense_type: e.target.value })} className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-cyan-500/50">
                {Object.entries(TYPES).map(([k, t]) => <option key={k} value={k}>{t.label}</option>)}
              </select>
              {form.expense_type === 'feast' && (
                <p className="text-pink-400/70 text-xs mt-1">Feast cost is split equally among active members (not by meal count).</p>
              )}
            </div>
            <div>
              <label className="block text-sm text-white/60 mb-1">Amount (৳)</label>
              <input required type="number" min="0.01" step="0.01" value={form.amount} onChange={e => setForm({ ...form, amount: e.target.value })} className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-cyan-500/50" />
            </div>
            <div>
              <label className="block text-sm text-white/60 mb-1">Date</label>
              <input required type="date" value={form.date} onChange={e => setForm({ ...form, date: e.target.value })} className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-cyan-500/50" />
            </div>
            <div>
              <label className="block text-sm text-white/60 mb-1">Spent by (who did bazar)</label>
              <select value={form.spent_by} onChange={e => setForm({ ...form, spent_by: e.target.value })} className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-cyan-500/50">
                <option value="">—</option>
                {approvedMembers.map(m => <option key={m.id} value={m.id}>{m.display_name}</option>)}
              </select>
            </div>
            <div className="sm:col-span-2">
              <label className="block text-sm text-white/60 mb-1">Items bought (ki ki kinlen)</label>
              <ItemListEditor items={items} onChange={setItems} />
            </div>
            <div className="sm:col-span-2">
              <label className="block text-sm text-white/60 mb-1">Note</label>
              <input type="text" value={form.note} onChange={e => setForm({ ...form, note: e.target.value })} className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-cyan-500/50" placeholder="optional" />
            </div>
            <div className="sm:col-span-2">
              <label className="block text-sm text-white/60 mb-1">Receipt / রশিদ (optional)</label>
              <div className="flex flex-wrap items-center gap-3">
                <input
                  type="file"
                  accept="image/*,application/pdf"
                  onChange={e => { setReceiptFile(e.target.files?.[0] || null); setRemoveReceipt(false); }}
                  className="text-sm text-white/60 file:mr-3 file:px-4 file:py-2 file:rounded-xl file:border-0 file:bg-white/10 file:text-white file:text-sm hover:file:bg-white/20 file:cursor-pointer"
                />
                {editing?.attachment_url && !receiptFile && !removeReceipt && (
                  <span className="flex items-center gap-2 text-xs text-white/50">
                    <a href={editing.attachment_url} target="_blank" rel="noreferrer" className="flex items-center gap-1 text-cyan-400 hover:underline">
                      <Paperclip size={12} /> Current receipt
                    </a>
                    <button type="button" onClick={() => setRemoveReceipt(true)} className="text-red-400/70 hover:text-red-400">Remove</button>
                  </span>
                )}
                {removeReceipt && <span className="text-red-400/70 text-xs">Receipt will be removed on save.</span>}
              </div>
            </div>
            <div className="sm:col-span-2 flex justify-end gap-3 mt-2">
              <button type="button" onClick={() => { setIsAdding(false); setEditing(null); }} className="px-5 py-2.5 rounded-xl text-white/60 hover:text-white hover:bg-white/5 transition-colors">Cancel</button>
              <button type="submit" disabled={saving} className="bg-cyan-500 hover:bg-cyan-600 text-white px-6 py-2.5 rounded-xl shadow-lg shadow-cyan-500/20 transition-all font-medium disabled:opacity-50">
                {saving ? 'Saving...' : 'Save'}
              </button>
            </div>
          </form>
        </div>
      )}

      <div className="bg-[#1a1a2e] border border-white/10 rounded-2xl divide-y divide-white/5">
        {expenses.map(exp => {
          const t = TYPES[exp.expense_type] || TYPES.other;
          const expItems = Array.isArray(exp.items) ? exp.items : [];
          const isOpen = expanded[exp.id];
          return (
            <div key={exp.id}>
              <div className="flex items-center gap-3 px-4 py-3">
                <div className={`w-9 h-9 rounded-xl flex items-center justify-center shrink-0 ${t.color}`}>
                  <t.icon size={18} />
                </div>
                <div className="flex-1 min-w-0">
                  <p className="text-white text-sm font-medium truncate">
                    {t.label}
                    {exp.spent_by && memberName(exp.spent_by) && (
                      <span className="text-white/40 font-normal"> · by {memberName(exp.spent_by)}</span>
                    )}
                  </p>
                  <p className="text-white/40 text-xs truncate">{exp.date}{exp.note ? ` · ${exp.note}` : ''}</p>
                </div>
                {exp.attachment_url && (
                  <a href={exp.attachment_url} target="_blank" rel="noreferrer" title="View receipt"
                    className="p-1.5 rounded-lg bg-[#12122a] border border-white/10 text-white/60 hover:text-cyan-400">
                    <Paperclip size={14} />
                  </a>
                )}
                {expItems.length > 0 && (
                  <button
                    onClick={() => setExpanded(x => ({ ...x, [exp.id]: !x[exp.id] }))}
                    title="Items list"
                    className="flex items-center gap-1 p-1.5 rounded-lg bg-[#12122a] border border-white/10 text-white/60 hover:text-cyan-400 text-xs"
                  >
                    {expItems.length} {isOpen ? <ChevronUp size={13} /> : <ChevronDown size={13} />}
                  </button>
                )}
                <span className="text-white font-semibold">{fmt(exp.amount)}</span>
                {canEdit(exp) && (
                  <div className="flex gap-1 ml-2">
                    <button onClick={() => openEdit(exp)} className="p-1.5 rounded-lg bg-[#12122a] border border-white/10 text-white/60 hover:text-cyan-400">
                      <Edit2 size={14} />
                    </button>
                    <button onClick={() => { if (confirm('Delete this expense?')) deleteExpense(exp.id).catch(err => alert('Cannot delete: ' + err.message)); }} className="p-1.5 rounded-lg bg-[#12122a] border border-white/10 text-white/60 hover:text-red-400">
                      <Trash2 size={14} />
                    </button>
                  </div>
                )}
              </div>
              {isOpen && expItems.length > 0 && (
                <div className="px-4 pb-3 pl-16">
                  <div className="bg-[#12122a] border border-white/10 rounded-xl px-4 py-2 divide-y divide-white/5">
                    {expItems.map((it, i) => (
                      <div key={i} className="flex justify-between py-1.5 text-sm">
                        <span className="text-white/70">{it.name}</span>
                        <span className="text-white/50">{it.amount != null && it.amount !== '' ? fmt(it.amount) : ''}</span>
                      </div>
                    ))}
                  </div>
                </div>
              )}
            </div>
          );
        })}
        {expenses.length === 0 && (
          <div className="px-4 py-10 text-center text-white/40 text-sm">No expenses this month. Whoever does the bazar records it here.</div>
        )}
      </div>
    </div>
  );
}

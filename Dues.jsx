import { useState } from 'react';
import { useDues } from '../hooks/useDues';
import DueCard from '../components/DueCard';
import { Plus, X } from 'lucide-react';

export default function Dues() {
  const { dues, loading, addDue, updateDue, deleteDue } = useDues();
  const [showForm, setShowForm] = useState(false);
  const [editData, setEditData] = useState(null);
  const [tab, setTab] = useState('all');
  const [form, setForm] = useState({
    title: '', amount: '', due_date: '', category: '',
    is_recurring: false, recurrence_period: 'monthly', notes: '', status: 'pending'
  });
  const [submitting, setSubmitting] = useState(false);

  const filtered = tab === 'all' ? dues : tab === 'overdue'
    ? dues.filter(d => new Date(d.due_date) < new Date() && d.status !== 'paid')
    : dues.filter(d => d.status === tab);

  const totalPending = dues.filter(d => d.status !== 'paid').reduce((s, d) => s + d.amount, 0);
  const overdueCount = dues.filter(d => new Date(d.due_date) < new Date() && d.status !== 'paid').length;

  const openForm = (due = null) => {
    if (due) {
      setEditData(due);
      setForm({
        title: due.title, amount: due.amount.toString(), due_date: due.due_date,
        category: due.category || '', is_recurring: due.is_recurring || false,
        recurrence_period: due.recurrence_period || 'monthly', notes: due.notes || '', status: due.status
      });
    } else {
      setEditData(null);
      setForm({
        title: '', amount: '', due_date: '', category: '',
        is_recurring: false, recurrence_period: 'monthly', notes: '', status: 'pending'
      });
    }
    setShowForm(true);
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setSubmitting(true);
    try {
      const data = { ...form, amount: parseFloat(form.amount) };
      if (editData) await updateDue(editData.id, data);
      else await addDue(data);
      setShowForm(false);
    } catch (err) { alert(err.message); }
    setSubmitting(false);
  };

  const handleMarkPaid = async (id) => {
    await updateDue(id, { status: 'paid' });
  };

  const handleDelete = async (id) => {
    if (confirm('Delete this due?')) await deleteDue(id);
  };

  return (
    <div className="space-y-6 animate-in">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-white">Dues & Bills</h1>
          <p className="text-white/40 text-sm mt-1">Track your upcoming payments</p>
        </div>
        <button onClick={() => openForm()} className="flex items-center gap-2 px-5 py-2.5 rounded-xl bg-gradient-to-r from-cyan-500 to-purple-600 text-white text-sm font-semibold hover:shadow-lg hover:shadow-cyan-500/25 transition-all">
          <Plus className="w-4 h-4" /> Add Due
        </button>
      </div>

      {/* Summary */}
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
        <div className="rounded-xl bg-white/5 border border-white/10 p-4">
          <p className="text-xs text-white/40">Total Pending</p>
          <p className="text-xl font-bold text-amber-400 mt-1">৳{totalPending.toLocaleString()}</p>
        </div>
        <div className="rounded-xl bg-white/5 border border-white/10 p-4">
          <p className="text-xs text-white/40">Overdue</p>
          <p className="text-xl font-bold text-red-400 mt-1">{overdueCount} items</p>
        </div>
        <div className="rounded-xl bg-white/5 border border-white/10 p-4">
          <p className="text-xs text-white/40">Total Dues</p>
          <p className="text-xl font-bold text-white mt-1">{dues.length}</p>
        </div>
      </div>

      {/* Tabs */}
      <div className="flex gap-2 flex-wrap">
        {[['all', 'All'], ['pending', 'Pending'], ['overdue', '⚠️ Overdue'], ['paid', '✅ Paid']].map(([key, label]) => (
          <button key={key} onClick={() => setTab(key)}
            className={`px-4 py-2 rounded-xl text-sm font-medium transition-all ${
              tab === key ? 'bg-white/10 text-white border border-white/20' : 'text-white/40 hover:text-white hover:bg-white/5 border border-transparent'
            }`}>{label}</button>
        ))}
      </div>

      {/* Due Cards */}
      {loading ? (
        <div className="flex justify-center py-12"><div className="w-8 h-8 border-3 border-cyan-500/30 border-t-cyan-500 rounded-full animate-spin" /></div>
      ) : filtered.length > 0 ? (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          {filtered.map(due => <DueCard key={due.id} due={due} onEdit={openForm} onDelete={handleDelete} onMarkPaid={handleMarkPaid} />)}
        </div>
      ) : (
        <div className="text-center py-16 text-white/30">
          <p className="text-4xl mb-3">📅</p>
          <p className="text-sm">No dues found</p>
        </div>
      )}

      {/* Form Modal */}
      {showForm && (
        <div className="fixed inset-0 bg-black/60 backdrop-blur-sm flex items-center justify-center z-50 p-4" onClick={() => setShowForm(false)}>
          <div className="bg-[#12122a] border border-white/10 rounded-2xl w-full max-w-md shadow-2xl max-h-[90vh] overflow-y-auto" onClick={e => e.stopPropagation()}>
            <div className="flex items-center justify-between p-6 border-b border-white/10">
              <h2 className="text-lg font-semibold text-white">{editData ? 'Edit' : 'Add'} Due</h2>
              <button onClick={() => setShowForm(false)} className="text-white/40 hover:text-white transition-colors"><X className="w-5 h-5" /></button>
            </div>
            <form onSubmit={handleSubmit} className="p-6 space-y-4">
              <div>
                <label className="block text-sm text-white/50 mb-1.5">Title</label>
                <input type="text" required value={form.title} onChange={e => setForm(f => ({ ...f, title: e.target.value }))} placeholder="e.g. Electricity Bill" className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-2.5 text-white text-sm focus:outline-none focus:border-cyan-500/50 placeholder:text-white/20" />
              </div>
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-sm text-white/50 mb-1.5">Amount</label>
                  <input type="number" required min="0" step="0.01" value={form.amount} onChange={e => setForm(f => ({ ...f, amount: e.target.value }))} className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-2.5 text-white text-sm focus:outline-none focus:border-cyan-500/50" />
                </div>
                <div>
                  <label className="block text-sm text-white/50 mb-1.5">Due Date</label>
                  <input type="date" required value={form.due_date} onChange={e => setForm(f => ({ ...f, due_date: e.target.value }))} className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-2.5 text-white text-sm focus:outline-none focus:border-cyan-500/50" />
                </div>
              </div>
              <div>
                <label className="block text-sm text-white/50 mb-1.5">Category</label>
                <input type="text" value={form.category} onChange={e => setForm(f => ({ ...f, category: e.target.value }))} placeholder="e.g. Utilities" className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-2.5 text-white text-sm focus:outline-none focus:border-cyan-500/50 placeholder:text-white/20" />
              </div>
              <div className="flex items-center gap-3">
                <label className="relative inline-flex items-center cursor-pointer">
                  <input type="checkbox" checked={form.is_recurring} onChange={e => setForm(f => ({ ...f, is_recurring: e.target.checked }))} className="sr-only peer" />
                  <div className="w-9 h-5 bg-white/10 rounded-full peer peer-checked:bg-cyan-500/50 transition-colors after:content-[''] after:absolute after:top-[2px] after:start-[2px] after:bg-white after:rounded-full after:h-4 after:w-4 after:transition-all peer-checked:after:translate-x-full" />
                </label>
                <span className="text-sm text-white/50">Recurring</span>
                {form.is_recurring && (
                  <select value={form.recurrence_period} onChange={e => setForm(f => ({ ...f, recurrence_period: e.target.value }))} className="bg-white/5 border border-white/10 rounded-xl px-3 py-1.5 text-white text-sm focus:outline-none focus:border-cyan-500/50 appearance-none">
                    <option value="weekly" className="bg-[#12122a]">Weekly</option>
                    <option value="monthly" className="bg-[#12122a]">Monthly</option>
                    <option value="yearly" className="bg-[#12122a]">Yearly</option>
                  </select>
                )}
              </div>
              <div>
                <label className="block text-sm text-white/50 mb-1.5">Notes</label>
                <textarea value={form.notes} onChange={e => setForm(f => ({ ...f, notes: e.target.value }))} placeholder="Optional notes..." rows={2} className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-2.5 text-white text-sm focus:outline-none focus:border-cyan-500/50 placeholder:text-white/20 resize-none" />
              </div>
              <button type="submit" disabled={submitting} className="w-full py-3 rounded-xl bg-gradient-to-r from-cyan-500 to-purple-600 text-white font-semibold text-sm hover:shadow-lg hover:shadow-cyan-500/25 transition-all disabled:opacity-50">
                {submitting ? 'Saving...' : editData ? 'Update Due' : 'Add Due'}
              </button>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}

import { useState } from 'react';
import { useLoans } from '../hooks/useLoans';
import LoanCard from '../components/LoanCard';
import { Plus, X, ArrowUpRight, ArrowDownLeft } from 'lucide-react';

export default function Loans() {
  const { loans, loading, addLoan, updateLoan, deleteLoan } = useLoans();
  const [showForm, setShowForm] = useState(false);
  const [editData, setEditData] = useState(null);
  const [tab, setTab] = useState('all');
  const [form, setForm] = useState({
    type: 'given', person_name: '', amount: '', paid_amount: '0',
    date: new Date().toISOString().split('T')[0], due_date: '', notes: '', status: 'active'
  });
  const [submitting, setSubmitting] = useState(false);

  const filtered = tab === 'all' ? loans : loans.filter(l => l.type === tab);
  const activeLoans = loans.filter(l => l.status !== 'paid');
  const totalGiven = activeLoans.filter(l => l.type === 'given').reduce((s, l) => s + l.amount - (l.paid_amount || 0), 0);
  const totalTaken = activeLoans.filter(l => l.type === 'taken').reduce((s, l) => s + l.amount - (l.paid_amount || 0), 0);

  const openForm = (loan = null) => {
    if (loan) {
      setEditData(loan);
      setForm({
        type: loan.type, person_name: loan.person_name, amount: loan.amount.toString(),
        paid_amount: (loan.paid_amount || 0).toString(), date: loan.date,
        due_date: loan.due_date || '', notes: loan.notes || '', status: loan.status
      });
    } else {
      setEditData(null);
      setForm({
        type: 'given', person_name: '', amount: '', paid_amount: '0',
        date: new Date().toISOString().split('T')[0], due_date: '', notes: '', status: 'active'
      });
    }
    setShowForm(true);
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setSubmitting(true);
    try {
      const data = {
        ...form,
        amount: parseFloat(form.amount),
        paid_amount: parseFloat(form.paid_amount || '0'),
        due_date: form.due_date || null
      };
      if (editData) await updateLoan(editData.id, data);
      else await addLoan(data);
      setShowForm(false);
    } catch (err) { alert(err.message); }
    setSubmitting(false);
  };

  const handleDelete = async (id) => {
    if (confirm('Delete this loan?')) await deleteLoan(id);
  };

  return (
    <div className="space-y-6 animate-in">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-white">Loans</h1>
          <p className="text-white/40 text-sm mt-1">Track loans given and taken</p>
        </div>
        <button onClick={() => openForm()} className="flex items-center gap-2 px-5 py-2.5 rounded-xl bg-gradient-to-r from-cyan-500 to-purple-600 text-white text-sm font-semibold hover:shadow-lg hover:shadow-cyan-500/25 transition-all">
          <Plus className="w-4 h-4" /> Add Loan
        </button>
      </div>

      {/* Summary */}
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
        <div className="rounded-xl bg-white/5 border border-white/10 p-4">
          <div className="flex items-center gap-2 mb-1">
            <ArrowUpRight className="w-4 h-4 text-orange-400" />
            <p className="text-xs text-white/40">Given (Receivable)</p>
          </div>
          <p className="text-xl font-bold text-orange-400">৳{totalGiven.toLocaleString()}</p>
        </div>
        <div className="rounded-xl bg-white/5 border border-white/10 p-4">
          <div className="flex items-center gap-2 mb-1">
            <ArrowDownLeft className="w-4 h-4 text-blue-400" />
            <p className="text-xs text-white/40">Taken (Payable)</p>
          </div>
          <p className="text-xl font-bold text-blue-400">৳{totalTaken.toLocaleString()}</p>
        </div>
        <div className="rounded-xl bg-white/5 border border-white/10 p-4">
          <p className="text-xs text-white/40">Net Position</p>
          <p className={`text-xl font-bold mt-1 ${totalGiven - totalTaken >= 0 ? 'text-emerald-400' : 'text-red-400'}`}>
            ৳{(totalGiven - totalTaken).toLocaleString()}
          </p>
        </div>
      </div>

      {/* Tabs */}
      <div className="flex gap-2">
        {[['all', 'All'], ['given', '↑ Given'], ['taken', '↓ Taken']].map(([key, label]) => (
          <button key={key} onClick={() => setTab(key)}
            className={`px-4 py-2 rounded-xl text-sm font-medium transition-all ${
              tab === key ? 'bg-white/10 text-white border border-white/20' : 'text-white/40 hover:text-white hover:bg-white/5 border border-transparent'
            }`}>{label}</button>
        ))}
      </div>

      {/* Loan Cards */}
      {loading ? (
        <div className="flex justify-center py-12"><div className="w-8 h-8 border-3 border-cyan-500/30 border-t-cyan-500 rounded-full animate-spin" /></div>
      ) : filtered.length > 0 ? (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          {filtered.map(loan => <LoanCard key={loan.id} loan={loan} onEdit={openForm} onDelete={handleDelete} />)}
        </div>
      ) : (
        <div className="text-center py-16 text-white/30">
          <p className="text-4xl mb-3">🤝</p>
          <p className="text-sm">No loans found</p>
        </div>
      )}

      {/* Form Modal */}
      {showForm && (
        <div className="fixed inset-0 bg-black/60 backdrop-blur-sm flex items-center justify-center z-50 p-4" onClick={() => setShowForm(false)}>
          <div className="bg-[#12122a] border border-white/10 rounded-2xl w-full max-w-md shadow-2xl max-h-[90vh] overflow-y-auto" onClick={e => e.stopPropagation()}>
            <div className="flex items-center justify-between p-6 border-b border-white/10">
              <h2 className="text-lg font-semibold text-white">{editData ? 'Edit' : 'Add'} Loan</h2>
              <button onClick={() => setShowForm(false)} className="text-white/40 hover:text-white transition-colors"><X className="w-5 h-5" /></button>
            </div>
            <form onSubmit={handleSubmit} className="p-6 space-y-4">
              <div className="flex gap-2">
                {['given', 'taken'].map(type => (
                  <button key={type} type="button" onClick={() => setForm(f => ({ ...f, type }))}
                    className={`flex-1 py-2.5 rounded-xl text-sm font-medium transition-all ${
                      form.type === type
                        ? type === 'given' ? 'bg-orange-500/20 text-orange-400 border border-orange-500/30' : 'bg-blue-500/20 text-blue-400 border border-blue-500/30'
                        : 'bg-white/5 text-white/40 border border-white/10 hover:bg-white/10'
                    }`}>{type === 'given' ? '↑ Given' : '↓ Taken'}</button>
                ))}
              </div>
              <div>
                <label className="block text-sm text-white/50 mb-1.5">Person Name</label>
                <input type="text" required value={form.person_name} onChange={e => setForm(f => ({ ...f, person_name: e.target.value }))} placeholder="Who?" className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-2.5 text-white text-sm focus:outline-none focus:border-cyan-500/50 placeholder:text-white/20" />
              </div>
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-sm text-white/50 mb-1.5">Amount</label>
                  <input type="number" required min="0" step="0.01" value={form.amount} onChange={e => setForm(f => ({ ...f, amount: e.target.value }))} className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-2.5 text-white text-sm focus:outline-none focus:border-cyan-500/50" />
                </div>
                <div>
                  <label className="block text-sm text-white/50 mb-1.5">Paid Amount</label>
                  <input type="number" min="0" step="0.01" value={form.paid_amount} onChange={e => setForm(f => ({ ...f, paid_amount: e.target.value }))} className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-2.5 text-white text-sm focus:outline-none focus:border-cyan-500/50" />
                </div>
              </div>
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-sm text-white/50 mb-1.5">Date</label>
                  <input type="date" required value={form.date} onChange={e => setForm(f => ({ ...f, date: e.target.value }))} className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-2.5 text-white text-sm focus:outline-none focus:border-cyan-500/50" />
                </div>
                <div>
                  <label className="block text-sm text-white/50 mb-1.5">Due Date</label>
                  <input type="date" value={form.due_date} onChange={e => setForm(f => ({ ...f, due_date: e.target.value }))} className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-2.5 text-white text-sm focus:outline-none focus:border-cyan-500/50" />
                </div>
              </div>
              <div>
                <label className="block text-sm text-white/50 mb-1.5">Status</label>
                <select value={form.status} onChange={e => setForm(f => ({ ...f, status: e.target.value }))} className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-2.5 text-white text-sm focus:outline-none focus:border-cyan-500/50 appearance-none">
                  <option value="active" className="bg-[#12122a]">Active</option>
                  <option value="partially_paid" className="bg-[#12122a]">Partially Paid</option>
                  <option value="paid" className="bg-[#12122a]">Paid</option>
                </select>
              </div>
              <div>
                <label className="block text-sm text-white/50 mb-1.5">Notes</label>
                <textarea value={form.notes} onChange={e => setForm(f => ({ ...f, notes: e.target.value }))} placeholder="Optional notes..." rows={2} className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-2.5 text-white text-sm focus:outline-none focus:border-cyan-500/50 placeholder:text-white/20 resize-none" />
              </div>
              <button type="submit" disabled={submitting} className="w-full py-3 rounded-xl bg-gradient-to-r from-cyan-500 to-purple-600 text-white font-semibold text-sm hover:shadow-lg hover:shadow-cyan-500/25 transition-all disabled:opacity-50">
                {submitting ? 'Saving...' : editData ? 'Update Loan' : 'Add Loan'}
              </button>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}

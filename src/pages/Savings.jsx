import { useState, useMemo } from 'react';
import { useSavings } from '../hooks/useSavings';
import { useAccounts } from '../context/AccountContext';
import { PiggyBank, Plus, X, Trash2, TrendingUp, TrendingDown } from 'lucide-react';

const MONTHS = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];

export default function Savings() {
  const { savings, loading, addSaving, deleteSaving } = useSavings();
  const { accounts } = useAccounts();
  const [showForm, setShowForm] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const initialForm = {
    type: 'deposit',
    amount: '',
    account_id: '',
    date: new Date().toISOString().split('T')[0],
    purpose: '',
    notes: ''
  };
  const [form, setForm] = useState(initialForm);

  const now = new Date();
  const stats = useMemo(() => {
    const total = savings.reduce((s, e) => s + (e.type === 'deposit' ? 1 : -1) * Number(e.amount), 0);
    const thisMonth = savings
      .filter(e => {
        const d = new Date(e.date);
        return d.getMonth() === now.getMonth() && d.getFullYear() === now.getFullYear();
      })
      .reduce((s, e) => s + (e.type === 'deposit' ? 1 : -1) * Number(e.amount), 0);
    return { total, thisMonth };
  }, [savings]); // eslint-disable-line react-hooks/exhaustive-deps

  // Net saving per month for the last 6 months
  const monthlyTrend = useMemo(() => {
    const rows = [];
    for (let i = 5; i >= 0; i--) {
      const d = new Date(now.getFullYear(), now.getMonth() - i, 1);
      const net = savings
        .filter(e => {
          const ed = new Date(e.date);
          return ed.getMonth() === d.getMonth() && ed.getFullYear() === d.getFullYear();
        })
        .reduce((s, e) => s + (e.type === 'deposit' ? 1 : -1) * Number(e.amount), 0);
      rows.push({ label: `${MONTHS[d.getMonth()]} ${d.getFullYear()}`, net });
    }
    return rows;
  }, [savings]); // eslint-disable-line react-hooks/exhaustive-deps

  const maxNet = Math.max(1, ...monthlyTrend.map(r => Math.abs(r.net)));

  const handleSubmit = async (e) => {
    e.preventDefault();
    setSubmitting(true);
    try {
      await addSaving({
        ...form,
        amount: parseFloat(form.amount),
        account_id: form.account_id || null,
        purpose: form.purpose || null,
        notes: form.notes || null
      });
      setShowForm(false);
      setForm(initialForm);
    } catch (err) {
      alert('Error saving entry: ' + err.message);
    }
    setSubmitting(false);
  };

  const handleDelete = async (id) => {
    if (confirm('Delete this savings entry?')) {
      try {
        await deleteSaving(id);
      } catch (err) {
        alert('Failed to delete: ' + err.message);
      }
    }
  };

  if (loading) return <div className="text-white/50 p-6">Loading savings...</div>;

  return (
    <div className="space-y-6 animate-in">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-white">Savings</h1>
          <p className="text-white/40 text-sm mt-1">Track money you set aside, separate from your goals</p>
        </div>
        <button
          onClick={() => { setForm(initialForm); setShowForm(true); }}
          className="flex items-center gap-2 px-5 py-2.5 rounded-xl bg-gradient-to-r from-emerald-500 to-cyan-500 text-white text-sm font-semibold hover:shadow-lg hover:shadow-emerald-500/25 transition-all"
        >
          <Plus className="w-4 h-4" /> Add Entry
        </button>
      </div>

      {/* Summary */}
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
        <div className="rounded-xl bg-emerald-500/10 border border-emerald-500/20 p-4">
          <p className="text-xs text-emerald-400/70">Total Savings</p>
          <p className="text-xl font-bold text-emerald-400 mt-1">৳{stats.total.toLocaleString()}</p>
        </div>
        <div className="rounded-xl bg-white/5 border border-white/10 p-4">
          <p className="text-xs text-white/40">This Month (net)</p>
          <p className={`text-xl font-bold mt-1 ${stats.thisMonth >= 0 ? 'text-cyan-400' : 'text-red-400'}`}>
            ৳{stats.thisMonth.toLocaleString()}
          </p>
        </div>
        <div className="rounded-xl bg-white/5 border border-white/10 p-4">
          <p className="text-xs text-white/40">Entries</p>
          <p className="text-xl font-bold text-white mt-1">{savings.length}</p>
        </div>
      </div>

      {/* 6-month trend */}
      <div className="rounded-2xl bg-[#1a1a2e] border border-white/10 p-5">
        <h3 className="text-white font-semibold mb-4">Last 6 Months</h3>
        <div className="space-y-3">
          {monthlyTrend.map(row => (
            <div key={row.label} className="flex items-center gap-3">
              <span className="text-xs text-white/40 w-20 shrink-0">{row.label}</span>
              <div className="flex-1 h-2 bg-white/5 rounded-full overflow-hidden">
                <div
                  className={`h-full rounded-full ${row.net >= 0 ? 'bg-gradient-to-r from-emerald-500 to-cyan-500' : 'bg-red-500'}`}
                  style={{ width: `${(Math.abs(row.net) / maxNet) * 100}%` }}
                />
              </div>
              <span className={`text-xs font-medium w-24 text-right ${row.net >= 0 ? 'text-emerald-400' : 'text-red-400'}`}>
                ৳{row.net.toLocaleString()}
              </span>
            </div>
          ))}
        </div>
      </div>

      {/* Entries */}
      {savings.length > 0 ? (
        <div className="rounded-2xl bg-[#1a1a2e] border border-white/10 overflow-hidden">
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="bg-white/5 border-b border-white/10">
                  <th className="text-left py-3 px-5 text-white/60 font-medium">Date</th>
                  <th className="text-left py-3 px-5 text-white/60 font-medium">Type</th>
                  <th className="text-left py-3 px-5 text-white/60 font-medium">Purpose</th>
                  <th className="text-left py-3 px-5 text-white/60 font-medium">Account</th>
                  <th className="text-right py-3 px-5 text-white/60 font-medium">Amount</th>
                  <th className="text-left py-3 px-5 text-white/60 font-medium">Notes</th>
                  <th className="py-3 px-5"></th>
                </tr>
              </thead>
              <tbody>
                {savings.map(entry => (
                  <tr key={entry.id} className="border-b border-white/5 hover:bg-white/[0.02] transition-colors group">
                    <td className="py-3 px-5 text-white/70">{new Date(entry.date).toLocaleDateString()}</td>
                    <td className="py-3 px-5">
                      <span className={`inline-flex items-center gap-1.5 px-2 py-0.5 rounded-lg text-xs font-medium ${
                        entry.type === 'deposit'
                          ? 'bg-emerald-500/15 text-emerald-400'
                          : 'bg-red-500/15 text-red-400'
                      }`}>
                        {entry.type === 'deposit' ? <TrendingUp size={12} /> : <TrendingDown size={12} />}
                        {entry.type === 'deposit' ? 'Deposit' : 'Withdraw'}
                      </span>
                    </td>
                    <td className="py-3 px-5 text-white font-medium">{entry.purpose || '-'}</td>
                    <td className="py-3 px-5 text-white/60">{entry.accounts?.name || '-'}</td>
                    <td className={`py-3 px-5 text-right font-semibold ${entry.type === 'deposit' ? 'text-emerald-400' : 'text-red-400'}`}>
                      {entry.type === 'deposit' ? '+' : '−'}৳{Number(entry.amount).toLocaleString()}
                    </td>
                    <td className="py-3 px-5 text-white/50">{entry.notes || '-'}</td>
                    <td className="py-3 px-5 text-right">
                      <button
                        onClick={() => handleDelete(entry.id)}
                        className="text-white/30 hover:text-red-400 p-1.5 rounded-lg hover:bg-red-500/10 opacity-0 group-hover:opacity-100 transition-all"
                      >
                        <Trash2 size={15} />
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      ) : (
        <div className="text-center py-16 border border-white/5 rounded-2xl bg-white/[0.02]">
          <PiggyBank className="mx-auto text-white/20 mb-4" size={48} />
          <h3 className="text-white/60 font-medium">No savings recorded yet</h3>
          <p className="text-white/40 text-sm mt-1">Add your first deposit to start building your savings history.</p>
        </div>
      )}

      {/* Add form modal */}
      {showForm && (
        <div className="fixed inset-0 bg-black/60 backdrop-blur-sm flex items-center justify-center z-50 p-4" onClick={() => setShowForm(false)}>
          <div className="bg-[#12122a] border border-white/10 rounded-2xl w-full max-w-md shadow-2xl" onClick={e => e.stopPropagation()}>
            <div className="flex items-center justify-between p-6 border-b border-white/10">
              <h2 className="text-lg font-semibold text-white">Add Savings Entry</h2>
              <button onClick={() => setShowForm(false)} className="text-white/40 hover:text-white transition-colors"><X className="w-5 h-5" /></button>
            </div>
            <form onSubmit={handleSubmit} className="p-6 space-y-4">
              <div className="flex gap-2">
                {[
                  { id: 'deposit', label: '💰 Deposit', active: 'bg-emerald-500/20 text-emerald-400 border-emerald-500/30' },
                  { id: 'withdraw', label: '💸 Withdraw', active: 'bg-red-500/20 text-red-400 border-red-500/30' }
                ].map(t => (
                  <button
                    key={t.id}
                    type="button"
                    onClick={() => setForm(f => ({ ...f, type: t.id }))}
                    className={`flex-1 py-2.5 rounded-xl text-sm font-medium transition-all border ${
                      form.type === t.id ? t.active : 'bg-white/5 text-white/40 border-white/10 hover:bg-white/10'
                    }`}
                  >
                    {t.label}
                  </button>
                ))}
              </div>
              <div>
                <label className="block text-sm text-white/50 mb-1.5">Amount (৳)</label>
                <input type="number" required min="0.01" step="0.01" value={form.amount} onChange={e => setForm(f => ({ ...f, amount: e.target.value }))} placeholder="0.00" className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-2.5 text-white text-sm focus:outline-none focus:border-emerald-500/50" autoFocus />
              </div>
              <div>
                <label className="block text-sm text-white/50 mb-1.5">
                  {form.type === 'deposit' ? 'Save From Account' : 'Return To Account'}
                </label>
                <select
                  value={form.account_id}
                  onChange={e => setForm(f => ({ ...f, account_id: e.target.value }))}
                  className="w-full bg-white/5 border border-emerald-500/30 rounded-xl px-4 py-2.5 text-white text-sm focus:outline-none focus:border-emerald-500/50 appearance-none"
                >
                  <option value="" className="bg-[#12122a]">No account (tracked separately)</option>
                  {accounts.map(a => (
                    <option key={a.id} value={a.id} className="bg-[#12122a]">{a.name} ({a.currency}{a.current_balance})</option>
                  ))}
                </select>
                <p className="text-xs text-white/40 mt-1">
                  {form.type === 'deposit'
                    ? 'The amount will be deducted from this account balance.'
                    : 'The amount will be added back to this account balance.'}
                </p>
              </div>
              <div>
                <label className="block text-sm text-white/50 mb-1.5">Purpose (Optional)</label>
                <input type="text" value={form.purpose} onChange={e => setForm(f => ({ ...f, purpose: e.target.value }))} placeholder="e.g. DPS, Emergency Fund, Cash at home" className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-2.5 text-white text-sm focus:outline-none focus:border-emerald-500/50 placeholder:text-white/20" />
              </div>
              <div>
                <label className="block text-sm text-white/50 mb-1.5">Date</label>
                <input type="date" required value={form.date} onChange={e => setForm(f => ({ ...f, date: e.target.value }))} className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-2.5 text-white text-sm focus:outline-none focus:border-emerald-500/50" />
              </div>
              <div>
                <label className="block text-sm text-white/50 mb-1.5">Notes</label>
                <input type="text" value={form.notes} onChange={e => setForm(f => ({ ...f, notes: e.target.value }))} placeholder="Anything to remember?" className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-2.5 text-white text-sm focus:outline-none focus:border-emerald-500/50 placeholder:text-white/20" />
              </div>
              <button type="submit" disabled={submitting} className="w-full py-3 rounded-xl bg-gradient-to-r from-emerald-500 to-cyan-500 text-white font-semibold text-sm hover:shadow-lg hover:shadow-emerald-500/25 transition-all disabled:opacity-50">
                {submitting ? 'Saving...' : form.type === 'deposit' ? 'Add Deposit' : 'Record Withdrawal'}
              </button>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}

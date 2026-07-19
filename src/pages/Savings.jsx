import { useState, useMemo } from 'react';
import { useSavings } from '../hooks/useSavings';
import { useAccounts } from '../context/AccountContext';
import { PiggyBank, Plus, X, Trash2, TrendingUp, TrendingDown, Repeat, Play, Landmark, Pencil } from 'lucide-react';

const MONTHS = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];

export const SAVING_TYPES = [
  { id: 'general', label: '💰 General' },
  { id: 'bank', label: '🏦 Bank Savings' },
  { id: 'dps', label: '📆 DPS' },
  { id: 'fdr', label: '📜 FDR' },
  { id: 'cash', label: '💵 Cash' },
  { id: 'other', label: '📦 Other' }
];
const savingTypeLabel = (id) => SAVING_TYPES.find(t => t.id === id)?.label || id || '💰 General';

export default function Savings() {
  const {
    savings, recurringSavings, savingHeads, loading, addSaving, deleteSaving,
    addSavingHead, updateSavingHead, deleteSavingHead,
    addRecurringSaving, updateRecurringSaving, deleteRecurringSaving, runDueRecurringSavings
  } = useSavings();
  const { accounts } = useAccounts();
  const [showForm, setShowForm] = useState(false);
  const [showRecurringForm, setShowRecurringForm] = useState(false);
  const [showHeadForm, setShowHeadForm] = useState(false);
  const [editHead, setEditHead] = useState(null);
  const [submitting, setSubmitting] = useState(false);
  const [runningDue, setRunningDue] = useState(false);
  const initialForm = {
    type: 'deposit',
    amount: '',
    account_id: '',
    date: new Date().toISOString().split('T')[0],
    purpose: '',
    notes: '',
    saving_type: 'general',
    institution: '',
    head_id: ''
  };
  const [form, setForm] = useState(initialForm);
  const initialRecurringForm = {
    title: '',
    amount: '',
    account_id: '',
    saving_type: 'dps',
    institution: '',
    frequency: 'monthly',
    next_run_date: new Date().toISOString().split('T')[0],
    head_id: ''
  };
  const [recurringForm, setRecurringForm] = useState(initialRecurringForm);
  const initialHeadForm = { name: '', saving_type: 'dps', institution: '', account_number: '', notes: '', interest_rate: '', tenure_months: '', start_date: '' };
  const [headForm, setHeadForm] = useState(initialHeadForm);
  const isMaturingType = headForm.saving_type === 'dps' || headForm.saving_type === 'fdr';

  // Net balance sitting in each head (deposits - withdrawals)
  const headBalances = useMemo(() => {
    const map = {};
    savings.forEach(e => {
      if (!e.head_id) return;
      map[e.head_id] = (map[e.head_id] || 0) + (e.type === 'deposit' ? 1 : -1) * Number(e.amount);
    });
    return map;
  }, [savings]);

  // DPS/FDR maturity projection for heads that have interest_rate + tenure_months set.
  // FDR: current balance is treated as the lump-sum principal (simple interest).
  // DPS: the linked recurring plan's amount is the monthly installment
  // (monthly-compounded annuity); without one, there's nothing to project from.
  const headMaturity = useMemo(() => {
    const map = {};
    savingHeads.forEach(h => {
      if ((h.saving_type !== 'dps' && h.saving_type !== 'fdr') || !h.tenure_months || !h.start_date) return;
      const r = Number(h.interest_rate || 0) / 100;
      const t = Number(h.tenure_months);
      const maturityDate = new Date(h.start_date);
      maturityDate.setMonth(maturityDate.getMonth() + t);
      let value = null;
      if (h.saving_type === 'fdr') {
        value = (headBalances[h.id] || 0) * (1 + r * (t / 12));
      } else {
        const plan = recurringSavings.find(rs => rs.head_id === h.id);
        if (plan) {
          const mr = r / 12;
          const installment = Number(plan.amount);
          value = mr === 0 ? installment * t : installment * ((Math.pow(1 + mr, t) - 1) / mr);
        }
      }
      map[h.id] = { maturityDate, value };
    });
    return map;
  }, [savingHeads, headBalances, recurringSavings]);

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
      // When a head is picked, its type/institution carry over to the entry
      const head = savingHeads.find(h => h.id === form.head_id);
      await addSaving({
        ...form,
        amount: parseFloat(form.amount),
        account_id: form.account_id || null,
        purpose: form.purpose || null,
        notes: form.notes || null,
        saving_type: head ? head.saving_type : form.saving_type,
        institution: head ? head.institution : (form.institution || null),
        head_id: form.head_id || null
      });
      setShowForm(false);
      setForm(initialForm);
    } catch (err) {
      alert('Error saving entry: ' + err.message);
    }
    setSubmitting(false);
  };

  const handleHeadSubmit = async (e) => {
    e.preventDefault();
    setSubmitting(true);
    try {
      const payload = {
        ...headForm,
        institution: headForm.institution || null,
        account_number: headForm.account_number || null,
        notes: headForm.notes || null,
        interest_rate: headForm.interest_rate === '' ? null : parseFloat(headForm.interest_rate),
        tenure_months: headForm.tenure_months === '' ? null : parseInt(headForm.tenure_months),
        start_date: headForm.start_date || null
      };
      if (editHead) await updateSavingHead(editHead.id, payload);
      else await addSavingHead(payload);
      setShowHeadForm(false);
      setEditHead(null);
      setHeadForm(initialHeadForm);
    } catch (err) {
      alert('Error saving head: ' + err.message);
    }
    setSubmitting(false);
  };

  const openHeadForm = (head = null) => {
    setEditHead(head);
    setHeadForm(head ? {
      name: head.name,
      saving_type: head.saving_type || 'general',
      institution: head.institution || '',
      account_number: head.account_number || '',
      notes: head.notes || '',
      interest_rate: head.interest_rate ?? '',
      tenure_months: head.tenure_months ?? '',
      start_date: head.start_date || ''
    } : initialHeadForm);
    setShowHeadForm(true);
  };

  const handleRecurringSubmit = async (e) => {
    e.preventDefault();
    setSubmitting(true);
    try {
      const head = savingHeads.find(h => h.id === recurringForm.head_id);
      await addRecurringSaving({
        ...recurringForm,
        amount: parseFloat(recurringForm.amount),
        account_id: recurringForm.account_id || null,
        saving_type: head ? head.saving_type : recurringForm.saving_type,
        institution: head ? head.institution : (recurringForm.institution || null),
        head_id: recurringForm.head_id || null
      });
      setShowRecurringForm(false);
      setRecurringForm(initialRecurringForm);
    } catch (err) {
      alert('Error adding recurring saving: ' + err.message);
    }
    setSubmitting(false);
  };

  const dueRecurring = recurringSavings.filter(r => r.is_active && new Date(r.next_run_date) <= new Date()).length;

  const handleRunDue = async () => {
    if (!window.confirm(`Run all ${dueRecurring} due recurring saving(s) now? Overdue items catch up for every missed period.`)) return;
    setRunningDue(true);
    try {
      const count = await runDueRecurringSavings();
      alert(`${count} savings entry(ies) created.`);
    } catch (err) {
      alert('Error running due savings: ' + err.message);
    }
    setRunningDue(false);
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

  if (loading) return <div className="text-foreground/50 p-6">Loading savings...</div>;

  return (
    <div className="space-y-6 animate-in">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-foreground">Savings</h1>
          <p className="text-foreground/40 text-sm mt-1">Track money you set aside, separate from your goals — including DPS/FDR with maturity projections via "New Head"</p>
        </div>
        <div className="flex flex-wrap gap-2">
          {dueRecurring > 0 && (
            <button
              onClick={handleRunDue}
              disabled={runningDue}
              className="flex items-center gap-2 px-4 py-2.5 rounded-xl bg-orange-500/20 border border-orange-500/30 text-orange-400 text-sm font-semibold hover:bg-orange-500/30 transition-all disabled:opacity-50"
            >
              <Play className="w-4 h-4" /> {runningDue ? 'Running...' : `Run ${dueRecurring} Due`}
            </button>
          )}
          <button
            onClick={() => openHeadForm()}
            className="flex items-center gap-2 px-4 py-2.5 rounded-xl bg-foreground/5 border border-foreground/10 text-foreground/70 text-sm font-semibold hover:bg-foreground/10 transition-all"
          >
            <Landmark className="w-4 h-4" /> New Head
          </button>
          <button
            onClick={() => { setRecurringForm(initialRecurringForm); setShowRecurringForm(true); }}
            className="flex items-center gap-2 px-4 py-2.5 rounded-xl bg-foreground/5 border border-foreground/10 text-foreground/70 text-sm font-semibold hover:bg-foreground/10 transition-all"
          >
            <Repeat className="w-4 h-4" /> Recurring
          </button>
          <button
            onClick={() => { setForm(initialForm); setShowForm(true); }}
            className="flex items-center gap-2 px-5 py-2.5 rounded-xl bg-gradient-to-r from-emerald-500 to-cyan-500 text-white text-sm font-semibold hover:shadow-lg hover:shadow-emerald-500/25 transition-all"
          >
            <Plus className="w-4 h-4" /> Add Entry
          </button>
        </div>
      </div>

      {/* Summary */}
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
        <div className="rounded-xl bg-emerald-500/10 border border-emerald-500/20 p-4">
          <p className="text-xs text-emerald-400/70">Total Savings</p>
          <p className="text-xl font-bold text-emerald-400 mt-1">৳{stats.total.toLocaleString()}</p>
        </div>
        <div className="rounded-xl bg-foreground/5 border border-foreground/10 p-4">
          <p className="text-xs text-foreground/40">This Month (net)</p>
          <p className={`text-xl font-bold mt-1 ${stats.thisMonth >= 0 ? 'text-cyan-400' : 'text-red-400'}`}>
            ৳{stats.thisMonth.toLocaleString()}
          </p>
        </div>
        <div className="rounded-xl bg-foreground/5 border border-foreground/10 p-4">
          <p className="text-xs text-foreground/40">Entries</p>
          <p className="text-xl font-bold text-foreground mt-1">{savings.length}</p>
        </div>
      </div>

      {/* 6-month trend */}
      <div className="rounded-2xl bg-card border border-foreground/10 p-5">
        <h3 className="text-foreground font-semibold mb-4">Last 6 Months</h3>
        <div className="space-y-3">
          {monthlyTrend.map(row => (
            <div key={row.label} className="flex items-center gap-3">
              <span className="text-xs text-foreground/40 w-20 shrink-0">{row.label}</span>
              <div className="flex-1 h-2 bg-foreground/5 rounded-full overflow-hidden">
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

      {/* Savings heads — where the money sits */}
      {savingHeads.length > 0 && (
        <div className="rounded-2xl bg-card border border-foreground/10 p-5">
          <h3 className="text-foreground font-semibold mb-4 flex items-center gap-2">
            <Landmark size={16} className="text-emerald-400" /> Savings Heads
          </h3>
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3">
            {savingHeads.map(h => (
              <div key={h.id} className="p-4 rounded-xl bg-white/[0.03] border border-foreground/5 group">
                <div className="flex items-start justify-between gap-2">
                  <div className="min-w-0">
                    <p className="text-sm font-medium text-foreground truncate">{h.name}</p>
                    <p className="text-xs text-foreground/40 truncate">
                      {savingTypeLabel(h.saving_type)}{h.institution ? ` • ${h.institution}` : ''}
                    </p>
                    {h.account_number && (
                      <p className="text-xs text-foreground/30 mt-0.5 truncate">A/C: {h.account_number}</p>
                    )}
                  </div>
                  <div className="flex gap-0.5 opacity-100 sm:opacity-0 sm:group-hover:opacity-100 transition-opacity shrink-0">
                    <button onClick={() => openHeadForm(h)} className="p-1.5 rounded-lg text-white/30 hover:text-cyan-400 hover:bg-cyan-500/10 transition-all">
                      <Pencil size={13} />
                    </button>
                    <button
                      onClick={() => { if (confirm(`Delete head "${h.name}"? Its entries stay, only the link is removed.`)) deleteSavingHead(h.id).catch(err => alert(err.message)); }}
                      className="p-1.5 rounded-lg text-white/30 hover:text-red-400 hover:bg-red-500/10 transition-all"
                    >
                      <Trash2 size={13} />
                    </button>
                  </div>
                </div>
                <p className={`text-lg font-bold mt-2 ${(headBalances[h.id] || 0) >= 0 ? 'text-emerald-400' : 'text-red-400'}`}>
                  ৳{(headBalances[h.id] || 0).toLocaleString()}
                </p>
                {headMaturity[h.id] && (
                  <div className="mt-2 pt-2 border-t border-foreground/5 text-xs">
                    <div className="flex justify-between text-foreground/40">
                      <span>Maturity</span>
                      <span>{headMaturity[h.id].maturityDate.toLocaleDateString()}</span>
                    </div>
                    {headMaturity[h.id].value != null && (
                      <div className="flex justify-between mt-0.5">
                        <span className="text-foreground/40">Projected</span>
                        <span className="text-cyan-400 font-medium">৳{Math.round(headMaturity[h.id].value).toLocaleString()}</span>
                      </div>
                    )}
                  </div>
                )}
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Recurring savings plans */}
      {recurringSavings.length > 0 && (
        <div className="rounded-2xl bg-card border border-foreground/10 p-5">
          <h3 className="text-foreground font-semibold mb-4 flex items-center gap-2">
            <Repeat size={16} className="text-cyan-400" /> Recurring Savings
          </h3>
          <div className="space-y-2">
            {recurringSavings.map(r => {
              const due = r.is_active && new Date(r.next_run_date) <= new Date();
              return (
                <div key={r.id} className="flex flex-wrap items-center gap-3 p-3 rounded-xl bg-white/[0.03] border border-foreground/5">
                  <div className="flex-1 min-w-[150px]">
                    <p className="text-sm text-foreground font-medium truncate">{r.title}</p>
                    <p className="text-xs text-foreground/40 truncate">
                      {r.saving_heads?.name ? `🏷️ ${r.saving_heads.name}` : savingTypeLabel(r.saving_type)}
                      {r.institution ? ` • ${r.institution}` : ''}{r.accounts?.name ? ` • from ${r.accounts.name}` : ''}
                    </p>
                  </div>
                  <span className="text-sm font-semibold text-emerald-400">৳{Number(r.amount).toLocaleString()}</span>
                  <span className={`text-xs px-2 py-0.5 rounded-lg capitalize ${due ? 'bg-orange-500/15 text-orange-400' : 'bg-foreground/5 text-white/40'}`}>
                    {r.frequency} • next {new Date(r.next_run_date).toLocaleDateString()}
                  </span>
                  <button
                    onClick={() => updateRecurringSaving(r.id, { is_active: !r.is_active }).catch(err => alert(err.message))}
                    className={`text-xs px-2.5 py-1 rounded-lg border transition-all ${
                      r.is_active
                        ? 'bg-emerald-500/15 text-emerald-400 border-emerald-500/30'
                        : 'bg-foreground/5 text-foreground/40 border-foreground/10'
                    }`}
                  >
                    {r.is_active ? 'Active' : 'Paused'}
                  </button>
                  <button
                    onClick={() => { if (confirm('Delete this recurring saving?')) deleteRecurringSaving(r.id).catch(err => alert(err.message)); }}
                    className="text-white/30 hover:text-red-400 p-1.5 rounded-lg hover:bg-red-500/10 transition-all"
                  >
                    <Trash2 size={14} />
                  </button>
                </div>
              );
            })}
          </div>
        </div>
      )}

      {/* Entries */}
      {savings.length > 0 ? (
        <div className="rounded-2xl bg-card border border-foreground/10 overflow-hidden">
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="bg-foreground/5 border-b border-foreground/10">
                  <th className="text-left py-3 px-5 text-foreground/60 font-medium">Date</th>
                  <th className="text-left py-3 px-5 text-foreground/60 font-medium">Type</th>
                  <th className="text-left py-3 px-5 text-foreground/60 font-medium">Purpose</th>
                  <th className="text-left py-3 px-5 text-foreground/60 font-medium">Kept At</th>
                  <th className="text-left py-3 px-5 text-foreground/60 font-medium">Account</th>
                  <th className="text-right py-3 px-5 text-foreground/60 font-medium">Amount</th>
                  <th className="text-left py-3 px-5 text-foreground/60 font-medium">Notes</th>
                  <th className="py-3 px-5"></th>
                </tr>
              </thead>
              <tbody>
                {savings.map(entry => (
                  <tr key={entry.id} className="border-b border-foreground/5 hover:bg-white/[0.02] transition-colors group">
                    <td className="py-3 px-5 text-foreground/70">{new Date(entry.date).toLocaleDateString()}</td>
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
                    <td className="py-3 px-5 text-foreground font-medium">{entry.purpose || '-'}</td>
                    <td className="py-3 px-5">
                      {entry.saving_heads?.name ? (
                        <>
                          <span className="inline-flex items-center gap-1.5 px-2 py-0.5 rounded-lg text-xs bg-emerald-500/10 text-emerald-300">
                            🏷️ {entry.saving_heads.name}
                          </span>
                          {entry.saving_heads.institution && <p className="text-xs text-foreground/40 mt-1">{entry.saving_heads.institution}</p>}
                        </>
                      ) : (
                        <>
                          <span className="inline-flex items-center gap-1.5 px-2 py-0.5 rounded-lg text-xs bg-cyan-500/10 text-cyan-300">
                            {savingTypeLabel(entry.saving_type)}
                          </span>
                          {entry.institution && <p className="text-xs text-foreground/40 mt-1">{entry.institution}</p>}
                        </>
                      )}
                    </td>
                    <td className="py-3 px-5 text-foreground/60">{entry.accounts?.name || '-'}</td>
                    <td className={`py-3 px-5 text-right font-semibold ${entry.type === 'deposit' ? 'text-emerald-400' : 'text-red-400'}`}>
                      {entry.type === 'deposit' ? '+' : '−'}৳{Number(entry.amount).toLocaleString()}
                    </td>
                    <td className="py-3 px-5 text-foreground/50">{entry.notes || '-'}</td>
                    <td className="py-3 px-5 text-right">
                      <button
                        onClick={() => handleDelete(entry.id)}
                        className="text-white/30 hover:text-red-400 p-1.5 rounded-lg hover:bg-red-500/10 opacity-100 sm:opacity-0 sm:group-hover:opacity-100 transition-all"
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
        <div className="text-center py-16 border border-foreground/5 rounded-2xl bg-white/[0.02]">
          <PiggyBank className="mx-auto text-foreground/20 mb-4" size={48} />
          <h3 className="text-foreground/60 font-medium">No savings recorded yet</h3>
          <p className="text-foreground/40 text-sm mt-1">Add your first deposit to start building your savings history.</p>
        </div>
      )}

      {/* Add form modal */}
      {showForm && (
        <div className="fixed inset-0 bg-black/60 backdrop-blur-sm flex items-center justify-center z-50 p-4" onClick={() => setShowForm(false)}>
          <div className="bg-muted border border-foreground/10 rounded-2xl w-full max-w-md shadow-2xl" onClick={e => e.stopPropagation()}>
            <div className="flex items-center justify-between p-6 border-b border-foreground/10">
              <h2 className="text-lg font-semibold text-foreground">Add Savings Entry</h2>
              <button onClick={() => setShowForm(false)} className="text-foreground/40 hover:text-foreground transition-colors"><X className="w-5 h-5" /></button>
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
                      form.type === t.id ? t.active : 'bg-foreground/5 text-foreground/40 border-foreground/10 hover:bg-foreground/10'
                    }`}
                  >
                    {t.label}
                  </button>
                ))}
              </div>
              <div>
                <label className="block text-sm text-foreground/50 mb-1.5">Amount (৳)</label>
                <input type="number" required min="0.01" step="0.01" value={form.amount} onChange={e => setForm(f => ({ ...f, amount: e.target.value }))} placeholder="0.00" className="w-full bg-foreground/5 border border-foreground/10 rounded-xl px-4 py-2.5 text-foreground text-sm focus:outline-none focus:border-emerald-500/50" autoFocus />
              </div>
              <div>
                <label className="block text-sm text-foreground/50 mb-1.5">
                  {form.type === 'deposit' ? 'Save From Account' : 'Return To Account'}
                </label>
                <select
                  value={form.account_id}
                  onChange={e => setForm(f => ({ ...f, account_id: e.target.value }))}
                  className="w-full bg-foreground/5 border border-emerald-500/30 rounded-xl px-4 py-2.5 text-foreground text-sm focus:outline-none focus:border-emerald-500/50 appearance-none"
                >
                  <option value="" className="bg-muted">No account (tracked separately)</option>
                  {accounts.map(a => (
                    <option key={a.id} value={a.id} className="bg-muted">{a.name} ({a.currency}{a.current_balance})</option>
                  ))}
                </select>
                <p className="text-xs text-foreground/40 mt-1">
                  {form.type === 'deposit'
                    ? 'The amount will be deducted from this account balance.'
                    : 'The amount will be added back to this account balance.'}
                </p>
              </div>
              <div>
                <label className="block text-sm text-foreground/50 mb-1.5">Savings Head (where the money sits)</label>
                <select
                  value={form.head_id}
                  onChange={e => setForm(f => ({ ...f, head_id: e.target.value }))}
                  className="w-full bg-foreground/5 border border-foreground/10 rounded-xl px-4 py-2.5 text-foreground text-sm focus:outline-none focus:border-emerald-500/50 appearance-none"
                >
                  <option value="" className="bg-muted">No head (specify manually below)</option>
                  {savingHeads.map(h => (
                    <option key={h.id} value={h.id} className="bg-muted">
                      {h.name}{h.institution ? ` — ${h.institution}` : ''}
                    </option>
                  ))}
                </select>
                {savingHeads.length === 0 && (
                  <p className="text-xs text-foreground/40 mt-1">Tip: create heads like "DBBL DPS" with the New Head button.</p>
                )}
              </div>
              {!form.head_id && (
                <div className="grid grid-cols-2 gap-3">
                  <div>
                    <label className="block text-sm text-foreground/50 mb-1.5">Saving Type</label>
                    <select
                      value={form.saving_type}
                      onChange={e => setForm(f => ({ ...f, saving_type: e.target.value }))}
                      className="w-full bg-foreground/5 border border-foreground/10 rounded-xl px-4 py-2.5 text-foreground text-sm focus:outline-none focus:border-emerald-500/50 appearance-none"
                    >
                      {SAVING_TYPES.map(t => (
                        <option key={t.id} value={t.id} className="bg-muted">{t.label}</option>
                      ))}
                    </select>
                  </div>
                  <div>
                    <label className="block text-sm text-foreground/50 mb-1.5">Bank / Where</label>
                    <input type="text" value={form.institution} onChange={e => setForm(f => ({ ...f, institution: e.target.value }))} placeholder="e.g. DBBL, Islami Bank" className="w-full bg-foreground/5 border border-foreground/10 rounded-xl px-4 py-2.5 text-foreground text-sm focus:outline-none focus:border-emerald-500/50 placeholder:text-foreground/20" />
                  </div>
                </div>
              )}
              <div>
                <label className="block text-sm text-foreground/50 mb-1.5">Purpose (Optional)</label>
                <input type="text" value={form.purpose} onChange={e => setForm(f => ({ ...f, purpose: e.target.value }))} placeholder="e.g. Emergency Fund, Hajj Fund" className="w-full bg-foreground/5 border border-foreground/10 rounded-xl px-4 py-2.5 text-foreground text-sm focus:outline-none focus:border-emerald-500/50 placeholder:text-foreground/20" />
              </div>
              <div>
                <label className="block text-sm text-foreground/50 mb-1.5">Date</label>
                <input type="date" required value={form.date} onChange={e => setForm(f => ({ ...f, date: e.target.value }))} className="w-full bg-foreground/5 border border-foreground/10 rounded-xl px-4 py-2.5 text-foreground text-sm focus:outline-none focus:border-emerald-500/50" />
              </div>
              <div>
                <label className="block text-sm text-foreground/50 mb-1.5">Notes</label>
                <input type="text" value={form.notes} onChange={e => setForm(f => ({ ...f, notes: e.target.value }))} placeholder="Anything to remember?" className="w-full bg-foreground/5 border border-foreground/10 rounded-xl px-4 py-2.5 text-foreground text-sm focus:outline-none focus:border-emerald-500/50 placeholder:text-foreground/20" />
              </div>
              <button type="submit" disabled={submitting} className="w-full py-3 rounded-xl bg-gradient-to-r from-emerald-500 to-cyan-500 text-white font-semibold text-sm hover:shadow-lg hover:shadow-emerald-500/25 transition-all disabled:opacity-50">
                {submitting ? 'Saving...' : form.type === 'deposit' ? 'Add Deposit' : 'Record Withdrawal'}
              </button>
            </form>
          </div>
        </div>
      )}

      {/* Recurring saving form modal */}
      {showRecurringForm && (
        <div className="fixed inset-0 bg-black/60 backdrop-blur-sm flex items-center justify-center z-50 p-4" onClick={() => setShowRecurringForm(false)}>
          <div className="bg-muted border border-foreground/10 rounded-2xl w-full max-w-md shadow-2xl max-h-[90vh] overflow-y-auto" onClick={e => e.stopPropagation()}>
            <div className="flex items-center justify-between p-6 border-b border-foreground/10">
              <h2 className="text-lg font-semibold text-foreground">New Recurring Saving</h2>
              <button onClick={() => setShowRecurringForm(false)} className="text-foreground/40 hover:text-foreground transition-colors"><X className="w-5 h-5" /></button>
            </div>
            <form onSubmit={handleRecurringSubmit} className="p-6 space-y-4">
              <div>
                <label className="block text-sm text-foreground/50 mb-1.5">Title</label>
                <input type="text" required value={recurringForm.title} onChange={e => setRecurringForm(f => ({ ...f, title: e.target.value }))} placeholder="e.g. DBBL DPS 5000" className="w-full bg-foreground/5 border border-foreground/10 rounded-xl px-4 py-2.5 text-foreground text-sm focus:outline-none focus:border-emerald-500/50 placeholder:text-foreground/20" autoFocus />
              </div>
              <div>
                <label className="block text-sm text-foreground/50 mb-1.5">Savings Head</label>
                <select
                  value={recurringForm.head_id}
                  onChange={e => setRecurringForm(f => ({ ...f, head_id: e.target.value }))}
                  className="w-full bg-foreground/5 border border-foreground/10 rounded-xl px-4 py-2.5 text-foreground text-sm focus:outline-none focus:border-emerald-500/50 appearance-none"
                >
                  <option value="" className="bg-muted">No head (specify manually below)</option>
                  {savingHeads.map(h => (
                    <option key={h.id} value={h.id} className="bg-muted">
                      {h.name}{h.institution ? ` — ${h.institution}` : ''}
                    </option>
                  ))}
                </select>
              </div>
              {!recurringForm.head_id && (
                <div className="grid grid-cols-2 gap-3">
                  <div>
                    <label className="block text-sm text-foreground/50 mb-1.5">Saving Type</label>
                    <select
                      value={recurringForm.saving_type}
                      onChange={e => setRecurringForm(f => ({ ...f, saving_type: e.target.value }))}
                      className="w-full bg-foreground/5 border border-foreground/10 rounded-xl px-4 py-2.5 text-foreground text-sm focus:outline-none focus:border-emerald-500/50 appearance-none"
                    >
                      {SAVING_TYPES.map(t => (
                        <option key={t.id} value={t.id} className="bg-muted">{t.label}</option>
                      ))}
                    </select>
                  </div>
                  <div>
                    <label className="block text-sm text-foreground/50 mb-1.5">Bank / Where</label>
                    <input type="text" value={recurringForm.institution} onChange={e => setRecurringForm(f => ({ ...f, institution: e.target.value }))} placeholder="e.g. DBBL" className="w-full bg-foreground/5 border border-foreground/10 rounded-xl px-4 py-2.5 text-foreground text-sm focus:outline-none focus:border-emerald-500/50 placeholder:text-foreground/20" />
                  </div>
                </div>
              )}
              <div>
                <label className="block text-sm text-foreground/50 mb-1.5">Amount per period (৳)</label>
                <input type="number" required min="0.01" step="0.01" value={recurringForm.amount} onChange={e => setRecurringForm(f => ({ ...f, amount: e.target.value }))} placeholder="0.00" className="w-full bg-foreground/5 border border-foreground/10 rounded-xl px-4 py-2.5 text-foreground text-sm focus:outline-none focus:border-emerald-500/50" />
              </div>
              <div>
                <label className="block text-sm text-foreground/50 mb-1.5">Save From Account (optional)</label>
                <select
                  value={recurringForm.account_id}
                  onChange={e => setRecurringForm(f => ({ ...f, account_id: e.target.value }))}
                  className="w-full bg-foreground/5 border border-emerald-500/30 rounded-xl px-4 py-2.5 text-foreground text-sm focus:outline-none focus:border-emerald-500/50 appearance-none"
                >
                  <option value="" className="bg-muted">No account (tracked separately)</option>
                  {accounts.map(a => (
                    <option key={a.id} value={a.id} className="bg-muted">{a.name} ({a.currency}{a.current_balance})</option>
                  ))}
                </select>
                <p className="text-xs text-foreground/40 mt-1">Each run deducts the amount from this account.</p>
              </div>
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-sm text-foreground/50 mb-1.5">Frequency</label>
                  <select
                    value={recurringForm.frequency}
                    onChange={e => setRecurringForm(f => ({ ...f, frequency: e.target.value }))}
                    className="w-full bg-foreground/5 border border-foreground/10 rounded-xl px-4 py-2.5 text-foreground text-sm focus:outline-none focus:border-emerald-500/50 appearance-none"
                  >
                    <option value="daily" className="bg-muted">Daily</option>
                    <option value="weekly" className="bg-muted">Weekly</option>
                    <option value="monthly" className="bg-muted">Monthly</option>
                    <option value="yearly" className="bg-muted">Yearly</option>
                  </select>
                </div>
                <div>
                  <label className="block text-sm text-foreground/50 mb-1.5">First Run Date</label>
                  <input type="date" required value={recurringForm.next_run_date} onChange={e => setRecurringForm(f => ({ ...f, next_run_date: e.target.value }))} className="w-full bg-foreground/5 border border-foreground/10 rounded-xl px-4 py-2.5 text-foreground text-sm focus:outline-none focus:border-emerald-500/50" />
                </div>
              </div>
              <button type="submit" disabled={submitting} className="w-full py-3 rounded-xl bg-gradient-to-r from-emerald-500 to-cyan-500 text-white font-semibold text-sm hover:shadow-lg hover:shadow-emerald-500/25 transition-all disabled:opacity-50">
                {submitting ? 'Saving...' : 'Add Recurring Saving'}
              </button>
            </form>
          </div>
        </div>
      )}

      {/* Savings head form modal */}
      {showHeadForm && (
        <div className="fixed inset-0 bg-black/60 backdrop-blur-sm flex items-center justify-center z-50 p-4" onClick={() => { setShowHeadForm(false); setEditHead(null); }}>
          <div className="bg-muted border border-foreground/10 rounded-2xl w-full max-w-md shadow-2xl" onClick={e => e.stopPropagation()}>
            <div className="flex items-center justify-between p-6 border-b border-foreground/10">
              <h2 className="text-lg font-semibold text-foreground">{editHead ? 'Edit' : 'New'} Savings Head</h2>
              <button onClick={() => { setShowHeadForm(false); setEditHead(null); }} className="text-foreground/40 hover:text-foreground transition-colors"><X className="w-5 h-5" /></button>
            </div>
            <form onSubmit={handleHeadSubmit} className="p-6 space-y-4">
              <div>
                <label className="block text-sm text-foreground/50 mb-1.5">Head Name</label>
                <input type="text" required value={headForm.name} onChange={e => setHeadForm(f => ({ ...f, name: e.target.value }))} placeholder="e.g. DBBL DPS, Home Cash" className="w-full bg-foreground/5 border border-foreground/10 rounded-xl px-4 py-2.5 text-foreground text-sm focus:outline-none focus:border-emerald-500/50 placeholder:text-foreground/20" autoFocus />
              </div>
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-sm text-foreground/50 mb-1.5">Saving Type</label>
                  <select
                    value={headForm.saving_type}
                    onChange={e => setHeadForm(f => ({ ...f, saving_type: e.target.value }))}
                    className="w-full bg-foreground/5 border border-foreground/10 rounded-xl px-4 py-2.5 text-foreground text-sm focus:outline-none focus:border-emerald-500/50 appearance-none"
                  >
                    {SAVING_TYPES.map(t => (
                      <option key={t.id} value={t.id} className="bg-muted">{t.label}</option>
                    ))}
                  </select>
                </div>
                <div>
                  <label className="block text-sm text-foreground/50 mb-1.5">Bank / Where</label>
                  <input type="text" value={headForm.institution} onChange={e => setHeadForm(f => ({ ...f, institution: e.target.value }))} placeholder="e.g. DBBL" className="w-full bg-foreground/5 border border-foreground/10 rounded-xl px-4 py-2.5 text-foreground text-sm focus:outline-none focus:border-emerald-500/50 placeholder:text-foreground/20" />
                </div>
              </div>
              <div>
                <label className="block text-sm text-foreground/50 mb-1.5">Account Number (Optional)</label>
                <input type="text" value={headForm.account_number} onChange={e => setHeadForm(f => ({ ...f, account_number: e.target.value }))} placeholder="e.g. 123.456.789 / DPS A/C no" className="w-full bg-foreground/5 border border-foreground/10 rounded-xl px-4 py-2.5 text-foreground text-sm focus:outline-none focus:border-emerald-500/50 placeholder:text-foreground/20" />
              </div>
              {isMaturingType && (
                <div className="grid grid-cols-3 gap-3 p-3 rounded-xl bg-emerald-500/[0.06] border border-emerald-500/15">
                  <div>
                    <label className="block text-xs text-foreground/50 mb-1.5">Rate (%/yr)</label>
                    <input type="number" step="0.01" value={headForm.interest_rate} onChange={e => setHeadForm(f => ({ ...f, interest_rate: e.target.value }))} className="w-full bg-foreground/5 border border-foreground/10 rounded-xl px-3 py-2 text-foreground text-sm focus:outline-none focus:border-emerald-500/50" />
                  </div>
                  <div>
                    <label className="block text-xs text-foreground/50 mb-1.5">Tenure (mo)</label>
                    <input type="number" value={headForm.tenure_months} onChange={e => setHeadForm(f => ({ ...f, tenure_months: e.target.value }))} className="w-full bg-foreground/5 border border-foreground/10 rounded-xl px-3 py-2 text-foreground text-sm focus:outline-none focus:border-emerald-500/50" />
                  </div>
                  <div>
                    <label className="block text-xs text-foreground/50 mb-1.5">Start Date</label>
                    <input type="date" value={headForm.start_date} onChange={e => setHeadForm(f => ({ ...f, start_date: e.target.value }))} className="w-full bg-foreground/5 border border-foreground/10 rounded-xl px-3 py-2 text-foreground text-sm focus:outline-none focus:border-emerald-500/50" />
                  </div>
                  <p className="col-span-3 text-[11px] text-foreground/35">Fill these in to see a projected maturity value below. DPS projects off the linked recurring plan's amount — add one via "Recurring".</p>
                </div>
              )}
              <div>
                <label className="block text-sm text-foreground/50 mb-1.5">Notes (Optional)</label>
                <input type="text" value={headForm.notes} onChange={e => setHeadForm(f => ({ ...f, notes: e.target.value }))} className="w-full bg-foreground/5 border border-foreground/10 rounded-xl px-4 py-2.5 text-foreground text-sm focus:outline-none focus:border-emerald-500/50" />
              </div>
              <button type="submit" disabled={submitting} className="w-full py-3 rounded-xl bg-gradient-to-r from-emerald-500 to-cyan-500 text-white font-semibold text-sm hover:shadow-lg hover:shadow-emerald-500/25 transition-all disabled:opacity-50">
                {submitting ? 'Saving...' : editHead ? 'Update Head' : 'Create Head'}
              </button>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}

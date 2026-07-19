import { useState } from 'react';
import { useBudgets } from '../hooks/useBudgets';
import { useCategories } from '../hooks/useCategories';
import { useTransactions } from '../hooks/useTransactions';
import { useBudgetSpend } from '../hooks/useBudgetSpend';
import { useFamily } from '../hooks/useFamily';
import BudgetCard from '../components/BudgetCard';
import { Plus, X } from 'lucide-react';

export default function Budgets() {
  const { budgets, loading, fetchBudgets, addBudget, deleteBudget } = useBudgets();
  const { categories } = useCategories();
  const { transactions } = useTransactions();
  const { members: familyMembers } = useFamily();
  const [showForm, setShowForm] = useState(false);
  const now = new Date();
  const [month, setMonth] = useState(now.getMonth() + 1);
  const [year, setYear] = useState(now.getFullYear());
  const [form, setForm] = useState({ category_id: '', amount: '', family_member_id: '' });
  const [submitting, setSubmitting] = useState(false);

  const expenseCategories = categories.filter(c => c.type === 'expense');

  const budgetData = useBudgetSpend(budgets, transactions);

  const totalBudget = budgets.reduce((s, b) => s + b.amount, 0);
  const totalSpent = budgetData.reduce((s, b) => s + b.spent, 0);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setSubmitting(true);
    try {
      await addBudget({ ...form, amount: parseFloat(form.amount), family_member_id: form.family_member_id || null, month, year });
      setShowForm(false);
      setForm({ category_id: '', amount: '', family_member_id: '' });
    } catch (err) {
      alert(err.message);
    }
    setSubmitting(false);
  };

  const handleDelete = async (id) => {
    if (confirm('Delete this budget?')) await deleteBudget(id);
  };

  const handleMonthChange = (m, y) => {
    setMonth(m);
    setYear(y);
    fetchBudgets(m, y);
  };

  const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];

  return (
    <div className="space-y-6 animate-in">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-foreground">Budgets</h1>
          <p className="text-foreground/40 text-sm mt-1">Set and track monthly budgets</p>
        </div>
        <div className="flex items-center gap-3">
          <select value={month} onChange={e => handleMonthChange(parseInt(e.target.value), year)} className="bg-foreground/5 border border-foreground/10 rounded-xl px-4 py-2.5 text-foreground text-sm focus:outline-none focus:border-cyan-500/50 appearance-none cursor-pointer">
            {months.map((m, i) => <option key={i} value={i + 1} className="bg-muted">{m}</option>)}
          </select>
          <select value={year} onChange={e => handleMonthChange(month, parseInt(e.target.value))} className="bg-foreground/5 border border-foreground/10 rounded-xl px-4 py-2.5 text-foreground text-sm focus:outline-none focus:border-cyan-500/50 appearance-none cursor-pointer">
            {[2024, 2025, 2026, 2027].map(y => <option key={y} value={y} className="bg-muted">{y}</option>)}
          </select>
          <button onClick={() => setShowForm(true)} className="flex items-center gap-2 px-5 py-2.5 rounded-xl bg-gradient-to-r from-cyan-500 to-purple-600 text-white text-sm font-semibold hover:shadow-lg hover:shadow-cyan-500/25 transition-all">
            <Plus className="w-4 h-4" /> Add Budget
          </button>
        </div>
      </div>

      {/* Summary */}
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
        <div className="rounded-xl bg-foreground/5 border border-foreground/10 p-4">
          <p className="text-xs text-foreground/40">Total Budget</p>
          <p className="text-xl font-bold text-foreground mt-1">৳{totalBudget.toLocaleString()}</p>
        </div>
        <div className="rounded-xl bg-foreground/5 border border-foreground/10 p-4">
          <p className="text-xs text-foreground/40">Total Spent</p>
          <p className="text-xl font-bold text-red-400 mt-1">৳{totalSpent.toLocaleString()}</p>
        </div>
        <div className="rounded-xl bg-foreground/5 border border-foreground/10 p-4">
          <p className="text-xs text-foreground/40">Remaining</p>
          <p className={`text-xl font-bold mt-1 ${totalBudget - totalSpent >= 0 ? 'text-emerald-400' : 'text-red-400'}`}>
            ৳{(totalBudget - totalSpent).toLocaleString()}
          </p>
        </div>
      </div>

      {/* Budget Cards */}
      {loading ? (
        <div className="flex justify-center py-12"><div className="w-8 h-8 border-3 border-cyan-500/30 border-t-cyan-500 rounded-full animate-spin" /></div>
      ) : budgetData.length > 0 ? (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          {budgetData.map(({ budget, spent }) => (
            <div key={budget.id} className="relative group">
              <BudgetCard budget={budget} spent={spent} />
              <button
                onClick={() => handleDelete(budget.id)}
                className="absolute top-3 right-3 p-1.5 rounded-lg text-white/0 group-hover:text-white/30 hover:!text-red-400 hover:bg-red-500/10 transition-all"
              >
                <X className="w-4 h-4" />
              </button>
            </div>
          ))}
        </div>
      ) : (
        <div className="text-center py-16 text-foreground/30">
          <p className="text-4xl mb-3">💰</p>
          <p className="text-sm">No budgets set for {months[month - 1]} {year}</p>
          <p className="text-xs text-foreground/20 mt-1">Click "Add Budget" to get started</p>
        </div>
      )}

      {/* Add Budget Modal */}
      {showForm && (
        <div className="fixed inset-0 bg-black/60 backdrop-blur-sm flex items-center justify-center z-50 p-4" onClick={() => setShowForm(false)}>
          <div className="bg-muted border border-foreground/10 rounded-2xl w-full max-w-md shadow-2xl" onClick={e => e.stopPropagation()}>
            <div className="flex items-center justify-between p-6 border-b border-foreground/10">
              <h2 className="text-lg font-semibold text-foreground">Add Budget</h2>
              <button onClick={() => setShowForm(false)} className="text-foreground/40 hover:text-foreground transition-colors"><X className="w-5 h-5" /></button>
            </div>
            <form onSubmit={handleSubmit} className="p-6 space-y-4">
              <div>
                <label className="block text-sm text-foreground/50 mb-1.5">Category</label>
                <select required value={form.category_id} onChange={e => setForm(f => ({ ...f, category_id: e.target.value }))} className="w-full bg-foreground/5 border border-foreground/10 rounded-xl px-4 py-2.5 text-foreground text-sm focus:outline-none focus:border-cyan-500/50 appearance-none">
                  <option value="" className="bg-muted">Select category...</option>
                  {expenseCategories.map(c => <option key={c.id} value={c.id} className="bg-muted">{c.icon} {c.name}</option>)}
                </select>
              </div>
              <div>
                <label className="block text-sm text-foreground/50 mb-1.5">Budget Amount (৳)</label>
                <input type="number" required min="0" step="0.01" value={form.amount} onChange={e => setForm(f => ({ ...f, amount: e.target.value }))} placeholder="0.00" className="w-full bg-foreground/5 border border-foreground/10 rounded-xl px-4 py-2.5 text-foreground text-sm focus:outline-none focus:border-cyan-500/50 placeholder:text-foreground/20" />
              </div>
              {familyMembers.length > 0 && (
                <div>
                  <label className="block text-sm text-foreground/50 mb-1.5">Family Member (Optional)</label>
                  <select value={form.family_member_id} onChange={e => setForm(f => ({ ...f, family_member_id: e.target.value }))} className="w-full bg-foreground/5 border border-foreground/10 rounded-xl px-4 py-2.5 text-foreground text-sm focus:outline-none focus:border-cyan-500/50 appearance-none">
                    <option value="" className="bg-muted">Household (whole family)</option>
                    {familyMembers.map(m => <option key={m.id} value={m.id} className="bg-muted">{m.name}</option>)}
                  </select>
                  <p className="text-foreground/30 text-xs mt-1">A member-scoped budget tracks only their spend; a household budget can coexist for the same category.</p>
                </div>
              )}
              <p className="text-xs text-foreground/30">Budget for: {months[month - 1]} {year}</p>
              <button type="submit" disabled={submitting} className="w-full py-3 rounded-xl bg-gradient-to-r from-cyan-500 to-purple-600 text-white font-semibold text-sm hover:shadow-lg hover:shadow-cyan-500/25 transition-all disabled:opacity-50">
                {submitting ? 'Saving...' : 'Add Budget'}
              </button>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}

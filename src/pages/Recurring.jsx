import { useState } from 'react';
import { useRecurring } from '../hooks/useRecurring';
import { useAccounts } from '../context/AccountContext';
import { useCategories } from '../hooks/useCategories';
import { useTransactions } from '../hooks/useTransactions';
import { useAuth } from '../context/AuthContext';
import { useEntity } from '../context/EntityContext';
import { supabase } from '../lib/supabase';
import { Repeat, Plus, Edit2, Trash2, CalendarClock, Play, Check, Zap } from 'lucide-react';

function getNextRunDate(frequency, fromDate) {
  const d = new Date(fromDate);
  switch (frequency) {
    case 'daily': d.setDate(d.getDate() + 1); break;
    case 'weekly': d.setDate(d.getDate() + 7); break;
    case 'monthly': d.setMonth(d.getMonth() + 1); break;
    case 'yearly': d.setFullYear(d.getFullYear() + 1); break;
    default: d.setMonth(d.getMonth() + 1);
  }
  return d.toISOString().split('T')[0];
}

export default function Recurring() {
  const { recurring, loading, fetchRecurring, addRecurring, updateRecurring, deleteRecurring } = useRecurring();
  const { accounts, fetchAccounts } = useAccounts();
  const { categories } = useCategories();
  const { addTransaction } = useTransactions();
  const { user } = useAuth();
  const { currentEntity } = useEntity();

  const [isAdding, setIsAdding] = useState(false);
  const [editingItem, setEditingItem] = useState(null);
  const [runningId, setRunningId] = useState(null);
  const [ranId, setRanId] = useState(null);
  const [runningAll, setRunningAll] = useState(false);

  const initialForm = {
    title: '',
    type: 'expense',
    amount: '',
    account_id: '',
    category_id: '',
    frequency: 'monthly',
    next_run_date: new Date().toISOString().split('T')[0],
    is_active: true
  };
  const [form, setForm] = useState(initialForm);

  const filteredCategories = categories.filter(c => c.type === form.type);

  const handleSubmit = async (e) => {
    e.preventDefault();
    try {
      // Strip joined relations (categories/accounts) so we only write real columns
      const cleanForm = { ...form };
      delete cleanForm.categories;
      delete cleanForm.accounts;
      const payload = {
        ...cleanForm,
        amount: parseFloat(form.amount)
      };
      if (editingItem) {
        await updateRecurring(editingItem.id, payload);
      } else {
        await addRecurring(payload);
      }
      setIsAdding(false);
      setEditingItem(null);
      setForm(initialForm);
    } catch (err) {
      console.error(err);
      alert('Error saving recurring transaction');
    }
  };

  const handleRunNow = async (item) => {
    if (!window.confirm(`Run "${item.title}" now for ৳${item.amount.toLocaleString()}?`)) return;
    setRunningId(item.id);
    try {
      // Create the transaction
      await addTransaction({
        account_id: item.account_id,
        category_id: item.category_id,
        type: item.type,
        amount: item.amount,
        date: new Date().toISOString().split('T')[0],
        description: `${item.title} (Recurring - Manual Run)`
      });
      // Advance the next_run_date (strip joined relations before writing)
      const nextDate = getNextRunDate(item.frequency, item.next_run_date);
      const cleanItem = { ...item };
      delete cleanItem.categories;
      delete cleanItem.accounts;
      await updateRecurring(item.id, { ...cleanItem, next_run_date: nextDate });
      await fetchAccounts();
      setRanId(item.id);
      setTimeout(() => setRanId(null), 2500);
    } catch (err) {
      console.error(err);
      alert('Error running recurring transaction: ' + err.message);
    }
    setRunningId(null);
  };

  const dueCount = recurring.filter(r => r.is_active && new Date(r.next_run_date) <= new Date()).length;

  const handleRunAllDue = async () => {
    if (!window.confirm(`Run all ${dueCount} due recurring transaction(s) now? Overdue items will catch up for every missed period.`)) return;
    setRunningAll(true);
    try {
      const { data, error } = await supabase.rpc('run_due_recurring', {
        p_user_id: user.id,
        p_entity_id: currentEntity.id
      });
      if (error) throw error;
      await Promise.all([fetchRecurring(), fetchAccounts()]);
      alert(`${data} transaction(s) created.`);
    } catch (err) {
      console.error(err);
      alert('Error running due transactions: ' + err.message);
    }
    setRunningAll(false);
  };

  const totalMonthlyExpense = recurring
    .filter(r => r.is_active && r.type === 'expense' && r.frequency === 'monthly')
    .reduce((s, r) => s + Number(r.amount), 0);

  const totalMonthlyIncome = recurring
    .filter(r => r.is_active && r.type === 'income' && r.frequency === 'monthly')
    .reduce((s, r) => s + Number(r.amount), 0);

  if (loading) return <div className="text-white/50 p-6">Loading recurring transactions...</div>;

  return (
    <div className="space-y-6 animate-in">
      <div className="flex justify-between items-center">
        <div>
          <h1 className="text-2xl font-bold text-white">Recurring Transactions</h1>
          <p className="text-white/40 text-sm mt-1">Manage subscriptions, salaries, and auto-payments.</p>
        </div>
        <div className="flex gap-2">
          {dueCount > 0 && (
            <button
              onClick={handleRunAllDue}
              disabled={runningAll}
              className="flex items-center gap-2 bg-emerald-500 hover:bg-emerald-600 text-white px-4 py-2 rounded-xl transition-colors shadow-lg shadow-emerald-500/20 disabled:opacity-50"
            >
              <Zap size={18} /> {runningAll ? 'Running...' : `Run ${dueCount} Due`}
            </button>
          )}
          <button
            onClick={() => { setIsAdding(true); setEditingItem(null); setForm(initialForm); }}
            className="flex items-center gap-2 bg-orange-500 hover:bg-orange-600 text-white px-4 py-2 rounded-xl transition-colors shadow-lg shadow-orange-500/20"
          >
            <Plus size={18} /> Add Recurring
          </button>
        </div>
      </div>

      {/* Summary */}
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
        <div className="rounded-xl bg-white/5 border border-white/10 p-4">
          <p className="text-xs text-white/40">Active Schedules</p>
          <p className="text-xl font-bold text-white mt-1">{recurring.filter(r => r.is_active).length}</p>
        </div>
        <div className="rounded-xl bg-white/5 border border-white/10 p-4">
          <p className="text-xs text-white/40">Monthly Expenses</p>
          <p className="text-xl font-bold text-red-400 mt-1">৳{totalMonthlyExpense.toLocaleString()}</p>
        </div>
        <div className="rounded-xl bg-white/5 border border-white/10 p-4">
          <p className="text-xs text-white/40">Monthly Income</p>
          <p className="text-xl font-bold text-emerald-400 mt-1">৳{totalMonthlyIncome.toLocaleString()}</p>
        </div>
      </div>

      {(isAdding || editingItem) && (
        <div className="bg-[#1a1a2e] border border-white/10 rounded-2xl p-6">
          <h2 className="text-lg font-semibold text-white mb-4">{editingItem ? 'Edit Item' : 'New Recurring Transaction'}</h2>
          <form onSubmit={handleSubmit} className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            
            <div className="sm:col-span-2 flex gap-2">
              {['expense', 'income'].map(type => (
                <button
                  key={type}
                  type="button"
                  onClick={() => setForm(f => ({ ...f, type, category_id: '' }))}
                  className={`flex-1 py-2.5 rounded-xl text-sm font-medium transition-all ${
                    form.type === type
                      ? type === 'expense'
                        ? 'bg-red-500/20 text-red-400 border border-red-500/30'
                        : 'bg-emerald-500/20 text-emerald-400 border border-emerald-500/30'
                      : 'bg-white/5 text-white/40 border border-white/10 hover:bg-white/10'
                  }`}
                >
                  {type === 'expense' ? '💸 Expense' : '💰 Income'}
                </button>
              ))}
            </div>

            <div>
              <label className="block text-sm text-white/60 mb-1">Title</label>
              <input required type="text" value={form.title} onChange={e => setForm({...form, title: e.target.value})} className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-orange-500/50" placeholder="e.g. Netflix Subscription" />
            </div>
            
            <div>
              <label className="block text-sm text-white/60 mb-1">Amount</label>
              <input required type="number" step="0.01" min="0" value={form.amount} onChange={e => setForm({...form, amount: e.target.value})} className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-orange-500/50" />
            </div>

            <div>
              <label className="block text-sm text-white/60 mb-1">Account</label>
              <select required value={form.account_id} onChange={e => setForm({...form, account_id: e.target.value})} className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-orange-500/50">
                <option value="">Select Account</option>
                {accounts.map(a => <option key={a.id} value={a.id}>{a.name} ({a.currency}{a.current_balance})</option>)}
              </select>
            </div>

            <div>
              <label className="block text-sm text-white/60 mb-1">Category</label>
              <select required value={form.category_id} onChange={e => setForm({...form, category_id: e.target.value})} className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-orange-500/50">
                <option value="">Select Category</option>
                {filteredCategories.map(c => <option key={c.id} value={c.id}>{c.icon} {c.name}</option>)}
              </select>
            </div>

            <div>
              <label className="block text-sm text-white/60 mb-1">Frequency</label>
              <select required value={form.frequency} onChange={e => setForm({...form, frequency: e.target.value})} className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-orange-500/50">
                <option value="daily">Daily</option>
                <option value="weekly">Weekly</option>
                <option value="monthly">Monthly</option>
                <option value="yearly">Yearly</option>
              </select>
            </div>

            <div>
              <label className="block text-sm text-white/60 mb-1">Next Run Date</label>
              <input required type="date" value={form.next_run_date} onChange={e => setForm({...form, next_run_date: e.target.value})} className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-orange-500/50" />
            </div>

            <div className="sm:col-span-2 flex items-center gap-2 mt-2">
              <input type="checkbox" id="is_active" checked={form.is_active} onChange={e => setForm({...form, is_active: e.target.checked})} className="w-4 h-4 rounded border-white/10 bg-[#12122a] text-orange-500 focus:ring-orange-500 focus:ring-offset-[#1a1a2e]" />
              <label htmlFor="is_active" className="text-sm text-white/80">Active (Will run automatically)</label>
            </div>

            <div className="sm:col-span-2 flex justify-end gap-3 mt-4">
              <button type="button" onClick={() => {setIsAdding(false); setEditingItem(null);}} className="px-5 py-2.5 rounded-xl text-white/60 hover:text-white hover:bg-white/5 transition-colors">Cancel</button>
              <button type="submit" className="bg-orange-500 hover:bg-orange-600 text-white px-6 py-2.5 rounded-xl shadow-lg shadow-orange-500/20 transition-all font-medium">Save Setting</button>
            </div>
          </form>
        </div>
      )}

      <div className="bg-[#1a1a2e] border border-white/10 rounded-2xl overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="bg-white/5 border-b border-white/10">
                <th className="text-left py-4 px-5 text-white/60 font-medium">Details</th>
                <th className="text-left py-4 px-5 text-white/60 font-medium">Schedule</th>
                <th className="text-right py-4 px-5 text-white/60 font-medium">Amount</th>
                <th className="text-center py-4 px-5 text-white/60 font-medium">Status</th>
                <th className="text-right py-4 px-5 text-white/60 font-medium">Actions</th>
              </tr>
            </thead>
            <tbody>
              {recurring.length === 0 ? (
                <tr>
                  <td colSpan="5" className="text-center py-12 text-white/40">
                    <Repeat className="mx-auto mb-3 opacity-20" size={32} />
                    No recurring transactions setup yet.
                  </td>
                </tr>
              ) : recurring.map(item => {
                const isExpense = item.type === 'expense';
                const isDue = new Date(item.next_run_date) <= new Date();
                return (
                  <tr key={item.id} className={`border-b border-white/5 hover:bg-white/[0.02] transition-colors ${!item.is_active ? 'opacity-50' : ''}`}>
                    <td className="py-4 px-5">
                      <div className="flex items-center gap-3">
                        <div className={`w-8 h-8 rounded-full flex items-center justify-center ${isExpense ? 'bg-red-500/10 text-red-400' : 'bg-emerald-500/10 text-emerald-400'}`}>
                          {item.categories?.icon || <CalendarClock size={16} />}
                        </div>
                        <div>
                          <p className="text-white font-medium">{item.title}</p>
                          <p className="text-white/40 text-xs">{item.accounts?.name}</p>
                        </div>
                      </div>
                    </td>
                    <td className="py-4 px-5">
                      <p className="text-white/80 capitalize">{item.frequency}</p>
                      <p className={`text-xs ${isDue && item.is_active ? 'text-orange-400 font-medium' : 'text-white/40'}`}>
                        Next: {new Date(item.next_run_date).toLocaleDateString()}
                        {isDue && item.is_active && ' ⚠️'}
                      </p>
                    </td>
                    <td className={`py-4 px-5 text-right font-medium ${isExpense ? 'text-red-400' : 'text-emerald-400'}`}>
                      {isExpense ? '-' : '+'}৳{item.amount.toLocaleString()}
                    </td>
                    <td className="py-4 px-5 text-center">
                      <span className={`px-2 py-1 rounded-md text-xs font-medium ${item.is_active ? 'bg-emerald-500/10 text-emerald-400' : 'bg-white/10 text-white/40'}`}>
                        {item.is_active ? 'Active' : 'Paused'}
                      </span>
                    </td>
                    <td className="py-4 px-5 text-right">
                      <div className="flex justify-end gap-2">
                        {/* Run Now Button */}
                        {item.is_active && (
                          <button
                            onClick={() => handleRunNow(item)}
                            disabled={runningId === item.id}
                            title="Run this transaction now"
                            className={`p-1.5 rounded-lg transition-all ${
                              ranId === item.id
                                ? 'text-emerald-400 bg-emerald-500/10'
                                : 'text-white/40 hover:text-orange-400 hover:bg-orange-500/10'
                            }`}
                          >
                            {ranId === item.id ? <Check size={16} /> : runningId === item.id ? (
                              <div className="w-4 h-4 border-2 border-orange-500/30 border-t-orange-500 rounded-full animate-spin" />
                            ) : (
                              <Play size={16} />
                            )}
                          </button>
                        )}
                        <button onClick={() => { setEditingItem(item); setForm(item); setIsAdding(false); }} className="text-white/40 hover:text-cyan-400 p-1.5 rounded-lg hover:bg-cyan-500/10">
                          <Edit2 size={16} />
                        </button>
                        <button onClick={() => { if (confirm(`Delete recurring "${item.title}"?`)) deleteRecurring(item.id).catch(err => alert("Cannot delete: " + err.message)); }} className="text-white/40 hover:text-red-400 p-1.5 rounded-lg hover:bg-red-500/10">
                          <Trash2 size={16} />
                        </button>
                      </div>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}

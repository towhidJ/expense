import { useState } from 'react';
import { useLiabilities } from '../hooks/useLiabilities';
import { useAccounts } from '../context/AccountContext';
import { useCategories } from '../hooks/useCategories';
import { ShieldAlert, Plus, CreditCard, Landmark, Banknote, Edit2, Trash2 } from 'lucide-react';

export default function Liabilities() {
  const { liabilities, repayments, loading, addLiability, updateLiability, deleteLiability, repayLiability, increaseLiability } = useLiabilities();
  const { accounts, fetchAccounts } = useAccounts();
  const { categories } = useCategories();
  const expenseCategories = categories?.filter(c => c.type === 'expense') || [];
  const [isAdding, setIsAdding] = useState(false);
  const [editingLiability, setEditingLiability] = useState(null);
  const [showPaid, setShowPaid] = useState(false);
  
  // Repayment Modal State
  const [repayingLiability, setRepayingLiability] = useState(null);
  const [repayForm, setRepayForm] = useState({
    account_id: '',
    amount: '',
    date: new Date().toISOString().split('T')[0],
    notes: ''
  });

  // Increase Due Modal State
  const [increasingLiability, setIncreasingLiability] = useState(null);
  const [increaseForm, setIncreaseForm] = useState({
    amount: '',
    expense_category_id: '',
    date: new Date().toISOString().split('T')[0],
    notes: ''
  });

  const initialForm = {
    name: '',
    type: 'loan_taken',
    principal: 0,
    interest_rate: 0,
    due_date: '',
    remaining_balance: 0,
    notes: '',
    received_type: 'cash',
    account_id: '',
    asset_name: '',
    asset_type: 'Electronics',
    expense_category_id: ''
  };
  const [form, setForm] = useState(initialForm);

  const handleSubmit = async (e) => {
    e.preventDefault();
    try {
      if (editingLiability) {
        await updateLiability(editingLiability.id, form);
      } else {
        // For new liabilities, initial remaining balance is usually the principal
        await addLiability({
          ...form,
          remaining_balance: form.remaining_balance || form.principal
        });
      }
      if (form.account_id) {
        await fetchAccounts();
      }
      setIsAdding(false);
      setEditingLiability(null);
      setForm(initialForm);
    } catch (err) {
      console.error(err);
      alert('Error saving liability');
    }
  };

  const handleRepay = async (e) => {
    e.preventDefault();
    try {
      await repayLiability(
        repayingLiability.id,
        repayForm.account_id,
        parseFloat(repayForm.amount),
        repayForm.date,
        repayForm.notes
      );
      await fetchAccounts();
      setRepayingLiability(null);
      setRepayForm({ account_id: '', amount: '', date: new Date().toISOString().split('T')[0], notes: '' });
      alert('Repayment processed successfully!');
    } catch (err) {
      console.error(err);
      alert('Error processing repayment');
    }
  };

  const handleIncrease = async (e) => {
    e.preventDefault();
    try {
      await increaseLiability(
        increasingLiability.id,
        parseFloat(increaseForm.amount),
        increaseForm.expense_category_id,
        increaseForm.date,
        increaseForm.notes
      );
      setIncreasingLiability(null);
      setIncreaseForm({ amount: '', expense_category_id: '', date: new Date().toISOString().split('T')[0], notes: '' });
      alert('Liability increased successfully!');
    } catch (err) {
      console.error(err);
      alert('Error increasing liability');
    }
  };

  const getIcon = (type) => {
    switch(type) {
      case 'loan_taken': return <Landmark className="text-red-400" size={24} />;
      case 'loan_given': return <Banknote className="text-emerald-400" size={24} />;
      case 'credit_card': return <CreditCard className="text-orange-400" size={24} />;
      case 'installment': return <Banknote className="text-yellow-400" size={24} />;
      default: return <ShieldAlert className="text-white/50" size={24} />;
    }
  };

  if (loading) return <div className="text-white/50 p-6">Loading liabilities...</div>;

  return (
    <div className="space-y-6 animate-in relative">
      <div className="flex justify-between items-center">
        <div>
          <h1 className="text-2xl font-bold text-white">Liabilities & Debts</h1>
          <p className="text-white/40 text-sm mt-1">Manage loans, credit cards, and installments.</p>
        </div>
        <div className="flex items-center gap-3">
          <button
            onClick={() => setShowPaid(v => !v)}
            className={`px-3 py-2 rounded-xl text-sm font-medium transition-all border ${
              showPaid ? 'bg-white/10 text-white border-white/20' : 'bg-white/5 text-white/40 border-white/10 hover:bg-white/10 hover:text-white'
            }`}
          >
            {showPaid ? 'Hide Paid' : 'Show Paid'}
          </button>
          <button
            onClick={() => { setIsAdding(true); setEditingLiability(null); setForm(initialForm); }}
            className="flex items-center gap-2 bg-red-500 hover:bg-red-600 text-white px-4 py-2 rounded-xl transition-colors shadow-lg shadow-red-500/20"
          >
            <Plus size={18} /> Add Liability
          </button>
        </div>
      </div>

      {(isAdding || editingLiability) && (
        <div className="bg-[#1a1a2e] border border-white/10 rounded-2xl p-6">
          <h2 className="text-lg font-semibold text-white mb-4">{editingLiability ? 'Edit Liability' : 'New Liability'}</h2>
          <form onSubmit={handleSubmit} className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            
            <div className="sm:col-span-2 mb-2">
              <div className="flex gap-2">
                {[
                  { id: 'loan_taken', label: 'Loan Taken', icon: '↘️', color: 'red' },
                  { id: 'loan_given', label: 'Loan Given', icon: '↗️', color: 'emerald' },
                  { id: 'credit_card', label: 'Credit Card', icon: '💳', color: 'orange' },
                  { id: 'installment', label: 'Installment', icon: '📅', color: 'yellow' }
                ].map(t => (
                  <button
                    key={t.id}
                    type="button"
                    onClick={() => setForm({ ...form, type: t.id })}
                    className={`flex-1 flex flex-col items-center justify-center py-2.5 px-2 rounded-xl text-xs sm:text-sm font-medium transition-all ${
                      form.type === t.id
                        ? `bg-${t.color}-500/20 text-${t.color}-400 border border-${t.color}-500/30`
                        : 'bg-white/5 text-white/40 border border-white/10 hover:bg-white/10'
                    }`}
                  >
                    <span className="text-lg mb-0.5">{t.icon}</span>
                    <span>{t.label}</span>
                  </button>
                ))}
              </div>
            </div>

            <div className="sm:col-span-2">
              <label className="block text-sm text-white/60 mb-1">Name / Source</label>
              <input required type="text" value={form.name} onChange={e => setForm({...form, name: e.target.value})} className={`w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-${form.type === 'loan_given' ? 'emerald' : 'red'}-500/50`} placeholder={form.type === 'loan_given' ? "e.g. Lent to John" : "e.g. Home Loan"} />
            </div>

            <div>
              <label className="block text-sm text-white/60 mb-1">Principal Amount</label>
              <input required type="number" step="0.01" value={form.principal} onChange={e => setForm({...form, principal: parseFloat(e.target.value)})} className={`w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-${form.type === 'loan_given' ? 'emerald' : 'red'}-500/50`} />
            </div>
            <div>
              <label className="block text-sm text-white/60 mb-1">Remaining Balance</label>
              <input required type="number" step="0.01" value={form.remaining_balance} onChange={e => setForm({...form, remaining_balance: parseFloat(e.target.value)})} className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-red-500/50" />
            </div>
            <div>
              <label className="block text-sm text-white/60 mb-1">Interest Rate (%)</label>
              <input type="number" step="0.01" value={form.interest_rate} onChange={e => setForm({...form, interest_rate: parseFloat(e.target.value)})} className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-red-500/50" />
            </div>
            <div>
              <label className="block text-sm text-white/60 mb-1">Due Date</label>
              <input type="date" value={form.due_date} onChange={e => setForm({...form, due_date: e.target.value})} className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-red-500/50" />
            </div>
            <div className="sm:col-span-2">
              <label className="block text-sm text-white/60 mb-2">What did you receive from this liability?</label>
              <div className="grid grid-cols-2 sm:grid-cols-4 gap-2 mb-4">
                {[
                  { id: 'cash', label: 'Cash / Bank' },
                  { id: 'asset', label: 'Physical Asset (EMI)' },
                  { id: 'expense', label: 'Expense (Baki)' },
                  { id: 'none', label: 'Nothing / Past Loan' }
                ].map(opt => (
                  <button
                    key={opt.id}
                    type="button"
                    onClick={() => setForm({ ...form, received_type: opt.id })}
                    className={`py-2 px-2 rounded-xl text-xs sm:text-sm font-medium transition-all border ${
                      form.received_type === opt.id
                        ? 'bg-cyan-500/20 text-cyan-400 border-cyan-500/50'
                        : 'bg-white/5 text-white/40 border-white/10 hover:bg-white/10'
                    }`}
                  >
                    {opt.label}
                  </button>
                ))}
              </div>

              {form.received_type === 'cash' && (
                <div className="animate-in fade-in slide-in-from-top-2">
                  <label className="block text-sm text-white/60 mb-1">Deposit To Account</label>
                  <select value={form.account_id} onChange={e => setForm({...form, account_id: e.target.value})} className="w-full bg-[#12122a] border border-emerald-500/30 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-emerald-500/50">
                    <option value="">Select an account...</option>
                    {accounts.map(a => <option key={a.id} value={a.id}>{a.name} ({a.currency}{a.current_balance})</option>)}
                  </select>
                  <p className="text-xs text-white/40 mt-1">The Principal Amount will be added to this account balance.</p>
                </div>
              )}

              {form.received_type === 'asset' && (
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 animate-in fade-in slide-in-from-top-2">
                  <div>
                    <label className="block text-sm text-white/60 mb-1">Asset Name</label>
                    <input required={form.received_type === 'asset'} type="text" placeholder="e.g. iPhone 15 Pro" value={form.asset_name} onChange={e => setForm({...form, asset_name: e.target.value})} className="w-full bg-[#12122a] border border-cyan-500/30 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-cyan-500/50" />
                  </div>
                  <div>
                    <label className="block text-sm text-white/60 mb-1">Asset Category</label>
                    <select value={form.asset_type} onChange={e => setForm({...form, asset_type: e.target.value})} className="w-full bg-[#12122a] border border-cyan-500/30 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-cyan-500/50">
                      <option value="Electronics">Electronics</option>
                      <option value="Vehicle">Vehicle</option>
                      <option value="Real Estate">Real Estate</option>
                      <option value="Furniture">Furniture</option>
                      <option value="Other">Other</option>
                    </select>
                  </div>
                  <p className="text-xs text-white/40 mt-1 sm:col-span-2">This will automatically create a new Asset in your portfolio with the loan's principal amount.</p>
                </div>
              )}

              {form.received_type === 'expense' && (
                <div className="animate-in fade-in slide-in-from-top-2">
                  <label className="block text-sm text-white/60 mb-1">Expense Category</label>
                  <select required={form.received_type === 'expense'} value={form.expense_category_id} onChange={e => setForm({...form, expense_category_id: e.target.value})} className="w-full bg-[#12122a] border border-red-500/30 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-red-500/50">
                    <option value="">Select a category...</option>
                    {expenseCategories.map(c => <option key={c.id} value={c.id}>{c.icon} {c.name}</option>)}
                  </select>
                  <p className="text-xs text-white/40 mt-1">This will log an Expense transaction without deducting your cash balance.</p>
                </div>
              )}
            </div>
            <div className="sm:col-span-2">
              <label className="block text-sm text-white/60 mb-1">Notes</label>
              <textarea value={form.notes} onChange={e => setForm({...form, notes: e.target.value})} className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-red-500/50" rows={2} />
            </div>
            <div className="sm:col-span-2 flex justify-end gap-3 mt-2">
              <button type="button" onClick={() => {setIsAdding(false); setEditingLiability(null);}} className="px-5 py-2.5 rounded-xl text-white/60 hover:text-white hover:bg-white/5 transition-colors">Cancel</button>
              <button type="submit" className="bg-red-500 hover:bg-red-600 text-white px-6 py-2.5 rounded-xl shadow-lg shadow-red-500/20 transition-all font-medium">Save Liability</button>
            </div>
          </form>
        </div>
      )}

      {/* Repayment Modal */}
      {repayingLiability && (
        <div className="fixed inset-0 bg-black/60 backdrop-blur-sm z-50 flex items-center justify-center p-4">
          <div className="bg-[#1a1a2e] border border-white/10 rounded-2xl p-6 w-full max-w-md shadow-2xl">
            <h2 className="text-xl font-semibold text-white mb-2">Record Repayment</h2>
            <p className="text-sm text-white/50 mb-6">Repaying: <strong className="text-white">{repayingLiability.name}</strong></p>
            
            <form onSubmit={handleRepay} className="space-y-4">
              <div>
                <label className="block text-sm text-white/60 mb-1">Pay From Account</label>
                <select required value={repayForm.account_id} onChange={e => setRepayForm({...repayForm, account_id: e.target.value})} className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-emerald-500/50">
                  <option value="">Select an account...</option>
                  {accounts.map(a => <option key={a.id} value={a.id}>{a.name} ({a.currency}{a.current_balance})</option>)}
                </select>
              </div>
              <div>
                <label className="block text-sm text-white/60 mb-1">Amount</label>
                <input required type="number" step="0.01" max={repayingLiability.remaining_balance} value={repayForm.amount} onChange={e => setRepayForm({...repayForm, amount: e.target.value})} className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-emerald-500/50" placeholder="0.00" />
              </div>
              <div>
                <label className="block text-sm text-white/60 mb-1">Date</label>
                <input required type="date" value={repayForm.date} onChange={e => setRepayForm({...repayForm, date: e.target.value})} className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-emerald-500/50" />
              </div>
              <div>
                <label className="block text-sm text-white/60 mb-1">Notes</label>
                <input type="text" value={repayForm.notes} onChange={e => setRepayForm({...repayForm, notes: e.target.value})} className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-emerald-500/50" />
              </div>
              <div className="flex justify-end gap-3 mt-6">
                <button type="button" onClick={() => setRepayingLiability(null)} className="px-5 py-2.5 rounded-xl text-white/60 hover:text-white hover:bg-white/5 transition-colors">Cancel</button>
                <button type="submit" className="bg-emerald-500 hover:bg-emerald-600 text-white px-6 py-2.5 rounded-xl shadow-lg shadow-emerald-500/20 transition-all font-medium">Confirm Payment</button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Increase Due Modal */}
      {increasingLiability && (
        <div className="fixed inset-0 bg-black/60 backdrop-blur-sm z-50 flex items-center justify-center p-4">
          <div className="bg-[#1a1a2e] border border-white/10 rounded-2xl p-6 w-full max-w-md shadow-2xl">
            <h2 className="text-xl font-semibold text-white mb-2">Add Amount to Due</h2>
            <p className="text-sm text-white/50 mb-6">Increasing Liability: <strong className="text-white">{increasingLiability.name}</strong></p>
            
            <form onSubmit={handleIncrease} className="space-y-4">
              <div>
                <label className="block text-sm text-white/60 mb-1">Additional Amount</label>
                <input required type="number" step="0.01" value={increaseForm.amount} onChange={e => setIncreaseForm({...increaseForm, amount: e.target.value})} className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-red-500/50" placeholder="0.00" />
              </div>
              <div>
                <label className="block text-sm text-white/60 mb-1">Expense Category (Optional)</label>
                <select value={increaseForm.expense_category_id} onChange={e => setIncreaseForm({...increaseForm, expense_category_id: e.target.value})} className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-red-500/50">
                  <option value="">Do not log as expense</option>
                  {expenseCategories.map(c => <option key={c.id} value={c.id}>{c.icon} {c.name}</option>)}
                </select>
                <p className="text-xs text-white/40 mt-1">If selected, this amount will be added to your monthly expenses (e.g. for Groceries baki).</p>
              </div>
              <div>
                <label className="block text-sm text-white/60 mb-1">Date</label>
                <input required type="date" value={increaseForm.date} onChange={e => setIncreaseForm({...increaseForm, date: e.target.value})} className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-red-500/50" />
              </div>
              <div>
                <label className="block text-sm text-white/60 mb-1">Notes</label>
                <input type="text" value={increaseForm.notes} onChange={e => setIncreaseForm({...increaseForm, notes: e.target.value})} className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-red-500/50" />
              </div>
              <div className="flex justify-end gap-3 mt-6">
                <button type="button" onClick={() => setIncreasingLiability(null)} className="px-5 py-2.5 rounded-xl text-white/60 hover:text-white hover:bg-white/5 transition-colors">Cancel</button>
                <button type="submit" className="bg-red-500 hover:bg-red-600 text-white px-6 py-2.5 rounded-xl shadow-lg shadow-red-500/20 transition-all font-medium">Add Amount</button>
              </div>
            </form>
          </div>
        </div>
      )}

      {repayments && repayments.length > 0 && (
        <div className="bg-[#1a1a2e] border border-white/10 rounded-2xl overflow-hidden mt-6">
          <div className="p-5 border-b border-white/10">
            <h3 className="text-white font-semibold">Repayment History</h3>
          </div>
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="bg-white/5 border-b border-white/10">
                  <th className="text-left py-3 px-5 text-white/60 font-medium">Date</th>
                  <th className="text-left py-3 px-5 text-white/60 font-medium">Liability Name</th>
                  <th className="text-left py-3 px-5 text-white/60 font-medium">Paid From</th>
                  <th className="text-right py-3 px-5 text-white/60 font-medium">Amount</th>
                  <th className="text-left py-3 px-5 text-white/60 font-medium">Notes</th>
                </tr>
              </thead>
              <tbody>
                {repayments.map(rep => {
                  const liability = liabilities.find(l => l.id === rep.liability_id);
                  return (
                    <tr key={rep.id} className="border-b border-white/5 hover:bg-white/[0.02] transition-colors">
                      <td className="py-3 px-5 text-white/70">{new Date(rep.date).toLocaleDateString()}</td>
                      <td className="py-3 px-5 text-white font-medium">{liability?.name || 'Unknown'}</td>
                      <td className="py-3 px-5 text-white/70">{rep.accounts?.name || 'Unknown Account'}</td>
                      <td className="py-3 px-5 text-right font-medium text-emerald-400">৳{rep.amount.toLocaleString()}</td>
                      <td className="py-3 px-5 text-white/50">{rep.notes || '-'}</td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        </div>
      )}

      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
        {liabilities
          .filter(l => showPaid || l.remaining_balance > 0)
          .map(liability => {
          const isPaidOff = liability.remaining_balance <= 0;
          const progress = liability.principal > 0 ? Math.min(((liability.principal - liability.remaining_balance) / liability.principal) * 100, 100) : 0;
          return (
            <div key={liability.id} className={`border rounded-2xl p-5 hover:border-white/20 transition-all group ${
              isPaidOff ? 'bg-emerald-500/5 border-emerald-500/20' : 'bg-[#1a1a2e] border-white/10'
            }`}>
              <div className="flex justify-between items-start mb-4">
                <div className="flex items-center gap-3">
                  <div className="w-12 h-12 rounded-full bg-[#12122a] flex items-center justify-center">
                    {getIcon(liability.type)}
                  </div>
                  <div>
                    <div className="flex items-center gap-2">
                      <h3 className="text-white font-medium">{liability.name}</h3>
                      {isPaidOff && (
                        <span className="px-1.5 py-0.5 rounded text-[10px] font-bold bg-emerald-500/20 text-emerald-400 border border-emerald-500/30">✓ PAID</span>
                      )}
                    </div>
                    <p className="text-white/40 text-xs capitalize">{liability.type.replace('_', ' ')}</p>
                  </div>
                </div>
                <div className="flex gap-2 opacity-0 group-hover:opacity-100 transition-opacity">
                  <button onClick={() => { setEditingLiability(liability); setForm(liability); setIsAdding(false); }} className="text-white/40 hover:text-cyan-400 p-1.5 bg-white/5 hover:bg-cyan-500/10 rounded-lg">
                    <Edit2 size={16} />
                  </button>
                  <button onClick={() => deleteLiability(liability.id)} className="text-white/40 hover:text-red-400 p-1.5 bg-white/5 hover:bg-red-500/10 rounded-lg">
                    <Trash2 size={16} />
                  </button>
                </div>
              </div>
              
              <div className="space-y-4 pt-4 border-t border-white/5">
                <div>
                  <div className="flex justify-between text-sm mb-1">
                    <span className="text-white/40">Remaining</span>
                    <span className={`${liability.type === 'loan_given' ? 'text-emerald-400' : 'text-red-400'} font-semibold`}>৳{liability.remaining_balance.toLocaleString()}</span>
                  </div>
                  <div className="h-1.5 w-full bg-[#12122a] rounded-full overflow-hidden">
                    <div className={`h-full ${liability.type === 'loan_given' ? 'bg-emerald-500' : 'bg-red-500'} rounded-full`} style={{ width: `${100 - progress}%` }} />
                  </div>
                </div>

                <div className="flex justify-between items-center text-sm">
                  <div className="flex flex-col">
                    <span className="text-white/40 text-xs">Original</span>
                    <span className="text-white/80 font-medium">৳{liability.principal.toLocaleString()}</span>
                  </div>
                  <div className="flex gap-2">
                    <button 
                      onClick={() => setIncreasingLiability(liability)}
                      className="text-sm bg-white/5 hover:bg-white/10 text-white px-3 py-2 rounded-xl transition-all font-medium"
                      title="Add more amount to this liability"
                    >
                      <Plus size={16} />
                    </button>
                    <button 
                      onClick={() => setRepayingLiability(liability)}
                      className={`text-sm ${liability.type === 'loan_given' ? 'bg-emerald-500 hover:bg-emerald-600 shadow-emerald-500/20' : 'bg-red-500 hover:bg-red-600 shadow-red-500/20'} text-white px-4 py-2 rounded-xl transition-all font-medium shadow-lg`}
                    >
                      {liability.type === 'loan_given' ? 'Receive' : 'Repay'}
                    </button>
                  </div>
                </div>
              </div>
            </div>
          );
        })}
      </div>
      {liabilities.length === 0 && !isAdding && (
        <div className="text-center py-12 border border-white/5 rounded-2xl bg-white/[0.02]">
          <ShieldAlert className="mx-auto text-white/20 mb-4" size={48} />
          <h3 className="text-white/60 font-medium">No liabilities found</h3>
          <p className="text-white/40 text-sm mt-1">Add your active loans or credit cards to track them.</p>
        </div>
      )}
    </div>
  );
}

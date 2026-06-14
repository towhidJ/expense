import { useState } from 'react';
import { useTransfers } from '../hooks/useTransfers';
import { useAccounts } from '../context/AccountContext';
import { ArrowRightLeft, Plus } from 'lucide-react';

export default function Transfers() {
  const { transfers, loading: loadingTransfers, addTransfer } = useTransfers();
  const { accounts, fetchAccounts } = useAccounts();
  const [isAdding, setIsAdding] = useState(false);

  const initialForm = {
    from_account_id: '',
    to_account_id: '',
    amount: '',
    date: new Date().toISOString().split('T')[0],
    notes: ''
  };
  const [form, setForm] = useState(initialForm);

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (form.from_account_id === form.to_account_id) {
      alert("Source and destination accounts must be different.");
      return;
    }
    
    // Ensure sufficient balance
    const sourceAccount = accounts.find(a => a.id === form.from_account_id);
    if (sourceAccount && parseFloat(form.amount) > sourceAccount.current_balance) {
      if (!window.confirm("Warning: Transfer amount exceeds current balance. Continue?")) return;
    }

    try {
      await addTransfer({
        ...form,
        amount: parseFloat(form.amount)
      });
      setIsAdding(false);
      setForm(initialForm);
      // Refresh account balances after transfer
      await fetchAccounts();
    } catch (err) {
      console.error(err);
      alert('Error processing transfer');
    }
  };

  const fromAccount = accounts.find(a => a.id === form.from_account_id);

  if (loadingTransfers) return <div className="text-white/50 p-6">Loading transfers...</div>;

  return (
    <div className="space-y-6 animate-in">
      <div className="flex justify-between items-center">
        <div>
          <h1 className="text-2xl font-bold text-white">Transfer Money</h1>
          <p className="text-white/40 text-sm mt-1">Move funds between your accounts.</p>
        </div>
        <button
          onClick={() => setIsAdding(true)}
          className="flex items-center gap-2 bg-cyan-500 hover:bg-cyan-600 text-white px-4 py-2 rounded-xl transition-colors shadow-lg shadow-cyan-500/20"
        >
          <Plus size={18} /> New Transfer
        </button>
      </div>

      {/* Account balance preview */}
      {accounts.length > 0 && (
        <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-3">
          {accounts.map(acc => (
            <div key={acc.id} className="bg-white/5 border border-white/10 rounded-xl p-3">
              <p className="text-white/40 text-xs truncate">{acc.name}</p>
              <p className="text-white font-semibold mt-1">{acc.currency}{Number(acc.current_balance).toLocaleString()}</p>
            </div>
          ))}
        </div>
      )}

      {isAdding && (
        <div className="bg-[#1a1a2e] border border-white/10 rounded-2xl p-6">
          <h2 className="text-lg font-semibold text-white mb-4">Record a Transfer</h2>
          <form onSubmit={handleSubmit} className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div>
              <label className="block text-sm text-white/60 mb-1">From Account</label>
              <select required value={form.from_account_id} onChange={e => setForm({...form, from_account_id: e.target.value})} className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-cyan-500/50">
                <option value="">Select Account</option>
                {accounts.map(a => <option key={a.id} value={a.id}>{a.name} ({a.currency}{a.current_balance})</option>)}
              </select>
              {fromAccount && (
                <p className="text-xs text-white/40 mt-1">Available: {fromAccount.currency}{Number(fromAccount.current_balance).toLocaleString()}</p>
              )}
            </div>
            <div>
              <label className="block text-sm text-white/60 mb-1">To Account</label>
              <select required value={form.to_account_id} onChange={e => setForm({...form, to_account_id: e.target.value})} className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-cyan-500/50">
                <option value="">Select Account</option>
                {accounts.filter(a => a.id !== form.from_account_id).map(a => <option key={a.id} value={a.id}>{a.name}</option>)}
              </select>
            </div>
            <div>
              <label className="block text-sm text-white/60 mb-1">Amount</label>
              <input required type="number" step="0.01" min="0.01" value={form.amount} onChange={e => setForm({...form, amount: e.target.value})} className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-cyan-500/50" />
            </div>
            <div>
              <label className="block text-sm text-white/60 mb-1">Date</label>
              <input required type="date" value={form.date} onChange={e => setForm({...form, date: e.target.value})} className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-cyan-500/50" />
            </div>
            <div className="sm:col-span-2">
              <label className="block text-sm text-white/60 mb-1">Notes</label>
              <textarea value={form.notes} onChange={e => setForm({...form, notes: e.target.value})} className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-cyan-500/50" rows={2} />
            </div>
            <div className="sm:col-span-2 flex justify-end gap-3 mt-2">
              <button type="button" onClick={() => setIsAdding(false)} className="px-5 py-2.5 rounded-xl text-white/60 hover:text-white hover:bg-white/5 transition-colors">Cancel</button>
              <button type="submit" className="bg-cyan-500 hover:bg-cyan-600 text-white px-6 py-2.5 rounded-xl shadow-lg shadow-cyan-500/20 transition-all font-medium">Transfer Funds</button>
            </div>
          </form>
        </div>
      )}

      <div className="bg-[#1a1a2e] border border-white/10 rounded-2xl overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="bg-white/5 border-b border-white/10">
                <th className="text-left py-3 px-4 text-white/60 font-medium">Date</th>
                <th className="text-left py-3 px-4 text-white/60 font-medium">Transfer</th>
                <th className="text-right py-3 px-4 text-white/60 font-medium">Amount</th>
                <th className="text-left py-3 px-4 text-white/60 font-medium">Notes</th>
              </tr>
            </thead>
            <tbody>
              {transfers.length === 0 ? (
                <tr>
                  <td colSpan="4" className="text-center py-8 text-white/40">No transfers found.</td>
                </tr>
              ) : transfers.map(t => (
                <tr key={t.id} className="border-b border-white/5 hover:bg-white/[0.02] transition-colors">
                  <td className="py-3 px-4 text-white/70">{t.date}</td>
                  <td className="py-3 px-4">
                    <div className="flex items-center gap-2">
                      <span className="text-white/80">{t.from_account?.name || 'Unknown'}</span>
                      <ArrowRightLeft size={14} className="text-white/30 shrink-0" />
                      <span className="text-white/80">{t.to_account?.name || 'Unknown'}</span>
                    </div>
                  </td>
                  <td className="py-3 px-4 text-right font-medium text-cyan-400">
                    ৳{t.amount.toLocaleString()}
                  </td>
                  <td className="py-3 px-4 text-white/50">{t.notes || '-'}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}

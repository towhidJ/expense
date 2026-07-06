import { useState } from 'react';
import { useAccounts } from '../context/AccountContext';
import { Plus, Wallet, Building, CreditCard, Smartphone, Edit2, Trash2, Landmark } from 'lucide-react';

const ACCOUNT_TYPES = [
  { id: 'bank', label: 'Bank', icon: Building, color: 'text-blue-400', bg: 'bg-blue-500/10' },
  { id: 'cash', label: 'Cash', icon: Wallet, color: 'text-emerald-400', bg: 'bg-emerald-500/10' },
  { id: 'mobile', label: 'Mobile', icon: Smartphone, color: 'text-purple-400', bg: 'bg-purple-500/10' },
  { id: 'wallet', label: 'Wallet', icon: Wallet, color: 'text-orange-400', bg: 'bg-orange-500/10' },
  { id: 'credit_card', label: 'Credit Card', icon: CreditCard, color: 'text-red-400', bg: 'bg-red-500/10' },
];

export default function Accounts() {
  const { accounts, loading, addAccount, updateAccount, deleteAccount } = useAccounts();
  const [isAdding, setIsAdding] = useState(false);
  const [editingAccount, setEditingAccount] = useState(null);

  const initialForm = {
    name: '',
    type: 'bank',
    account_number: '',
    opening_balance: 0,
    current_balance: 0,
    currency: '৳',
    notes: ''
  };
  const [form, setForm] = useState(initialForm);

  const handleSubmit = async (e) => {
    e.preventDefault();
    try {
      if (editingAccount) {
        await updateAccount(editingAccount.id, form);
      } else {
        await addAccount(form);
      }
      setIsAdding(false);
      setEditingAccount(null);
      setForm(initialForm);
    } catch (err) {
      console.error(err);
      alert('Error saving account');
    }
  };

  const getIcon = (type) => {
    const t = ACCOUNT_TYPES.find(at => at.id === type);
    if (!t) return <Building className="text-white/50" size={24} />;
    const Icon = t.icon;
    return <Icon className={t.color} size={24} />;
  };


  // Summary totals
  const totalBalance = accounts.reduce((s, a) => s + Number(a.current_balance || 0), 0);
  const byType = ACCOUNT_TYPES.map(t => ({
    ...t,
    total: accounts.filter(a => a.type === t.id).reduce((s, a) => s + Number(a.current_balance || 0), 0),
    count: accounts.filter(a => a.type === t.id).length
  })).filter(t => t.count > 0);

  if (loading) return <div className="text-white/50 p-6">Loading accounts...</div>;

  return (
    <div className="space-y-6 animate-in">
      <div className="flex justify-between items-center">
        <div>
          <h1 className="text-2xl font-bold text-white">Accounts Management</h1>
          <p className="text-white/40 text-sm mt-1">Manage your cash, bank, and digital wallets.</p>
        </div>
        <button
          onClick={() => { setIsAdding(true); setEditingAccount(null); setForm(initialForm); }}
          className="flex items-center gap-2 bg-cyan-500 hover:bg-cyan-600 text-white px-4 py-2 rounded-xl transition-colors shadow-lg shadow-cyan-500/20"
        >
          <Plus size={18} /> Add Account
        </button>
      </div>

      {/* Total Balance Hero */}
      {accounts.length > 0 && (
        <div className="rounded-2xl bg-gradient-to-br from-cyan-500/10 to-purple-600/10 border border-cyan-500/20 p-6">
          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
            <div>
              <div className="flex items-center gap-2 mb-1">
                <Landmark className="w-5 h-5 text-cyan-400" />
                <p className="text-sm text-white/60">Total Cash Position</p>
              </div>
              <p className="text-4xl font-bold text-white">৳{totalBalance.toLocaleString()}</p>
              <p className="text-white/40 text-sm mt-1">{accounts.length} account{accounts.length !== 1 ? 's' : ''}</p>
            </div>
            {/* Type breakdown */}
            <div className="flex flex-wrap gap-3">
              {byType.map(t => (
                <div key={t.id} className={`flex items-center gap-2 px-3 py-2 rounded-xl ${t.bg} border border-white/10`}>
                  <div>{getIcon(t.id)}</div>
                  <div>
                    <p className="text-xs text-white/40">{t.label}</p>
                    <p className="text-sm font-semibold text-white">৳{t.total.toLocaleString()}</p>
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>
      )}

      {(isAdding || editingAccount) && (
        <div className="bg-[#1a1a2e] border border-white/10 rounded-2xl p-6">
          <h2 className="text-lg font-semibold text-white mb-4">{editingAccount ? 'Edit Account' : 'New Account'}</h2>
          <form onSubmit={handleSubmit} className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div>
              <label className="block text-sm text-white/60 mb-1">Account Name</label>
              <input required type="text" value={form.name} onChange={e => setForm({...form, name: e.target.value})} className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-cyan-500/50" placeholder="e.g. City Bank / bKash" />
            </div>
            <div>
              <label className="block text-sm text-white/60 mb-1">Type</label>
              <select value={form.type} onChange={e => setForm({...form, type: e.target.value})} className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-cyan-500/50">
                {ACCOUNT_TYPES.map(t => (
                  <option key={t.id} value={t.id}>{t.label}</option>
                ))}
              </select>
            </div>
            <div className="sm:col-span-2">
              <label className="block text-sm text-white/60 mb-1">Account Number (Optional)</label>
              <input type="text" value={form.account_number || ''} onChange={e => setForm({...form, account_number: e.target.value})} className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-cyan-500/50" placeholder="e.g. bank A/C no, bKash 01XXXXXXXXX, card number" />
            </div>
            <div>
              <label className="block text-sm text-white/60 mb-1">Opening Balance</label>
              <input required type="number" step="0.01" value={form.opening_balance} onChange={e => setForm({...form, opening_balance: parseFloat(e.target.value)})} className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-cyan-500/50" />
            </div>
            <div>
              <label className="block text-sm text-white/60 mb-1">Current Balance</label>
              <input required type="number" step="0.01" value={form.current_balance} onChange={e => setForm({...form, current_balance: parseFloat(e.target.value)})} className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-cyan-500/50" />
            </div>
            <div className="sm:col-span-2">
              <label className="block text-sm text-white/60 mb-1">Notes</label>
              <textarea value={form.notes} onChange={e => setForm({...form, notes: e.target.value})} className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-cyan-500/50" rows={2} />
            </div>
            <div className="sm:col-span-2 flex justify-end gap-3 mt-2">
              <button type="button" onClick={() => {setIsAdding(false); setEditingAccount(null);}} className="px-5 py-2.5 rounded-xl text-white/60 hover:text-white hover:bg-white/5 transition-colors">Cancel</button>
              <button type="submit" className="bg-cyan-500 hover:bg-cyan-600 text-white px-6 py-2.5 rounded-xl shadow-lg shadow-cyan-500/20 transition-all font-medium">Save Account</button>
            </div>
          </form>
        </div>
      )}

      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
        {accounts.map(acc => {
          const typeInfo = ACCOUNT_TYPES.find(t => t.id === acc.type);
          const change = Number(acc.current_balance) - Number(acc.opening_balance);
          return (
            <div key={acc.id} className="bg-[#1a1a2e] border border-white/10 rounded-2xl p-5 hover:border-white/20 transition-colors group">
              <div className="flex justify-between items-start mb-4">
                <div className="flex items-center gap-3">
                  <div className={`w-12 h-12 rounded-full ${typeInfo?.bg || 'bg-white/5'} flex items-center justify-center`}>
                    {getIcon(acc.type)}
                  </div>
                  <div>
                    <h3 className="text-white font-medium">{acc.name}</h3>
                    <p className="text-white/40 text-xs capitalize">{acc.type.replace('_', ' ')}</p>
                    {acc.account_number && (
                      <p className="text-white/30 text-xs mt-0.5">A/C: {acc.account_number}</p>
                    )}
                  </div>
                </div>
                <div className="flex gap-2 opacity-0 group-hover:opacity-100 transition-opacity">
                  <button onClick={() => { setEditingAccount(acc); setForm(acc); setIsAdding(false); }} className="text-white/40 hover:text-cyan-400 p-1.5 bg-white/5 hover:bg-cyan-500/10 rounded-lg">
                    <Edit2 size={16} />
                  </button>
                  <button onClick={() => { if (confirm(`Delete account "${acc.name}"?`)) deleteAccount(acc.id).catch(err => alert("Cannot delete: " + err.message)); }} className="text-white/40 hover:text-red-400 p-1.5 bg-white/5 hover:bg-red-500/10 rounded-lg">
                    <Trash2 size={16} />
                  </button>
                </div>
              </div>
              <div className="pt-4 border-t border-white/5 space-y-2">
                <div className="flex justify-between items-end">
                  <p className="text-white/40 text-sm">Balance</p>
                  {change !== 0 && (
                    <span className={`text-xs font-medium ${change >= 0 ? 'text-emerald-400' : 'text-red-400'}`}>
                      {change >= 0 ? '+' : ''}৳{change.toLocaleString()} from opening
                    </span>
                  )}
                </div>
                <p className="text-2xl font-semibold text-white">{acc.currency}{Number(acc.current_balance).toLocaleString()}</p>
              </div>
            </div>
          );
        })}
      </div>
      {accounts.length === 0 && !isAdding && (
        <div className="text-center py-12 border border-white/5 rounded-2xl bg-white/[0.02]">
          <Wallet className="mx-auto text-white/20 mb-4" size={48} />
          <h3 className="text-white/60 font-medium">No accounts found</h3>
          <p className="text-white/40 text-sm mt-1">Add your first bank account or wallet to get started.</p>
        </div>
      )}
    </div>
  );
}

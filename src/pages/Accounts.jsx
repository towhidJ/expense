import { useState } from 'react';
import { useAccounts } from '../context/AccountContext';
import { Plus, Wallet, Building, CreditCard, Smartphone, Edit2, Trash2 } from 'lucide-react';

export default function Accounts() {
  const { accounts, loading, addAccount, updateAccount, deleteAccount } = useAccounts();
  const [isAdding, setIsAdding] = useState(false);
  const [editingAccount, setEditingAccount] = useState(null);

  const initialForm = {
    name: '',
    type: 'bank',
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
    switch(type) {
      case 'bank': return <Building className="text-blue-400" size={24} />;
      case 'cash': return <Wallet className="text-emerald-400" size={24} />;
      case 'mobile': return <Smartphone className="text-purple-400" size={24} />;
      case 'wallet': return <Wallet className="text-orange-400" size={24} />;
      case 'credit_card': return <CreditCard className="text-red-400" size={24} />;
      default: return <Building className="text-white/50" size={24} />;
    }
  };

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
                <option value="bank">Bank Account</option>
                <option value="cash">Cash</option>
                <option value="mobile">Mobile Banking</option>
                <option value="wallet">Digital Wallet</option>
                <option value="credit_card">Credit Card</option>
              </select>
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
        {accounts.map(acc => (
          <div key={acc.id} className="bg-[#1a1a2e] border border-white/10 rounded-2xl p-5 hover:border-white/20 transition-colors group">
            <div className="flex justify-between items-start mb-4">
              <div className="flex items-center gap-3">
                <div className="w-12 h-12 rounded-full bg-[#12122a] flex items-center justify-center">
                  {getIcon(acc.type)}
                </div>
                <div>
                  <h3 className="text-white font-medium">{acc.name}</h3>
                  <p className="text-white/40 text-xs capitalize">{acc.type.replace('_', ' ')}</p>
                </div>
              </div>
              <div className="flex gap-2 opacity-0 group-hover:opacity-100 transition-opacity">
                <button onClick={() => { setEditingAccount(acc); setForm(acc); setIsAdding(false); }} className="text-white/40 hover:text-cyan-400 p-1.5 bg-white/5 hover:bg-cyan-500/10 rounded-lg">
                  <Edit2 size={16} />
                </button>
                <button onClick={() => deleteAccount(acc.id)} className="text-white/40 hover:text-red-400 p-1.5 bg-white/5 hover:bg-red-500/10 rounded-lg">
                  <Trash2 size={16} />
                </button>
              </div>
            </div>
            <div className="pt-4 border-t border-white/5">
              <p className="text-white/40 text-sm">Balance</p>
              <p className="text-2xl font-semibold text-white">{acc.currency}{acc.current_balance.toLocaleString()}</p>
            </div>
          </div>
        ))}
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

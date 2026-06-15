import { useState, useEffect } from 'react';
import { X } from 'lucide-react';
import { useAssets } from '../hooks/useAssets';
import { useAccounts } from '../context/AccountContext';
import { useAttachments } from '../hooks/useAttachments';
import DocumentUpload from './DocumentUpload';

export default function TransactionForm({ isOpen, onClose, onSubmit, categories, editData }) {
  const { assets } = useAssets();
  const { accounts } = useAccounts();
  const { fetchAttachments, deleteAttachment } = useAttachments();
  const [form, setForm] = useState({
    type: 'expense',
    category_id: '',
    account_id: '',
    asset_id: '',
    amount: '',
    description: '',
    date: new Date().toISOString().split('T')[0]
  });
  const [files, setFiles] = useState([]);
  const [existing, setExisting] = useState([]);
  const [submitting, setSubmitting] = useState(false);

  useEffect(() => {
    setFiles([]);
    if (editData) {
      setForm({
        type: editData.type,
        category_id: editData.category_id,
        account_id: editData.account_id || '',
        asset_id: editData.asset_id || '',
        amount: editData.amount.toString(),
        description: editData.description || '',
        date: editData.date
      });
      fetchAttachments({ transactionId: editData.id }).then(setExisting);
    } else {
      setExisting([]);
      setForm({
        type: 'expense',
        category_id: '',
        account_id: '',
        asset_id: '',
        amount: '',
        description: '',
        date: new Date().toISOString().split('T')[0]
      });
    }
  }, [editData, isOpen, fetchAttachments]);

  const filteredCategories = categories.filter(c => c.type === form.type);

  const handleRemoveExisting = async (att) => {
    try {
      await deleteAttachment(att);
      setExisting(prev => prev.filter(a => a.id !== att.id));
    } catch (err) {
      alert(err.message);
    }
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setSubmitting(true);
    try {
      await onSubmit({
        ...form,
        amount: parseFloat(form.amount),
        asset_id: form.type === 'expense' && form.asset_id ? form.asset_id : null
      }, editData?.id, files);
      onClose();
    } catch (err) {
      alert(err.message);
    }
    setSubmitting(false);
  };

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 bg-black/60 backdrop-blur-sm flex items-center justify-center z-50 p-4" onClick={onClose}>
      <div className="bg-[#12122a] border border-white/10 rounded-2xl w-full max-w-md shadow-2xl max-h-[90vh] overflow-y-auto" onClick={e => e.stopPropagation()}>
        <div className="flex items-center justify-between p-6 border-b border-white/10">
          <h2 className="text-lg font-semibold text-white">{editData ? 'Edit' : 'Add'} Transaction</h2>
          <button onClick={onClose} className="text-white/40 hover:text-white transition-colors">
            <X className="w-5 h-5" />
          </button>
        </div>
        <form onSubmit={handleSubmit} className="p-6 space-y-4">
          <div className="flex gap-2">
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
            <label className="block text-sm text-white/50 mb-1.5">Category</label>
            <select
              required
              value={form.category_id}
              onChange={e => setForm(f => ({ ...f, category_id: e.target.value }))}
              className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-2.5 text-white text-sm focus:outline-none focus:border-cyan-500/50 transition-colors appearance-none"
            >
              <option value="" className="bg-[#12122a]">Select category...</option>
              {filteredCategories.map(c => (
                <option key={c.id} value={c.id} className="bg-[#12122a]">{c.icon} {c.name}</option>
              ))}
            </select>
          </div>

          <div>
            <label className="block text-sm text-white/50 mb-1.5">Account (Source/Destination)</label>
            <select
              required
              value={form.account_id}
              onChange={e => setForm(f => ({ ...f, account_id: e.target.value }))}
              className="w-full bg-white/5 border border-emerald-500/30 rounded-xl px-4 py-2.5 text-white text-sm focus:outline-none focus:border-emerald-500/50 transition-colors appearance-none"
            >
              <option value="" className="bg-[#12122a]">Select account...</option>
              {accounts.map(a => (
                <option key={a.id} value={a.id} className="bg-[#12122a]">{a.name} ({a.currency}{a.current_balance})</option>
              ))}
            </select>
          </div>

          {form.type === 'expense' && assets && assets.length > 0 && (
            <div>
              <label className="block text-sm text-white/50 mb-1.5">Asset (Optional)</label>
              <select
                value={form.asset_id}
                onChange={e => setForm(f => ({ ...f, asset_id: e.target.value }))}
                className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-2.5 text-white text-sm focus:outline-none focus:border-cyan-500/50 transition-colors appearance-none"
              >
                <option value="" className="bg-[#12122a]">None</option>
                {assets.map(a => (
                  <option key={a.id} value={a.id} className="bg-[#12122a]">🏍️ {a.name}</option>
                ))}
              </select>
            </div>
          )}

          <div>
            <label className="block text-sm text-white/50 mb-1.5">Amount (৳)</label>
            <input
              type="number"
              required
              min="0"
              step="0.01"
              value={form.amount}
              onChange={e => setForm(f => ({ ...f, amount: e.target.value }))}
              placeholder="0.00"
              className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-2.5 text-white text-sm focus:outline-none focus:border-cyan-500/50 transition-colors placeholder:text-white/20"
            />
          </div>

          <div>
            <label className="block text-sm text-white/50 mb-1.5">Description</label>
            <input
              type="text"
              value={form.description}
              onChange={e => setForm(f => ({ ...f, description: e.target.value }))}
              placeholder="What was this for?"
              className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-2.5 text-white text-sm focus:outline-none focus:border-cyan-500/50 transition-colors placeholder:text-white/20"
            />
          </div>

          <div>
            <label className="block text-sm text-white/50 mb-1.5">Date</label>
            <input
              type="date"
              required
              value={form.date}
              onChange={e => setForm(f => ({ ...f, date: e.target.value }))}
              className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-2.5 text-white text-sm focus:outline-none focus:border-cyan-500/50 transition-colors"
            />
          </div>

          <DocumentUpload
            files={files}
            onChange={setFiles}
            existing={existing}
            onRemoveExisting={handleRemoveExisting}
          />

          <button
            type="submit"
            disabled={submitting}
            className="w-full py-3 rounded-xl bg-gradient-to-r from-cyan-500 to-purple-600 text-white font-semibold text-sm hover:shadow-lg hover:shadow-cyan-500/25 transition-all disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {submitting ? 'Saving...' : editData ? 'Update Transaction' : 'Add Transaction'}
          </button>
        </form>
      </div>
    </div>
  );
}

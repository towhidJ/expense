import { useState } from 'react';
import { Plus, Minus, Trash2, Package, AlertTriangle } from 'lucide-react';

export default function StockTab({ stockItems, isManager, addStockItem, adjustStock, deleteStockItem }) {
  const initialForm = { name: '', quantity: '', unit: '', low_stock_threshold: '', expiry_date: '' };
  const [form, setForm] = useState(initialForm);
  const [isAdding, setIsAdding] = useState(false);
  const [saving, setSaving] = useState(false);
  const [adjusting, setAdjusting] = useState({}); // { [id]: amount }

  const handleSubmit = async (e) => {
    e.preventDefault();
    setSaving(true);
    try {
      await addStockItem(form);
      setIsAdding(false);
      setForm(initialForm);
    } catch (err) {
      console.error(err);
      alert('Error adding stock item: ' + err.message);
    } finally {
      setSaving(false);
    }
  };

  const handleAdjust = async (id, sign) => {
    const amount = Number(adjusting[id]);
    if (!amount || amount <= 0) return;
    try {
      await adjustStock(id, sign * amount);
      setAdjusting(a => ({ ...a, [id]: '' }));
    } catch (err) {
      alert('Error adjusting stock: ' + err.message);
    }
  };

  const isLow = (item) => item.low_stock_threshold != null && Number(item.quantity) <= Number(item.low_stock_threshold);
  const expiryDays = (item) => item.expiry_date ? Math.ceil((new Date(item.expiry_date) - new Date()) / 86400000) : null;

  return (
    <div className="space-y-4">
      <div className="flex justify-end">
        <button
          onClick={() => { setIsAdding(true); setForm(initialForm); }}
          className="flex items-center gap-2 bg-cyan-500 hover:bg-cyan-600 text-white px-4 py-2 rounded-xl transition-colors shadow-lg shadow-cyan-500/20"
        >
          <Plus size={18} /> Add Stock Item
        </button>
      </div>

      {isAdding && (
        <div className="bg-[#1a1a2e] border border-white/10 rounded-2xl p-6">
          <h2 className="text-lg font-semibold text-white mb-4">New Stock Item</h2>
          <form onSubmit={handleSubmit} className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div>
              <label className="block text-sm text-white/60 mb-1">Name</label>
              <input required type="text" value={form.name} onChange={e => setForm({ ...form, name: e.target.value })} placeholder="Rice / চাল" className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-cyan-500/50" />
            </div>
            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="block text-sm text-white/60 mb-1">Quantity</label>
                <input type="number" min="0" step="0.01" value={form.quantity} onChange={e => setForm({ ...form, quantity: e.target.value })} className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-cyan-500/50" />
              </div>
              <div>
                <label className="block text-sm text-white/60 mb-1">Unit</label>
                <input type="text" value={form.unit} onChange={e => setForm({ ...form, unit: e.target.value })} placeholder="kg" className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-cyan-500/50" />
              </div>
            </div>
            <div>
              <label className="block text-sm text-white/60 mb-1">Low-stock alert below</label>
              <input type="number" min="0" step="0.01" value={form.low_stock_threshold} onChange={e => setForm({ ...form, low_stock_threshold: e.target.value })} placeholder="optional" className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-cyan-500/50" />
            </div>
            <div>
              <label className="block text-sm text-white/60 mb-1">Expiry date</label>
              <input type="date" value={form.expiry_date} onChange={e => setForm({ ...form, expiry_date: e.target.value })} className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-cyan-500/50" />
            </div>
            <div className="sm:col-span-2 flex justify-end gap-3 mt-2">
              <button type="button" onClick={() => setIsAdding(false)} className="px-5 py-2.5 rounded-xl text-white/60 hover:text-white hover:bg-white/5 transition-colors">Cancel</button>
              <button type="submit" disabled={saving} className="bg-cyan-500 hover:bg-cyan-600 text-white px-6 py-2.5 rounded-xl shadow-lg shadow-cyan-500/20 transition-all font-medium disabled:opacity-50">
                {saving ? 'Saving...' : 'Save'}
              </button>
            </div>
          </form>
        </div>
      )}

      <div className="bg-[#1a1a2e] border border-white/10 rounded-2xl divide-y divide-white/5">
        {stockItems.map(item => (
          <div key={item.id} className="flex flex-wrap items-center gap-3 px-4 py-3">
            <div className={`w-9 h-9 rounded-xl flex items-center justify-center shrink-0 ${isLow(item) ? 'bg-red-500/10 text-red-400' : 'bg-cyan-500/10 text-cyan-400'}`}>
              <Package size={18} />
            </div>
            <div className="flex-1 min-w-[140px]">
              <p className="text-white text-sm font-medium flex items-center gap-2">
                {item.name}
                {isLow(item) && <span title="Low stock" className="text-red-400"><AlertTriangle size={13} /></span>}
              </p>
              <p className="text-white/40 text-xs">
                {item.quantity} {item.unit || ''}
                {expiryDays(item) != null && (
                  expiryDays(item) < 0
                    ? <span className="text-red-400 font-medium"> · expired!</span>
                    : expiryDays(item) <= 7
                      ? <span className="text-amber-400 font-medium"> · expires in {expiryDays(item)}d</span>
                      : <span> · exp {new Date(item.expiry_date).toLocaleDateString()}</span>
                )}
              </p>
            </div>
            <div className="flex items-center gap-1.5">
              <input
                type="number" min="0" step="0.01" placeholder="amount"
                value={adjusting[item.id] || ''}
                onChange={e => setAdjusting(a => ({ ...a, [item.id]: e.target.value }))}
                className="w-20 bg-[#12122a] border border-white/10 rounded-lg px-2 py-1.5 text-white text-sm focus:outline-none focus:border-cyan-500/50"
              />
              <button onClick={() => handleAdjust(item.id, 1)} title="Stock in" className="p-1.5 rounded-lg bg-emerald-500/10 border border-emerald-500/20 text-emerald-400 hover:bg-emerald-500/20">
                <Plus size={14} />
              </button>
              <button onClick={() => handleAdjust(item.id, -1)} title="Stock out" className="p-1.5 rounded-lg bg-orange-500/10 border border-orange-500/20 text-orange-400 hover:bg-orange-500/20">
                <Minus size={14} />
              </button>
            </div>
            {isManager && (
              <button onClick={() => { if (confirm(`Remove "${item.name}" from stock?`)) deleteStockItem(item.id).catch(err => alert(err.message)); }} className="p-1.5 rounded-lg bg-[#12122a] border border-white/10 text-white/60 hover:text-red-400">
                <Trash2 size={14} />
              </button>
            )}
          </div>
        ))}
        {stockItems.length === 0 && (
          <div className="px-4 py-10 text-center text-white/40 text-sm">No stock items yet. Add what's in the pantry.</div>
        )}
      </div>
      <p className="text-white/30 text-xs">Anyone can adjust quantities (stock in/out) — it's a shared list.{isManager ? ' Only a manager can remove an item.' : ''}</p>
    </div>
  );
}

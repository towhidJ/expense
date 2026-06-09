import { useState, useMemo } from 'react';
import { useAssets } from '../hooks/useAssets';
import { useTransactions } from '../hooks/useTransactions';
import AssetCard from '../components/AssetCard';
import { Plus, X } from 'lucide-react';

export default function Assets() {
  const { assets, loading, addAsset, updateAsset, deleteAsset } = useAssets();
  const { transactions } = useTransactions();
  const [showForm, setShowForm] = useState(false);
  const [editData, setEditData] = useState(null);
  const [form, setForm] = useState({
    name: '', type: 'Property', purchase_value: '', current_value: '', depreciation: '', purchase_date: new Date().toISOString().split('T')[0], notes: ''
  });
  const [submitting, setSubmitting] = useState(false);

  const totalValue = assets.reduce((s, a) => s + Number(a.current_value || a.value || 0), 0);

  const assetExpenses = useMemo(() => {
    const map = {};
    transactions.filter(t => t.type === 'expense' && t.asset_id).forEach(t => {
      map[t.asset_id] = (map[t.asset_id] || 0) + t.amount;
    });
    return map;
  }, [transactions]);

  const openForm = (asset = null) => {
    if (asset) {
      setEditData(asset);
      setForm({
        name: asset.name, 
        type: asset.type || 'Other', 
        purchase_value: asset.purchase_value?.toString() || asset.value?.toString() || '',
        current_value: asset.current_value?.toString() || asset.value?.toString() || '',
        depreciation: asset.depreciation?.toString() || '',
        purchase_date: asset.purchase_date, 
        notes: asset.notes || ''
      });
    } else {
      setEditData(null);
      setForm({
        name: '', type: 'Property', purchase_value: '', current_value: '', depreciation: '', purchase_date: new Date().toISOString().split('T')[0], notes: ''
      });
    }
    setShowForm(true);
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setSubmitting(true);
    try {
      const data = { 
        ...form, 
        purchase_value: parseFloat(form.purchase_value || 0),
        current_value: parseFloat(form.current_value || 0),
        depreciation: parseFloat(form.depreciation || 0),
        value: parseFloat(form.current_value || 0) // Keep backward compatibility with old components
      };
      if (editData) await updateAsset(editData.id, data);
      else await addAsset(data);
      setShowForm(false);
    } catch (err) { alert(err.message); }
    setSubmitting(false);
  };

  const handleDelete = async (id) => {
    if (confirm('Delete this asset? It will not delete linked expenses, but the link will be broken.')) {
      await deleteAsset(id);
    }
  };

  return (
    <div className="space-y-6 animate-in">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-white">Assets</h1>
          <p className="text-white/40 text-sm mt-1">Track belongings and their associated expenses</p>
        </div>
        <button onClick={() => openForm()} className="flex items-center gap-2 px-5 py-2.5 rounded-xl bg-gradient-to-r from-cyan-500 to-purple-600 text-white text-sm font-semibold hover:shadow-lg hover:shadow-cyan-500/25 transition-all">
          <Plus className="w-4 h-4" /> Add Asset
        </button>
      </div>

      <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
        <div className="rounded-xl bg-white/5 border border-white/10 p-4">
          <p className="text-xs text-white/40">Total Assets Value</p>
          <p className="text-xl font-bold text-cyan-400 mt-1">৳{totalValue.toLocaleString()}</p>
        </div>
        <div className="rounded-xl bg-white/5 border border-white/10 p-4">
          <p className="text-xs text-white/40">Registered Assets</p>
          <p className="text-xl font-bold text-white mt-1">{assets.length}</p>
        </div>
      </div>

      {loading ? (
        <div className="flex justify-center py-12"><div className="w-8 h-8 border-3 border-cyan-500/30 border-t-cyan-500 rounded-full animate-spin" /></div>
      ) : assets.length > 0 ? (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          {assets.map(asset => (
            <AssetCard key={asset.id} asset={asset} totalExpense={assetExpenses[asset.id] || 0} onEdit={openForm} onDelete={handleDelete} />
          ))}
        </div>
      ) : (
        <div className="text-center py-16 text-white/30">
          <p className="text-4xl mb-3">🏍️</p>
          <p className="text-sm">No assets tracked yet.</p>
          <p className="text-xs text-white/20 mt-1">Add a bike, car, or laptop to track its expenses!</p>
        </div>
      )}

      {showForm && (
        <div className="fixed inset-0 bg-black/60 backdrop-blur-sm flex items-center justify-center z-50 p-4" onClick={() => setShowForm(false)}>
          <div className="bg-[#12122a] border border-white/10 rounded-2xl w-full max-w-md shadow-2xl" onClick={e => e.stopPropagation()}>
            <div className="flex items-center justify-between p-6 border-b border-white/10">
              <h2 className="text-lg font-semibold text-white">{editData ? 'Edit' : 'Add'} Asset</h2>
              <button onClick={() => setShowForm(false)} className="text-white/40 hover:text-white transition-colors"><X className="w-5 h-5" /></button>
            </div>
            <form onSubmit={handleSubmit} className="p-6 space-y-4">
              <div>
                <label className="block text-sm text-white/50 mb-1.5">Asset Name</label>
                <input type="text" required value={form.name} onChange={e => setForm(f => ({ ...f, name: e.target.value }))} placeholder="e.g. Yamaha FZ" className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-2.5 text-white text-sm focus:outline-none focus:border-cyan-500/50" />
              </div>
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-sm text-white/50 mb-1.5">Type</label>
                  <select value={form.type} onChange={e => setForm(f => ({ ...f, type: e.target.value }))} className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-2.5 text-white text-sm focus:outline-none focus:border-cyan-500/50 appearance-none">
                    <option value="Land" className="bg-[#12122a]">Land</option>
                    <option value="Property" className="bg-[#12122a]">Property</option>
                    <option value="Vehicle" className="bg-[#12122a]">Vehicle</option>
                    <option value="Gold" className="bg-[#12122a]">Gold</option>
                    <option value="Equipment" className="bg-[#12122a]">Equipment</option>
                    <option value="Furniture" className="bg-[#12122a]">Furniture</option>
                    <option value="Other" className="bg-[#12122a]">Other</option>
                  </select>
                </div>
                <div>
                  <label className="block text-sm text-white/50 mb-1.5">Purchase Value (৳)</label>
                  <input type="number" required min="0" step="0.01" value={form.purchase_value} onChange={e => setForm(f => ({ ...f, purchase_value: e.target.value }))} className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-2.5 text-white text-sm focus:outline-none focus:border-cyan-500/50" />
                </div>
              </div>
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-sm text-white/50 mb-1.5">Current Value (৳)</label>
                  <input type="number" required min="0" step="0.01" value={form.current_value} onChange={e => setForm(f => ({ ...f, current_value: e.target.value }))} className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-2.5 text-white text-sm focus:outline-none focus:border-cyan-500/50" />
                </div>
                <div>
                  <label className="block text-sm text-white/50 mb-1.5">Depreciation (%)</label>
                  <input type="number" min="0" step="0.01" value={form.depreciation} onChange={e => setForm(f => ({ ...f, depreciation: e.target.value }))} className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-2.5 text-white text-sm focus:outline-none focus:border-cyan-500/50" />
                </div>
              </div>
              <div>
                <label className="block text-sm text-white/50 mb-1.5">Purchase Date</label>
                <input type="date" required value={form.purchase_date} onChange={e => setForm(f => ({ ...f, purchase_date: e.target.value }))} className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-2.5 text-white text-sm focus:outline-none focus:border-cyan-500/50" />
              </div>
              <button type="submit" disabled={submitting} className="w-full py-3 rounded-xl bg-gradient-to-r from-cyan-500 to-purple-600 text-white font-semibold text-sm hover:shadow-lg hover:shadow-cyan-500/25 transition-all disabled:opacity-50">
                {submitting ? 'Saving...' : editData ? 'Update Asset' : 'Add Asset'}
              </button>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}

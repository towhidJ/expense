import { useMemo, useState } from 'react';
import { useEntityTable } from '../hooks/useEntityTable';
import { useAccounts } from '../context/AccountContext';
import { useCategories } from '../hooks/useCategories';
import { useAuth } from '../context/AuthContext';
import { useEntity } from '../context/EntityContext';
import { supabase } from '../lib/supabase';
import StatCard from '../components/StatCard';
import { Boxes, Plus, Trash2, AlertTriangle, TrendingUp, ArrowDownCircle, ArrowUpCircle } from 'lucide-react';

const fmt = (n) => `৳${Math.round(Number(n || 0)).toLocaleString()}`;
const today = () => new Date().toISOString().split('T')[0];

export default function Inventory() {
  const { user } = useAuth();
  const { currentEntity } = useEntity();
  const { rows: items, loading, addRow, deleteRow, fetchRows: fetchItems } = useEntityTable('inventory_items');
  const { rows: movements, fetchRows: fetchMovements } = useEntityTable('inventory_movements', { orderBy: 'move_date' });
  const { accounts, fetchAccounts } = useAccounts();
  const { categories } = useCategories();

  const [adding, setAdding] = useState(false);
  const [moving, setMoving] = useState(null); // item being moved
  const initialForm = { name: '', sku: '', unit: 'pcs', cost_price: '', sale_price: '', reorder_level: '' };
  const [form, setForm] = useState(initialForm);
  const [mForm, setMForm] = useState({ movement_type: 'in', quantity: '', unit_price: '', date: today(), notes: '', account_id: '', category_id: '' });

  const lowStock = items.filter(i => Number(i.reorder_level) > 0 && Number(i.quantity) <= Number(i.reorder_level));
  const inventoryValue = items.reduce((s, i) => s + Number(i.quantity) * Number(i.cost_price || 0), 0);

  const handleAdd = async (e) => {
    e.preventDefault();
    try {
      await addRow({
        name: form.name, sku: form.sku || null, unit: form.unit || 'pcs',
        cost_price: parseFloat(form.cost_price) || 0, sale_price: parseFloat(form.sale_price) || 0,
        reorder_level: form.reorder_level ? parseFloat(form.reorder_level) : 0
      });
      setAdding(false);
      setForm(initialForm);
    } catch (err) {
      alert('Error saving item: ' + err.message);
    }
  };

  const openMove = (item, type) => {
    setMoving(item);
    setMForm({ movement_type: type, quantity: '', unit_price: type === 'in' ? String(item.cost_price || '') : String(item.sale_price || ''), date: today(), notes: '', account_id: '', category_id: '' });
  };

  const handleMove = async (e) => {
    e.preventDefault();
    try {
      const { error } = await supabase.rpc('process_inventory_movement', {
        p_user_id: user.id,
        p_entity_id: currentEntity.id,
        p_item_id: moving.id,
        p_movement_type: mForm.movement_type,
        p_quantity: parseFloat(mForm.quantity),
        p_unit_price: parseFloat(mForm.unit_price) || 0,
        p_date: mForm.date,
        p_notes: mForm.notes || null,
        p_account_id: mForm.account_id || null,
        p_category_id: mForm.category_id || null
      });
      if (error) throw error;
      await Promise.all([fetchItems(), fetchMovements(), fetchAccounts()]);
      setMoving(null);
    } catch (err) {
      alert('Error recording movement: ' + err.message);
    }
  };

  const relevantCategories = categories?.filter(c => c.type === (mForm.movement_type === 'in' ? 'expense' : 'income')) || [];

  const recentMovements = useMemo(
    () => [...movements].sort((a, b) => b.move_date.localeCompare(a.move_date)).slice(0, 20),
    [movements]
  );
  const itemName = (id) => items.find(i => i.id === id)?.name || '—';

  if (loading) return <div className="text-white/50 p-6">Loading inventory...</div>;

  return (
    <div className="space-y-6 animate-in">
      <div className="flex justify-between items-center">
        <div>
          <h1 className="text-2xl font-bold text-white">Inventory</h1>
          <p className="text-white/40 text-sm mt-1">Stock levels, cost value and movements.</p>
        </div>
        <button onClick={() => setAdding(true)} className="flex items-center gap-2 bg-cyan-500 hover:bg-cyan-600 text-white px-4 py-2 rounded-xl transition-colors shadow-lg shadow-cyan-500/20">
          <Plus size={18} /> Add Item
        </button>
      </div>

      <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
        <StatCard title="Total Items" value={items.length} icon={Boxes} gradient={["#22d3ee", "#06b6d4"]} iconBg="bg-cyan-500/10" />
        <StatCard title="Inventory Value" value={fmt(inventoryValue)} icon={TrendingUp} gradient={["#34d399", "#10b981"]} iconBg="bg-emerald-500/10" />
        <StatCard title="Low Stock" value={lowStock.length} icon={AlertTriangle} gradient={["#f87171", "#ef4444"]} iconBg="bg-red-500/10" />
      </div>

      {adding && (
        <div className="bg-[#1a1a2e] border border-white/10 rounded-2xl p-6">
          <h2 className="text-lg font-semibold text-white mb-4">New Item</h2>
          <form onSubmit={handleAdd} className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
            <div>
              <label className="block text-sm text-white/60 mb-1">Name</label>
              <input required type="text" value={form.name} onChange={e => setForm({ ...form, name: e.target.value })} className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-cyan-500/50" />
            </div>
            <div>
              <label className="block text-sm text-white/60 mb-1">SKU</label>
              <input type="text" value={form.sku} onChange={e => setForm({ ...form, sku: e.target.value })} className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-cyan-500/50" />
            </div>
            <div>
              <label className="block text-sm text-white/60 mb-1">Unit</label>
              <input type="text" value={form.unit} onChange={e => setForm({ ...form, unit: e.target.value })} placeholder="pcs / kg / box" className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-cyan-500/50" />
            </div>
            <div>
              <label className="block text-sm text-white/60 mb-1">Cost Price</label>
              <input type="number" step="0.01" value={form.cost_price} onChange={e => setForm({ ...form, cost_price: e.target.value })} className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-cyan-500/50" />
            </div>
            <div>
              <label className="block text-sm text-white/60 mb-1">Sale Price</label>
              <input type="number" step="0.01" value={form.sale_price} onChange={e => setForm({ ...form, sale_price: e.target.value })} className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-cyan-500/50" />
            </div>
            <div>
              <label className="block text-sm text-white/60 mb-1">Reorder Level</label>
              <input type="number" step="0.01" value={form.reorder_level} onChange={e => setForm({ ...form, reorder_level: e.target.value })} placeholder="Alert below this" className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-cyan-500/50" />
            </div>
            <div className="lg:col-span-3 flex justify-end gap-3">
              <button type="button" onClick={() => setAdding(false)} className="px-5 py-2.5 rounded-xl text-white/60 hover:text-white hover:bg-white/5 transition-colors">Cancel</button>
              <button type="submit" className="bg-cyan-500 hover:bg-cyan-600 text-white px-6 py-2.5 rounded-xl shadow-lg shadow-cyan-500/20 transition-all font-medium">Save Item</button>
            </div>
          </form>
        </div>
      )}

      {moving && (
        <div className="fixed inset-0 bg-black/60 backdrop-blur-sm z-50 flex items-center justify-center p-4">
          <div className="bg-[#1a1a2e] border border-white/10 rounded-2xl p-6 w-full max-w-md shadow-2xl">
            <h2 className="text-xl font-semibold text-white mb-2">{mForm.movement_type === 'in' ? 'Stock In' : 'Stock Out'}</h2>
            <p className="text-sm text-white/50 mb-6">{moving.name} — current stock: <strong className="text-white">{moving.quantity} {moving.unit}</strong></p>
            <form onSubmit={handleMove} className="space-y-4">
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-sm text-white/60 mb-1">Quantity</label>
                  <input required type="number" step="0.01" value={mForm.quantity} onChange={e => setMForm({ ...mForm, quantity: e.target.value })} className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-cyan-500/50" />
                </div>
                <div>
                  <label className="block text-sm text-white/60 mb-1">Unit Price</label>
                  <input type="number" step="0.01" value={mForm.unit_price} onChange={e => setMForm({ ...mForm, unit_price: e.target.value })} className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-cyan-500/50" />
                </div>
              </div>
              <div>
                <label className="block text-sm text-white/60 mb-1">Date</label>
                <input required type="date" value={mForm.date} onChange={e => setMForm({ ...mForm, date: e.target.value })} className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-cyan-500/50" />
              </div>
              <div>
                <label className="block text-sm text-white/60 mb-1">{mForm.movement_type === 'in' ? 'Pay From Account (optional)' : 'Deposit To Account (optional)'}</label>
                <select value={mForm.account_id} onChange={e => setMForm({ ...mForm, account_id: e.target.value })} className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-cyan-500/50">
                  <option value="">Don't log a transaction</option>
                  {accounts.map(a => <option key={a.id} value={a.id}>{a.name}</option>)}
                </select>
              </div>
              {mForm.account_id && (
                <div>
                  <label className="block text-sm text-white/60 mb-1">Category</label>
                  <select required value={mForm.category_id} onChange={e => setMForm({ ...mForm, category_id: e.target.value })} className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-cyan-500/50">
                    <option value="">Select...</option>
                    {relevantCategories.map(c => <option key={c.id} value={c.id}>{c.icon} {c.name}</option>)}
                  </select>
                </div>
              )}
              <div className="flex justify-end gap-3 mt-6">
                <button type="button" onClick={() => setMoving(null)} className="px-5 py-2.5 rounded-xl text-white/60 hover:text-white hover:bg-white/5 transition-colors">Cancel</button>
                <button type="submit" className="bg-cyan-500 hover:bg-cyan-600 text-white px-6 py-2.5 rounded-xl shadow-lg shadow-cyan-500/20 transition-all font-medium">Confirm</button>
              </div>
            </form>
          </div>
        </div>
      )}

      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
        {items.map(item => {
          const low = Number(item.reorder_level) > 0 && Number(item.quantity) <= Number(item.reorder_level);
          return (
            <div key={item.id} className={`bg-[#1a1a2e] border rounded-2xl p-5 transition-all ${low ? 'border-red-500/30' : 'border-white/10 hover:border-white/20'}`}>
              <div className="flex justify-between items-start mb-3">
                <div>
                  <h3 className="text-white font-medium">{item.name}</h3>
                  <p className="text-white/40 text-xs">{item.sku ? `#${item.sku}` : '—'}</p>
                </div>
                <button onClick={() => { if (confirm(`Delete "${item.name}"?`)) deleteRow(item.id).catch(err => alert(err.message)); }} className="text-white/40 hover:text-red-400 p-1.5 bg-white/5 hover:bg-red-500/10 rounded-lg">
                  <Trash2 size={15} />
                </button>
              </div>
              <div className="space-y-1.5 pt-3 border-t border-white/5 text-sm">
                <div className="flex justify-between">
                  <span className="text-white/40">Stock</span>
                  <span className={low ? 'text-red-400 font-medium' : 'text-white'}>{item.quantity} {item.unit}{low ? ' ⚠️' : ''}</span>
                </div>
                <div className="flex justify-between"><span className="text-white/40">Cost / Sale</span><span className="text-white/70">{fmt(item.cost_price)} / {fmt(item.sale_price)}</span></div>
              </div>
              <div className="flex gap-2 mt-4">
                <button onClick={() => openMove(item, 'in')} className="flex-1 flex items-center justify-center gap-1.5 text-xs bg-emerald-500/15 text-emerald-400 hover:bg-emerald-500/25 px-3 py-2 rounded-lg font-medium">
                  <ArrowDownCircle size={13} /> Stock In
                </button>
                <button onClick={() => openMove(item, 'out')} className="flex-1 flex items-center justify-center gap-1.5 text-xs bg-red-500/15 text-red-400 hover:bg-red-500/25 px-3 py-2 rounded-lg font-medium">
                  <ArrowUpCircle size={13} /> Stock Out
                </button>
              </div>
            </div>
          );
        })}
      </div>

      {items.length === 0 && !adding && (
        <div className="text-center py-12 border border-white/5 rounded-2xl bg-white/[0.02]">
          <Boxes className="mx-auto text-white/20 mb-4" size={48} />
          <h3 className="text-white/60 font-medium">No inventory items yet</h3>
          <p className="text-white/40 text-sm mt-1">Add products to track stock levels and value.</p>
        </div>
      )}

      {recentMovements.length > 0 && (
        <div className="bg-[#1a1a2e] border border-white/10 rounded-2xl overflow-hidden">
          <h2 className="text-white font-semibold px-5 pt-4 pb-2">Recent Movements</h2>
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="bg-white/5 border-b border-white/10">
                  <th className="text-left py-3 px-5 text-white/60 font-medium">Date</th>
                  <th className="text-left py-3 px-5 text-white/60 font-medium">Item</th>
                  <th className="text-left py-3 px-5 text-white/60 font-medium">Type</th>
                  <th className="text-right py-3 px-5 text-white/60 font-medium">Qty</th>
                  <th className="text-right py-3 px-5 text-white/60 font-medium">Value</th>
                </tr>
              </thead>
              <tbody>
                {recentMovements.map(m => (
                  <tr key={m.id} className="border-b border-white/5 hover:bg-white/[0.02]">
                    <td className="py-2.5 px-5 text-white/70">{new Date(m.move_date).toLocaleDateString()}</td>
                    <td className="py-2.5 px-5 text-white">{itemName(m.item_id)}</td>
                    <td className="py-2.5 px-5">
                      <span className={m.movement_type === 'in' ? 'text-emerald-400' : 'text-red-400'}>{m.movement_type === 'in' ? 'IN' : 'OUT'}</span>
                    </td>
                    <td className="py-2.5 px-5 text-right text-white/70">{m.quantity}</td>
                    <td className="py-2.5 px-5 text-right text-white">{fmt(m.quantity * m.unit_price)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}
    </div>
  );
}

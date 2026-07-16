import { useState, useMemo } from 'react';
import { useEntityTable } from '../hooks/useEntityTable';
import { useAccounts } from '../context/AccountContext';
import { useCategories } from '../hooks/useCategories';
import { useAuth } from '../context/AuthContext';
import { useEntity } from '../context/EntityContext';
import { supabase } from '../lib/supabase';
import StatCard from '../components/StatCard';
import { Home, Plus, Phone, Edit2, Trash2, Building2 } from 'lucide-react';

const fmt = (n) => `৳${Math.round(Number(n || 0)).toLocaleString()}`;
const today = () => new Date().toISOString().split('T')[0];
const monthKey = (d) => `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-01`;

// last 12 months, newest first
const last12Months = () => {
  const now = new Date();
  return Array.from({ length: 12 }, (_, i) => {
    const d = new Date(now.getFullYear(), now.getMonth() - i, 1);
    return { key: monthKey(d), label: d.toLocaleDateString('en-US', { month: 'short', year: '2-digit' }) };
  });
};

export default function Rent() {
  const { user } = useAuth();
  const { currentEntity } = useEntity();
  const { rows: units, loading, addRow, updateRow, deleteRow } = useEntityTable('rental_units');
  const { rows: payments, addRow: addPayment, deleteRow: deletePayment, fetchRows: fetchPayments } = useEntityTable('rent_payments', { orderBy: 'rent_month' });
  const { accounts, fetchAccounts } = useAccounts();
  const { categories } = useCategories();
  const incomeCategories = categories?.filter(c => c.type === 'income') || [];

  const [isAdding, setIsAdding] = useState(false);
  const [editing, setEditing] = useState(null);
  const [collecting, setCollecting] = useState(null); // { unit, month }
  const initialForm = { name: '', tenant_name: '', tenant_phone: '', monthly_rent: '', advance_deposit: '', rent_start: '', notes: '', is_active: true };
  const [form, setForm] = useState(initialForm);
  const [collectForm, setCollectForm] = useState({ amount: '', account_id: '', category_id: '', date: today(), log_income: true });

  const months = useMemo(last12Months, []);
  const paymentIndex = useMemo(() => {
    const map = new Map();
    for (const p of payments) map.set(`${p.unit_id}|${p.rent_month}`, p);
    return map;
  }, [payments]);

  const activeUnits = units.filter(u => u.is_active);
  const monthlyIncome = activeUnits.reduce((s, u) => s + Number(u.monthly_rent), 0);
  const thisMonthKey = monthKey(new Date());
  const collectedThisMonth = payments.filter(p => p.rent_month === thisMonthKey).reduce((s, p) => s + Number(p.amount), 0);
  const dueUnits = activeUnits.filter(u => !paymentIndex.has(`${u.id}|${thisMonthKey}`));

  const handleSubmit = async (e) => {
    e.preventDefault();
    const payload = {
      ...form,
      monthly_rent: parseFloat(form.monthly_rent) || 0,
      advance_deposit: form.advance_deposit ? parseFloat(form.advance_deposit) : 0,
      rent_start: form.rent_start || null
    };
    try {
      if (editing) await updateRow(editing.id, payload);
      else await addRow(payload);
      setIsAdding(false); setEditing(null); setForm(initialForm);
    } catch (err) {
      alert('Error saving unit: ' + err.message);
    }
  };

  const handleCollect = async (e) => {
    e.preventDefault();
    try {
      let txId = null;
      if (collectForm.log_income) {
        const { data, error } = await supabase.rpc('process_transaction', {
          p_user_id: user.id,
          p_entity_id: currentEntity.id,
          p_account_id: collectForm.account_id,
          p_category_id: collectForm.category_id,
          p_asset_id: null,
          p_type: 'income',
          p_amount: parseFloat(collectForm.amount),
          p_date: collectForm.date,
          p_description: `Rent — ${collecting.unit.name} (${new Date(collecting.month).toLocaleDateString('en-US', { month: 'long', year: 'numeric' })})`
        });
        if (error) throw error;
        txId = data;
      }
      await addPayment({
        unit_id: collecting.unit.id,
        rent_month: collecting.month,
        amount: parseFloat(collectForm.amount),
        paid_date: collectForm.date,
        transaction_id: txId,
        notes: ''
      });
      if (collectForm.log_income) await fetchAccounts();
      setCollecting(null);
    } catch (err) {
      alert(err.code === '23505' ? 'Rent for this month is already recorded.' : 'Error collecting rent: ' + err.message);
    }
  };

  if (loading) return <div className="text-white/50 p-6">Loading rental units...</div>;

  return (
    <div className="space-y-6 animate-in">
      <div className="flex justify-between items-center">
        <div>
          <h1 className="text-2xl font-bold text-white">Rent Management</h1>
          <p className="text-white/40 text-sm mt-1">Your units, tenants and month-by-month collection.</p>
        </div>
        <button
          onClick={() => { setIsAdding(true); setEditing(null); setForm(initialForm); }}
          className="flex items-center gap-2 bg-teal-500 hover:bg-teal-600 text-white px-4 py-2 rounded-xl transition-colors shadow-lg shadow-teal-500/20"
        >
          <Plus size={18} /> Add Unit
        </button>
      </div>

      <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
        <StatCard title="Active Units" value={activeUnits.length} icon={Building2} gradient={["#2dd4bf", "#14b8a6"]} iconBg="bg-teal-500/10" />
        <StatCard title="Expected / Month" value={fmt(monthlyIncome)} icon={Home} gradient={["#34d399", "#10b981"]} iconBg="bg-emerald-500/10" />
        <StatCard title="Collected This Month" value={`${fmt(collectedThisMonth)}${dueUnits.length ? ` (${dueUnits.length} due)` : ''}`} icon={Home} gradient={dueUnits.length ? ["#f59e0b", "#d97706"] : ["#34d399", "#10b981"]} iconBg="bg-amber-500/10" />
      </div>

      {(isAdding || editing) && (
        <div className="bg-[#1a1a2e] border border-white/10 rounded-2xl p-6">
          <h2 className="text-lg font-semibold text-white mb-4">{editing ? 'Edit Unit' : 'New Rental Unit'}</h2>
          <form onSubmit={handleSubmit} className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
            <div>
              <label className="block text-sm text-white/60 mb-1">Unit Name</label>
              <input required type="text" value={form.name} onChange={e => setForm({ ...form, name: e.target.value })} placeholder="e.g. 2nd Floor Flat-A" className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-teal-500/50" />
            </div>
            <div>
              <label className="block text-sm text-white/60 mb-1">Tenant Name</label>
              <input type="text" value={form.tenant_name || ''} onChange={e => setForm({ ...form, tenant_name: e.target.value })} className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-teal-500/50" />
            </div>
            <div>
              <label className="block text-sm text-white/60 mb-1">Tenant Phone</label>
              <input type="tel" value={form.tenant_phone || ''} onChange={e => setForm({ ...form, tenant_phone: e.target.value })} className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-teal-500/50" />
            </div>
            <div>
              <label className="block text-sm text-white/60 mb-1">Monthly Rent</label>
              <input required type="number" step="0.01" value={form.monthly_rent} onChange={e => setForm({ ...form, monthly_rent: e.target.value })} className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-teal-500/50" />
            </div>
            <div>
              <label className="block text-sm text-white/60 mb-1">Advance / Security Deposit</label>
              <input type="number" step="0.01" value={form.advance_deposit || ''} onChange={e => setForm({ ...form, advance_deposit: e.target.value })} className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-teal-500/50" />
            </div>
            <div>
              <label className="block text-sm text-white/60 mb-1">Rent Since</label>
              <input type="date" value={form.rent_start || ''} onChange={e => setForm({ ...form, rent_start: e.target.value })} className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-teal-500/50" />
            </div>
            <div className="flex items-center gap-2">
              <input type="checkbox" id="unit_active" checked={form.is_active} onChange={e => setForm({ ...form, is_active: e.target.checked })} className="w-4 h-4 rounded accent-teal-500" />
              <label htmlFor="unit_active" className="text-sm text-white/80">Currently rented</label>
            </div>
            <div className="sm:col-span-2 lg:col-span-3 flex justify-end gap-3">
              <button type="button" onClick={() => { setIsAdding(false); setEditing(null); }} className="px-5 py-2.5 rounded-xl text-white/60 hover:text-white hover:bg-white/5 transition-colors">Cancel</button>
              <button type="submit" className="bg-teal-500 hover:bg-teal-600 text-white px-6 py-2.5 rounded-xl shadow-lg shadow-teal-500/20 transition-all font-medium">Save Unit</button>
            </div>
          </form>
        </div>
      )}

      {collecting && (
        <div className="fixed inset-0 bg-black/60 backdrop-blur-sm z-50 flex items-center justify-center p-4">
          <div className="bg-[#1a1a2e] border border-white/10 rounded-2xl p-6 w-full max-w-md shadow-2xl max-h-[90vh] overflow-y-auto">
            <h2 className="text-xl font-semibold text-white mb-2">Collect Rent</h2>
            <p className="text-sm text-white/50 mb-6">
              {collecting.unit.name} — {new Date(collecting.month).toLocaleDateString('en-US', { month: 'long', year: 'numeric' })}
              {collecting.unit.tenant_name && <span> · {collecting.unit.tenant_name}</span>}
            </p>
            <form onSubmit={handleCollect} className="space-y-4">
              <div>
                <label className="block text-sm text-white/60 mb-1">Amount</label>
                <input required type="number" step="0.01" value={collectForm.amount} onChange={e => setCollectForm({ ...collectForm, amount: e.target.value })} className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-teal-500/50" />
              </div>
              <div>
                <label className="block text-sm text-white/60 mb-1">Date Received</label>
                <input required type="date" value={collectForm.date} onChange={e => setCollectForm({ ...collectForm, date: e.target.value })} className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-teal-500/50" />
              </div>
              <div className="flex items-center gap-2">
                <input type="checkbox" id="log_income" checked={collectForm.log_income} onChange={e => setCollectForm({ ...collectForm, log_income: e.target.checked })} className="w-4 h-4 rounded accent-teal-500" />
                <label htmlFor="log_income" className="text-sm text-white/80">Log as income transaction (adds to account balance)</label>
              </div>
              {collectForm.log_income && (
                <>
                  <div>
                    <label className="block text-sm text-white/60 mb-1">Deposit To Account</label>
                    <select required value={collectForm.account_id} onChange={e => setCollectForm({ ...collectForm, account_id: e.target.value })} className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-teal-500/50">
                      <option value="">Select an account...</option>
                      {accounts.map(a => <option key={a.id} value={a.id}>{a.name} ({a.currency}{a.current_balance})</option>)}
                    </select>
                  </div>
                  <div>
                    <label className="block text-sm text-white/60 mb-1">Income Category</label>
                    <select required value={collectForm.category_id} onChange={e => setCollectForm({ ...collectForm, category_id: e.target.value })} className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-teal-500/50">
                      <option value="">Select a category...</option>
                      {incomeCategories.map(c => <option key={c.id} value={c.id}>{c.icon} {c.name}</option>)}
                    </select>
                  </div>
                </>
              )}
              <div className="flex justify-end gap-3 mt-6">
                <button type="button" onClick={() => setCollecting(null)} className="px-5 py-2.5 rounded-xl text-white/60 hover:text-white hover:bg-white/5 transition-colors">Cancel</button>
                <button type="submit" className="bg-teal-500 hover:bg-teal-600 text-white px-6 py-2.5 rounded-xl shadow-lg shadow-teal-500/20 transition-all font-medium">Record Payment</button>
              </div>
            </form>
          </div>
        </div>
      )}

      <div className="space-y-4">
        {units.map(unit => {
          return (
            <div key={unit.id} className={`bg-[#1a1a2e] border rounded-2xl p-5 ${unit.is_active ? 'border-white/10' : 'border-white/5 opacity-60'}`}>
              <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3 mb-4">
                <div className="flex items-center gap-3">
                  <div className="w-11 h-11 rounded-xl bg-teal-500/10 flex items-center justify-center">
                    <Home className="text-teal-400" size={20} />
                  </div>
                  <div>
                    <h3 className="text-white font-medium">{unit.name} <span className="text-white/40 text-sm font-normal">· {fmt(unit.monthly_rent)}/mo</span></h3>
                    <p className="text-white/40 text-xs">
                      {unit.tenant_name || 'No tenant'}
                      {unit.tenant_phone && (
                        <a href={`tel:${unit.tenant_phone}`} className="text-cyan-400/80 hover:text-cyan-400 ml-2"><Phone size={10} className="inline -mt-0.5" /> {unit.tenant_phone}</a>
                      )}
                      {Number(unit.advance_deposit) > 0 && <span className="ml-2">· Advance {fmt(unit.advance_deposit)}</span>}
                    </p>
                  </div>
                </div>
                <div className="flex gap-2">
                  <button onClick={() => { setEditing(unit); setForm({ ...initialForm, ...unit }); setIsAdding(false); }} className="text-white/40 hover:text-cyan-400 p-2 bg-white/5 hover:bg-cyan-500/10 rounded-lg">
                    <Edit2 size={15} />
                  </button>
                  <button onClick={() => { if (confirm(`Delete "${unit.name}" and its payment history?`)) deleteRow(unit.id).then(fetchPayments).catch(err => alert(err.message)); }} className="text-white/40 hover:text-red-400 p-2 bg-white/5 hover:bg-red-500/10 rounded-lg">
                    <Trash2 size={15} />
                  </button>
                </div>
              </div>

              {/* 12-month collection grid */}
              <div className="flex gap-1.5 overflow-x-auto pb-1">
                {[...months].reverse().map(m => {
                  const payment = paymentIndex.get(`${unit.id}|${m.key}`);
                  const isFuture = m.key > thisMonthKey;
                  const beforeStart = unit.rent_start && m.key < monthKey(new Date(unit.rent_start));
                  return (
                    <button
                      key={m.key}
                      disabled={isFuture || beforeStart || !unit.is_active}
                      onClick={() => {
                        if (payment) {
                          if (confirm(`${m.label}: received ${fmt(payment.amount)} on ${new Date(payment.paid_date).toLocaleDateString()}. Remove this record? (Any linked income transaction stays.)`))
                            deletePayment(payment.id).catch(err => alert(err.message));
                        } else {
                          setCollecting({ unit, month: m.key });
                          setCollectForm({ amount: unit.monthly_rent, account_id: '', category_id: '', date: today(), log_income: true });
                        }
                      }}
                      title={payment ? `Paid ${fmt(payment.amount)}` : isFuture ? 'Future month' : 'Click to collect'}
                      className={`shrink-0 w-14 py-2 rounded-lg text-[11px] font-medium border transition-all ${
                        payment
                          ? 'bg-emerald-500/20 text-emerald-400 border-emerald-500/30'
                          : isFuture || beforeStart || !unit.is_active
                            ? 'bg-white/[0.02] text-white/20 border-white/5 cursor-default'
                            : m.key === thisMonthKey
                              ? 'bg-amber-500/15 text-amber-400 border-amber-500/30 hover:bg-amber-500/25'
                              : 'bg-red-500/10 text-red-400/80 border-red-500/20 hover:bg-red-500/20'
                      }`}
                    >
                      {m.label.split(' ')[0]}
                      <div className="text-[9px] opacity-70">{payment ? '✓' : isFuture || beforeStart ? '·' : 'due'}</div>
                    </button>
                  );
                })}
              </div>
            </div>
          );
        })}
      </div>

      {units.length === 0 && !isAdding && (
        <div className="text-center py-12 border border-white/5 rounded-2xl bg-white/[0.02]">
          <Building2 className="mx-auto text-white/20 mb-4" size={48} />
          <h3 className="text-white/60 font-medium">No rental units</h3>
          <p className="text-white/40 text-sm mt-1">Add flats/shops you rent out and track collection month by month.</p>
        </div>
      )}
    </div>
  );
}

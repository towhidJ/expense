import { useState } from 'react';
import { useEntityTable } from '../hooks/useEntityTable';
import StatCard from '../components/StatCard';
import { ShieldCheck, Plus, Edit2, Trash2, CalendarClock, Umbrella } from 'lucide-react';

const fmt = (n) => `৳${Math.round(Number(n || 0)).toLocaleString()}`;
const today = () => new Date().toISOString().split('T')[0];
const TYPE_META = {
  life: { label: 'Life', icon: '❤️' },
  health: { label: 'Health', icon: '🏥' },
  vehicle: { label: 'Vehicle', icon: '🚗' },
  property: { label: 'Property', icon: '🏠' },
  other: { label: 'Other', icon: '📄' }
};
const YEARLY_FACTOR = { monthly: 12, quarterly: 4, yearly: 1 };

export default function Insurance() {
  const { rows: policies, loading, addRow, updateRow, deleteRow } = useEntityTable('insurance_policies');
  const [isAdding, setIsAdding] = useState(false);
  const [editing, setEditing] = useState(null);

  const initialForm = {
    name: '', type: 'life', provider: '', policy_number: '',
    premium_amount: '', premium_frequency: 'yearly', next_premium_date: '',
    coverage_amount: '', maturity_date: '', notes: '', is_active: true
  };
  const [form, setForm] = useState(initialForm);

  const active = policies.filter(p => p.is_active);
  const yearlyPremium = active.reduce((s, p) => s + Number(p.premium_amount || 0) * (YEARLY_FACTOR[p.premium_frequency] || 1), 0);
  const totalCoverage = active.reduce((s, p) => s + Number(p.coverage_amount || 0), 0);
  const dueSoon = active.filter(p => p.next_premium_date && p.next_premium_date <= new Date(Date.now() + 30 * 86400000).toISOString().split('T')[0]);

  const handleSubmit = async (e) => {
    e.preventDefault();
    const payload = {
      ...form,
      premium_amount: parseFloat(form.premium_amount) || 0,
      coverage_amount: form.coverage_amount ? parseFloat(form.coverage_amount) : null,
      next_premium_date: form.next_premium_date || null,
      maturity_date: form.maturity_date || null
    };
    try {
      if (editing) await updateRow(editing.id, payload);
      else await addRow(payload);
      setIsAdding(false); setEditing(null); setForm(initialForm);
    } catch (err) {
      alert('Error saving policy: ' + err.message);
    }
  };

  if (loading) return <div className="text-foreground/50 p-6">Loading insurance policies...</div>;

  return (
    <div className="space-y-6 animate-in">
      <div className="flex justify-between items-center">
        <div>
          <h1 className="text-2xl font-bold text-foreground">Insurance</h1>
          <p className="text-foreground/40 text-sm mt-1">Policies, premiums and coverage in one place.</p>
        </div>
        <button
          onClick={() => { setIsAdding(true); setEditing(null); setForm(initialForm); }}
          className="flex items-center gap-2 bg-indigo-500 hover:bg-indigo-600 text-white px-4 py-2 rounded-xl transition-colors shadow-lg shadow-indigo-500/20"
        >
          <Plus size={18} /> Add Policy
        </button>
      </div>

      <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
        <StatCard title="Active Policies" value={active.length} icon={ShieldCheck} gradient={["#818cf8", "#6366f1"]} iconBg="bg-indigo-500/10" />
        <StatCard title="Yearly Premium" value={fmt(yearlyPremium)} icon={CalendarClock} gradient={["#f87171", "#ef4444"]} iconBg="bg-red-500/10" />
        <StatCard title="Total Coverage" value={fmt(totalCoverage)} icon={Umbrella} gradient={["#34d399", "#10b981"]} iconBg="bg-emerald-500/10" />
      </div>

      {dueSoon.length > 0 && (
        <div className="bg-amber-500/10 border border-amber-500/20 rounded-2xl p-4">
          <p className="text-amber-400 text-sm font-medium">⏰ Premium due within 30 days:</p>
          <ul className="text-foreground/60 text-xs mt-1.5 space-y-0.5">
            {dueSoon.map(p => (
              <li key={p.id}>{p.name} — {fmt(p.premium_amount)} on {new Date(p.next_premium_date).toLocaleDateString()}</li>
            ))}
          </ul>
        </div>
      )}

      {(isAdding || editing) && (
        <div className="bg-card border border-foreground/10 rounded-2xl p-6">
          <h2 className="text-lg font-semibold text-foreground mb-4">{editing ? 'Edit Policy' : 'New Policy'}</h2>
          <form onSubmit={handleSubmit} className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div>
              <label className="block text-sm text-foreground/60 mb-1">Policy Name</label>
              <input required type="text" value={form.name} onChange={e => setForm({ ...form, name: e.target.value })} placeholder="e.g. Jiban Bima" className="w-full bg-muted border border-foreground/10 rounded-xl px-4 py-2.5 text-foreground focus:outline-none focus:border-indigo-500/50" />
            </div>
            <div>
              <label className="block text-sm text-foreground/60 mb-1">Type</label>
              <select value={form.type} onChange={e => setForm({ ...form, type: e.target.value })} className="w-full bg-muted border border-foreground/10 rounded-xl px-4 py-2.5 text-foreground focus:outline-none focus:border-indigo-500/50">
                {Object.entries(TYPE_META).map(([k, v]) => <option key={k} value={k}>{v.icon} {v.label}</option>)}
              </select>
            </div>
            <div>
              <label className="block text-sm text-foreground/60 mb-1">Provider</label>
              <input type="text" value={form.provider} onChange={e => setForm({ ...form, provider: e.target.value })} placeholder="e.g. MetLife" className="w-full bg-muted border border-foreground/10 rounded-xl px-4 py-2.5 text-foreground focus:outline-none focus:border-indigo-500/50" />
            </div>
            <div>
              <label className="block text-sm text-foreground/60 mb-1">Policy Number</label>
              <input type="text" value={form.policy_number} onChange={e => setForm({ ...form, policy_number: e.target.value })} className="w-full bg-muted border border-foreground/10 rounded-xl px-4 py-2.5 text-foreground focus:outline-none focus:border-indigo-500/50" />
            </div>
            <div>
              <label className="block text-sm text-foreground/60 mb-1">Premium Amount</label>
              <input required type="number" step="0.01" value={form.premium_amount} onChange={e => setForm({ ...form, premium_amount: e.target.value })} className="w-full bg-muted border border-foreground/10 rounded-xl px-4 py-2.5 text-foreground focus:outline-none focus:border-indigo-500/50" />
            </div>
            <div>
              <label className="block text-sm text-foreground/60 mb-1">Premium Frequency</label>
              <select value={form.premium_frequency} onChange={e => setForm({ ...form, premium_frequency: e.target.value })} className="w-full bg-muted border border-foreground/10 rounded-xl px-4 py-2.5 text-foreground focus:outline-none focus:border-indigo-500/50">
                <option value="monthly">Monthly</option>
                <option value="quarterly">Quarterly</option>
                <option value="yearly">Yearly</option>
              </select>
            </div>
            <div>
              <label className="block text-sm text-foreground/60 mb-1">Next Premium Date</label>
              <input type="date" value={form.next_premium_date || ''} onChange={e => setForm({ ...form, next_premium_date: e.target.value })} className="w-full bg-muted border border-foreground/10 rounded-xl px-4 py-2.5 text-foreground focus:outline-none focus:border-indigo-500/50" />
            </div>
            <div>
              <label className="block text-sm text-foreground/60 mb-1">Coverage Amount</label>
              <input type="number" step="0.01" value={form.coverage_amount || ''} onChange={e => setForm({ ...form, coverage_amount: e.target.value })} className="w-full bg-muted border border-foreground/10 rounded-xl px-4 py-2.5 text-foreground focus:outline-none focus:border-indigo-500/50" />
            </div>
            <div>
              <label className="block text-sm text-foreground/60 mb-1">Maturity Date (Optional)</label>
              <input type="date" value={form.maturity_date || ''} onChange={e => setForm({ ...form, maturity_date: e.target.value })} className="w-full bg-muted border border-foreground/10 rounded-xl px-4 py-2.5 text-foreground focus:outline-none focus:border-indigo-500/50" />
            </div>
            <div className="flex items-center gap-2 mt-6">
              <input type="checkbox" id="ins_active" checked={form.is_active} onChange={e => setForm({ ...form, is_active: e.target.checked })} className="w-4 h-4 rounded accent-indigo-500" />
              <label htmlFor="ins_active" className="text-sm text-foreground/80">Active policy</label>
            </div>
            <div className="sm:col-span-2">
              <label className="block text-sm text-foreground/60 mb-1">Notes</label>
              <textarea value={form.notes || ''} onChange={e => setForm({ ...form, notes: e.target.value })} rows={2} className="w-full bg-muted border border-foreground/10 rounded-xl px-4 py-2.5 text-foreground focus:outline-none focus:border-indigo-500/50" />
            </div>
            <div className="sm:col-span-2 flex justify-end gap-3">
              <button type="button" onClick={() => { setIsAdding(false); setEditing(null); }} className="px-5 py-2.5 rounded-xl text-foreground/60 hover:text-foreground hover:bg-foreground/5 transition-colors">Cancel</button>
              <button type="submit" className="bg-indigo-500 hover:bg-indigo-600 text-white px-6 py-2.5 rounded-xl shadow-lg shadow-indigo-500/20 transition-all font-medium">Save Policy</button>
            </div>
          </form>
        </div>
      )}

      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
        {policies.map(p => {
          const premiumOverdue = p.is_active && p.next_premium_date && p.next_premium_date < today();
          return (
            <div key={p.id} className={`bg-card border rounded-2xl p-5 transition-all ${p.is_active ? 'border-foreground/10 hover:border-foreground/20' : 'border-foreground/5 opacity-60'}`}>
              <div className="flex justify-between items-start mb-3">
                <div className="flex items-center gap-3">
                  <div className="w-11 h-11 rounded-full bg-muted flex items-center justify-center text-xl">
                    {TYPE_META[p.type]?.icon || '📄'}
                  </div>
                  <div>
                    <h3 className="text-foreground font-medium">{p.name}</h3>
                    <p className="text-foreground/40 text-xs">{p.provider || TYPE_META[p.type]?.label}{p.policy_number ? ` · #${p.policy_number}` : ''}</p>
                  </div>
                </div>
                <div className="flex gap-1.5">
                  <button onClick={() => { setEditing(p); setForm({ ...initialForm, ...p }); setIsAdding(false); }} className="text-white/40 hover:text-cyan-400 p-1.5 bg-foreground/5 hover:bg-cyan-500/10 rounded-lg">
                    <Edit2 size={15} />
                  </button>
                  <button onClick={() => { if (confirm(`Delete policy "${p.name}"?`)) deleteRow(p.id).catch(err => alert(err.message)); }} className="text-white/40 hover:text-red-400 p-1.5 bg-foreground/5 hover:bg-red-500/10 rounded-lg">
                    <Trash2 size={15} />
                  </button>
                </div>
              </div>
              <div className="space-y-1.5 pt-3 border-t border-foreground/5 text-sm">
                <div className="flex justify-between"><span className="text-foreground/40">Premium</span><span className="text-foreground">{fmt(p.premium_amount)} <span className="text-foreground/40 text-xs">/{p.premium_frequency}</span></span></div>
                {p.coverage_amount != null && <div className="flex justify-between"><span className="text-foreground/40">Coverage</span><span className="text-emerald-400">{fmt(p.coverage_amount)}</span></div>}
                {p.next_premium_date && (
                  <div className="flex justify-between">
                    <span className="text-foreground/40">Next premium</span>
                    <span className={premiumOverdue ? 'text-red-400 font-medium' : 'text-foreground/70'}>
                      {new Date(p.next_premium_date).toLocaleDateString()}{premiumOverdue ? ' ⚠️' : ''}
                    </span>
                  </div>
                )}
                {p.maturity_date && <div className="flex justify-between"><span className="text-foreground/40">Maturity</span><span className="text-foreground/70">{new Date(p.maturity_date).toLocaleDateString()}</span></div>}
              </div>
            </div>
          );
        })}
      </div>

      {policies.length === 0 && !isAdding && (
        <div className="text-center py-12 border border-foreground/5 rounded-2xl bg-white/[0.02]">
          <ShieldCheck className="mx-auto text-foreground/20 mb-4" size={48} />
          <h3 className="text-foreground/60 font-medium">No insurance policies</h3>
          <p className="text-foreground/40 text-sm mt-1">Track premiums, coverage and maturity dates so nothing lapses.</p>
        </div>
      )}
    </div>
  );
}

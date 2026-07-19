import { useMemo, useState } from 'react';
import { Link } from 'react-router';
import { useEntityTable } from '../hooks/useEntityTable';
import { useAssets } from '../hooks/useAssets';
import { useAccounts } from '../context/AccountContext';
import { useCategories } from '../hooks/useCategories';
import { useAuth } from '../context/AuthContext';
import { useEntity } from '../context/EntityContext';
import { supabase } from '../lib/supabase';
import StatCard from '../components/StatCard';
import { Bike, Plus, Trash2, Fuel, Wrench, Gauge, Wallet, Link2 } from 'lucide-react';

const fmt = (n) => `৳${Math.round(Number(n || 0)).toLocaleString()}`;
const today = () => new Date().toISOString().split('T')[0];
const LOG_META = {
  fuel: { label: 'Fuel', icon: Fuel, color: 'text-amber-400' },
  service: { label: 'Maintenance', icon: Wrench, color: 'text-cyan-400' },
  other: { label: 'Other', icon: Gauge, color: 'text-foreground/50' }
};

export default function Vehicle() {
  const { user } = useAuth();
  const { currentEntity } = useEntity();
  const { rows: vehicles, loading, addRow: addVehicle, deleteRow: deleteVehicle } = useEntityTable('vehicles');
  const { rows: logs, addRow: addLog, deleteRow: deleteLog, fetchRows: fetchLogs } = useEntityTable('vehicle_logs', { orderBy: 'log_date' });
  const { assets } = useAssets();
  const { accounts, fetchAccounts } = useAccounts();
  const { categories } = useCategories();
  const expenseCategories = categories?.filter(c => c.type === 'expense') || [];

  const [activeVehicle, setActiveVehicle] = useState(null);
  const [addingVehicle, setAddingVehicle] = useState(false);
  const [addingLog, setAddingLog] = useState(false);
  const initialVForm = { name: '', vehicle_type: '', reg_number: '', purchase_date: '', notes: '', asset_id: '' };
  const [vForm, setVForm] = useState(initialVForm);
  const [lForm, setLForm] = useState({ log_type: 'fuel', log_date: today(), odometer: '', amount: '', liters: '', notes: '', account_id: '', category_id: '' });

  // Vehicle-type assets not yet linked to a vehicle log entry here — offered
  // so a bike/car already tracked in Assets doesn't get double-entered.
  const linkableAssets = useMemo(
    () => assets.filter(a => a.type === 'Vehicle' && !vehicles.some(v => v.asset_id === a.id)),
    [assets, vehicles]
  );

  const pickAsset = (assetId) => {
    const asset = assets.find(a => a.id === assetId);
    setVForm(f => ({
      ...f,
      asset_id: assetId,
      name: asset ? asset.name : f.name,
      purchase_date: asset?.purchase_date || f.purchase_date
    }));
  };

  const shownVehicle = activeVehicle || vehicles[0]?.id;
  const vehicleLogs = useMemo(
    () => logs.filter(l => l.vehicle_id === shownVehicle).sort((a, b) => b.log_date.localeCompare(a.log_date)),
    [logs, shownVehicle]
  );

  const yearStart = `${new Date().getFullYear()}-01-01`;
  const yearLogs = useMemo(() => vehicleLogs.filter(l => l.log_date >= yearStart), [vehicleLogs, yearStart]);
  const yearlySpend = yearLogs.reduce((s, l) => s + Number(l.amount), 0);
  const maintenanceSpend = yearLogs.filter(l => l.log_type === 'service').reduce((s, l) => s + Number(l.amount), 0);

  const mileage = useMemo(() => {
    const fuelLogs = [...vehicleLogs].filter(l => l.log_type === 'fuel' && l.odometer != null).sort((a, b) => a.odometer - b.odometer);
    if (fuelLogs.length < 2) return null;
    let totalKm = 0, totalLiters = 0;
    for (let i = 1; i < fuelLogs.length; i++) {
      totalKm += fuelLogs[i].odometer - fuelLogs[i - 1].odometer;
      totalLiters += Number(fuelLogs[i].liters || 0);
    }
    return totalLiters > 0 ? totalKm / totalLiters : null;
  }, [vehicleLogs]);

  const handleAddVehicle = async (e) => {
    e.preventDefault();
    try {
      const v = await addVehicle({ ...vForm, purchase_date: vForm.purchase_date || null, asset_id: vForm.asset_id || null });
      setActiveVehicle(v.id);
      setAddingVehicle(false);
      setVForm(initialVForm);
    } catch (err) {
      alert('Error saving vehicle: ' + err.message);
    }
  };

  const handleAddLog = async (e) => {
    e.preventDefault();
    try {
      const meta = LOG_META[lForm.log_type];
      const { data: txId, error } = await supabase.rpc('process_transaction', {
        p_user_id: user.id,
        p_entity_id: currentEntity.id,
        p_account_id: lForm.account_id,
        p_category_id: lForm.category_id,
        p_asset_id: null,
        p_type: 'expense',
        p_amount: Number(lForm.amount),
        p_date: lForm.log_date,
        p_description: `${vehicles.find(v => v.id === shownVehicle)?.name} — ${meta.label}`
      });
      if (error) throw error;
      await addLog({
        vehicle_id: shownVehicle,
        log_type: lForm.log_type,
        log_date: lForm.log_date,
        odometer: lForm.odometer ? parseFloat(lForm.odometer) : null,
        amount: parseFloat(lForm.amount),
        liters: lForm.log_type === 'fuel' && lForm.liters ? parseFloat(lForm.liters) : null,
        notes: lForm.notes || null,
        transaction_id: txId
      });
      await Promise.all([fetchAccounts(), fetchLogs()]);
      setAddingLog(false);
      setLForm({ log_type: 'fuel', log_date: today(), odometer: '', amount: '', liters: '', notes: '', account_id: '', category_id: '' });
    } catch (err) {
      alert('Error saving log: ' + err.message);
    }
  };

  if (loading) return <div className="text-foreground/50 p-6">Loading vehicles...</div>;

  return (
    <div className="space-y-6 animate-in">
      <div className="flex justify-between items-center">
        <div>
          <h1 className="text-2xl font-bold text-foreground">Vehicle Expense</h1>
          <p className="text-foreground/40 text-sm mt-1">Fuel, maintenance and running costs per vehicle.</p>
        </div>
        <button onClick={() => setAddingVehicle(true)} className="flex items-center gap-2 bg-cyan-500 hover:bg-cyan-600 text-white px-4 py-2 rounded-xl transition-colors shadow-lg shadow-cyan-500/20">
          <Plus size={18} /> Add Vehicle
        </button>
      </div>

      {vehicles.length === 0 && !addingVehicle ? (
        <div className="text-center py-12 border border-foreground/5 rounded-2xl bg-white/[0.02]">
          <Bike className="mx-auto text-foreground/20 mb-4" size={48} />
          <h3 className="text-foreground/60 font-medium">No vehicles yet</h3>
          <p className="text-foreground/40 text-sm mt-1">Add a bike or car to start tracking fuel and maintenance costs.</p>
        </div>
      ) : (
        <>
          <div className="flex gap-2 flex-wrap">
            {vehicles.map(v => (
              <button key={v.id} onClick={() => setActiveVehicle(v.id)} className={`flex items-center gap-1.5 px-3.5 py-2 rounded-xl text-sm font-medium transition-all border ${shownVehicle === v.id ? 'bg-cyan-500/20 text-cyan-400 border-cyan-500/40' : 'bg-foreground/5 text-white/40 border-foreground/10 hover:bg-foreground/10'}`}>
                🏍️ {v.name} {v.asset_id && <Link2 size={12} className="opacity-60" title="Linked to Assets" />}
              </button>
            ))}
          </div>

          {shownVehicle && (
            <>
              <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
                <StatCard title="This Year's Spend" value={fmt(yearlySpend)} icon={Wallet} gradient={["#f87171", "#ef4444"]} iconBg="bg-red-500/10" />
                <StatCard title="Maintenance (Year)" value={fmt(maintenanceSpend)} icon={Wrench} gradient={["#22d3ee", "#06b6d4"]} iconBg="bg-cyan-500/10" />
                <StatCard title="Mileage" value={mileage ? `${mileage.toFixed(1)} km/L` : '—'} icon={Gauge} gradient={["#34d399", "#10b981"]} iconBg="bg-emerald-500/10" />
                <StatCard title="Total Logs" value={vehicleLogs.length} icon={Fuel} gradient={["#f59e0b", "#d97706"]} iconBg="bg-amber-500/10" />
              </div>

              <div className="flex justify-end">
                <button onClick={() => setAddingLog(true)} className="flex items-center gap-2 bg-foreground/5 hover:bg-foreground/10 text-foreground px-4 py-2 rounded-xl transition-colors text-sm">
                  <Plus size={16} /> Add Log
                </button>
              </div>
            </>
          )}
        </>
      )}

      {addingVehicle && (
        <div className="bg-card border border-foreground/10 rounded-2xl p-6">
          <h2 className="text-lg font-semibold text-foreground mb-4">New Vehicle</h2>
          {linkableAssets.length > 0 && (
            <div className="mb-4 bg-cyan-500/[0.07] border border-cyan-500/20 rounded-xl p-4">
              <label className="flex items-center gap-1.5 text-sm text-cyan-400 mb-1.5"><Link2 size={14} /> Already in Assets?</label>
              <select value={vForm.asset_id} onChange={e => pickAsset(e.target.value)} className="w-full bg-muted border border-foreground/10 rounded-xl px-4 py-2.5 text-foreground focus:outline-none focus:border-cyan-500/50">
                <option value="">Don't link — enter details manually</option>
                {linkableAssets.map(a => <option key={a.id} value={a.id}>{a.name}</option>)}
              </select>
              <p className="text-xs text-foreground/40 mt-1.5">Linking fills in the name from <Link to="/assets" className="text-cyan-400 hover:underline">Assets</Link> so it's not entered twice.</p>
            </div>
          )}
          <form onSubmit={handleAddVehicle} className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div>
              <label className="block text-sm text-foreground/60 mb-1">Name</label>
              <input required type="text" value={vForm.name} onChange={e => setVForm({ ...vForm, name: e.target.value })} placeholder="e.g. Yamaha FZ" className="w-full bg-muted border border-foreground/10 rounded-xl px-4 py-2.5 text-foreground focus:outline-none focus:border-cyan-500/50" />
            </div>
            <div>
              <label className="block text-sm text-foreground/60 mb-1">Type</label>
              <input type="text" value={vForm.vehicle_type} onChange={e => setVForm({ ...vForm, vehicle_type: e.target.value })} placeholder="Bike / Car" className="w-full bg-muted border border-foreground/10 rounded-xl px-4 py-2.5 text-foreground focus:outline-none focus:border-cyan-500/50" />
            </div>
            <div>
              <label className="block text-sm text-foreground/60 mb-1">Registration Number</label>
              <input type="text" value={vForm.reg_number} onChange={e => setVForm({ ...vForm, reg_number: e.target.value })} className="w-full bg-muted border border-foreground/10 rounded-xl px-4 py-2.5 text-foreground focus:outline-none focus:border-cyan-500/50" />
            </div>
            <div>
              <label className="block text-sm text-foreground/60 mb-1">Purchase Date</label>
              <input type="date" value={vForm.purchase_date} onChange={e => setVForm({ ...vForm, purchase_date: e.target.value })} className="w-full bg-muted border border-foreground/10 rounded-xl px-4 py-2.5 text-foreground focus:outline-none focus:border-cyan-500/50" />
            </div>
            <div className="sm:col-span-2 flex justify-end gap-3">
              <button type="button" onClick={() => setAddingVehicle(false)} className="px-5 py-2.5 rounded-xl text-foreground/60 hover:text-foreground hover:bg-foreground/5 transition-colors">Cancel</button>
              <button type="submit" className="bg-cyan-500 hover:bg-cyan-600 text-white px-6 py-2.5 rounded-xl shadow-lg shadow-cyan-500/20 transition-all font-medium">Save Vehicle</button>
            </div>
          </form>
        </div>
      )}

      {addingLog && shownVehicle && (
        <div className="bg-card border border-foreground/10 rounded-2xl p-6">
          <h2 className="text-lg font-semibold text-foreground mb-4">New Log</h2>
          <form onSubmit={handleAddLog} className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
            <div>
              <label className="block text-sm text-foreground/60 mb-1">Type</label>
              <select value={lForm.log_type} onChange={e => setLForm({ ...lForm, log_type: e.target.value })} className="w-full bg-muted border border-foreground/10 rounded-xl px-4 py-2.5 text-foreground focus:outline-none focus:border-cyan-500/50">
                {Object.entries(LOG_META).map(([k, v]) => <option key={k} value={k}>{v.label}</option>)}
              </select>
            </div>
            <div>
              <label className="block text-sm text-foreground/60 mb-1">Date</label>
              <input required type="date" value={lForm.log_date} onChange={e => setLForm({ ...lForm, log_date: e.target.value })} className="w-full bg-muted border border-foreground/10 rounded-xl px-4 py-2.5 text-foreground focus:outline-none focus:border-cyan-500/50" />
            </div>
            <div>
              <label className="block text-sm text-foreground/60 mb-1">Odometer (km)</label>
              <input type="number" step="0.1" value={lForm.odometer} onChange={e => setLForm({ ...lForm, odometer: e.target.value })} className="w-full bg-muted border border-foreground/10 rounded-xl px-4 py-2.5 text-foreground focus:outline-none focus:border-cyan-500/50" />
            </div>
            {lForm.log_type === 'fuel' && (
              <div>
                <label className="block text-sm text-foreground/60 mb-1">Liters</label>
                <input type="number" step="0.01" value={lForm.liters} onChange={e => setLForm({ ...lForm, liters: e.target.value })} className="w-full bg-muted border border-foreground/10 rounded-xl px-4 py-2.5 text-foreground focus:outline-none focus:border-cyan-500/50" />
              </div>
            )}
            <div>
              <label className="block text-sm text-foreground/60 mb-1">Amount</label>
              <input required type="number" step="0.01" value={lForm.amount} onChange={e => setLForm({ ...lForm, amount: e.target.value })} className="w-full bg-muted border border-foreground/10 rounded-xl px-4 py-2.5 text-foreground focus:outline-none focus:border-cyan-500/50" />
            </div>
            <div>
              <label className="block text-sm text-foreground/60 mb-1">Pay From Account</label>
              <select required value={lForm.account_id} onChange={e => setLForm({ ...lForm, account_id: e.target.value })} className="w-full bg-muted border border-foreground/10 rounded-xl px-4 py-2.5 text-foreground focus:outline-none focus:border-cyan-500/50">
                <option value="">Select...</option>
                {accounts.map(a => <option key={a.id} value={a.id}>{a.name}</option>)}
              </select>
            </div>
            <div>
              <label className="block text-sm text-foreground/60 mb-1">Category</label>
              <select required value={lForm.category_id} onChange={e => setLForm({ ...lForm, category_id: e.target.value })} className="w-full bg-muted border border-foreground/10 rounded-xl px-4 py-2.5 text-foreground focus:outline-none focus:border-cyan-500/50">
                <option value="">Select...</option>
                {expenseCategories.map(c => <option key={c.id} value={c.id}>{c.icon} {c.name}</option>)}
              </select>
            </div>
            <div className="sm:col-span-2 lg:col-span-3">
              <label className="block text-sm text-foreground/60 mb-1">Notes</label>
              <input type="text" value={lForm.notes} onChange={e => setLForm({ ...lForm, notes: e.target.value })} className="w-full bg-muted border border-foreground/10 rounded-xl px-4 py-2.5 text-foreground focus:outline-none focus:border-cyan-500/50" />
            </div>
            <div className="sm:col-span-2 lg:col-span-3 flex justify-end gap-3">
              <button type="button" onClick={() => setAddingLog(false)} className="px-5 py-2.5 rounded-xl text-foreground/60 hover:text-foreground hover:bg-foreground/5 transition-colors">Cancel</button>
              <button type="submit" className="bg-cyan-500 hover:bg-cyan-600 text-white px-6 py-2.5 rounded-xl shadow-lg shadow-cyan-500/20 transition-all font-medium">Save Log</button>
            </div>
          </form>
        </div>
      )}

      {shownVehicle && (
        <div className="bg-card border border-foreground/10 rounded-2xl overflow-hidden">
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="bg-foreground/5 border-b border-foreground/10">
                  <th className="text-left py-3 px-5 text-foreground/60 font-medium">Date</th>
                  <th className="text-left py-3 px-5 text-foreground/60 font-medium">Type</th>
                  <th className="text-right py-3 px-5 text-foreground/60 font-medium">Odometer</th>
                  <th className="text-right py-3 px-5 text-foreground/60 font-medium">Amount</th>
                  <th className="text-right py-3 px-5 text-foreground/60 font-medium">Actions</th>
                </tr>
              </thead>
              <tbody>
                {vehicleLogs.map(l => {
                  const meta = LOG_META[l.log_type];
                  const Icon = meta.icon;
                  return (
                    <tr key={l.id} className="border-b border-foreground/5 hover:bg-white/[0.02]">
                      <td className="py-3 px-5 text-foreground/70">{new Date(l.log_date).toLocaleDateString()}</td>
                      <td className="py-3 px-5">
                        <span className={`flex items-center gap-1.5 ${meta.color}`}><Icon size={14} /> {meta.label}{l.liters ? ` (${l.liters}L)` : ''}</span>
                      </td>
                      <td className="py-3 px-5 text-right text-foreground/60">{l.odometer ?? '—'}</td>
                      <td className="py-3 px-5 text-right text-foreground font-medium">{fmt(l.amount)}</td>
                      <td className="py-3 px-5 text-right">
                        <button onClick={() => { if (confirm('Delete this log? (Linked transaction stays.)')) deleteLog(l.id).catch(err => alert(err.message)); }} className="text-white/30 hover:text-red-400 p-1.5 rounded-lg hover:bg-red-500/10">
                          <Trash2 size={14} />
                        </button>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
          {vehicleLogs.length === 0 && (
            <div className="text-center py-10">
              <Fuel className="mx-auto text-foreground/20 mb-3" size={40} />
              <p className="text-foreground/40 text-sm">No logs yet — add the first fuel or maintenance entry.</p>
            </div>
          )}
          <div className="px-5 py-3 border-t border-foreground/5 flex justify-end">
            <button onClick={() => { if (confirm('Delete this vehicle and all its logs?')) deleteVehicle(shownVehicle).then(() => setActiveVehicle(null)).catch(err => alert(err.message)); }} className="text-xs text-red-400/70 hover:text-red-400">
              Delete vehicle
            </button>
          </div>
        </div>
      )}
    </div>
  );
}

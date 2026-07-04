import { useState } from 'react';
import { useInvestments } from '../hooks/useInvestments';
import { TrendingUp, Plus, Edit2, Trash2, LineChart, Bitcoin, Building2, Briefcase } from 'lucide-react';

export default function Investments() {
  const { investments, loading, addInvestment, updateInvestment, deleteInvestment } = useInvestments();
  const [isAdding, setIsAdding] = useState(false);
  const [editingInvestment, setEditingInvestment] = useState(null);

  const initialForm = {
    name: '',
    type: 'stocks',
    invested_amount: 0,
    current_value: 0,
    purchase_date: new Date().toISOString().split('T')[0],
    notes: ''
  };
  const [form, setForm] = useState(initialForm);

  const calculateROI = (invested, current) => {
    if (!invested || invested === 0) return 0;
    return (((current - invested) / invested) * 100).toFixed(2);
  };

  const calculateProfitLoss = (invested, current) => {
    return (current - invested).toFixed(2);
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    try {
      const roi = calculateROI(form.invested_amount, form.current_value);
      const profit_loss = calculateProfitLoss(form.invested_amount, form.current_value);

      const payload = {
        ...form,
        roi,
        profit_loss
      };

      if (editingInvestment) {
        await updateInvestment(editingInvestment.id, payload);
      } else {
        await addInvestment(payload);
      }
      setIsAdding(false);
      setEditingInvestment(null);
      setForm(initialForm);
    } catch (err) {
      console.error(err);
      alert('Error saving investment');
    }
  };

  const getIcon = (type) => {
    switch(type) {
      case 'stocks': return <LineChart className="text-blue-400" size={24} />;
      case 'crypto': return <Bitcoin className="text-orange-400" size={24} />;
      case 'mutual_funds': return <Briefcase className="text-purple-400" size={24} />;
      case 'fdr': case 'dps': return <Building2 className="text-emerald-400" size={24} />;
      default: return <TrendingUp className="text-white/50" size={24} />;
    }
  };

  if (loading) return <div className="text-white/50 p-6">Loading portfolio...</div>;

  const totalInvested = investments.reduce((sum, inv) => sum + Number(inv.invested_amount), 0);
  const totalCurrent = investments.reduce((sum, inv) => sum + Number(inv.current_value), 0);
  const totalROI = totalInvested > 0 ? (((totalCurrent - totalInvested) / totalInvested) * 100).toFixed(2) : 0;
  const isPositive = totalCurrent >= totalInvested;

  return (
    <div className="space-y-6 animate-in">
      <div className="flex justify-between items-center">
        <div>
          <h1 className="text-2xl font-bold text-white">Investment Portfolio</h1>
          <p className="text-white/40 text-sm mt-1">Track your stocks, crypto, and savings.</p>
        </div>
        <button
          onClick={() => { setIsAdding(true); setEditingInvestment(null); setForm(initialForm); }}
          className="flex items-center gap-2 bg-blue-500 hover:bg-blue-600 text-white px-4 py-2 rounded-xl transition-colors shadow-lg shadow-blue-500/20"
        >
          <Plus size={18} /> Add Investment
        </button>
      </div>

      <div className="grid grid-cols-1 sm:grid-cols-3 gap-4 mb-8">
        <div className="bg-[#1a1a2e] border border-white/10 rounded-2xl p-5">
          <p className="text-white/40 text-sm">Total Invested</p>
          <p className="text-2xl font-semibold text-white mt-1">৳{totalInvested.toLocaleString()}</p>
        </div>
        <div className="bg-[#1a1a2e] border border-white/10 rounded-2xl p-5">
          <p className="text-white/40 text-sm">Current Value</p>
          <p className="text-2xl font-semibold text-white mt-1">৳{totalCurrent.toLocaleString()}</p>
        </div>
        <div className={`bg-[#1a1a2e] border rounded-2xl p-5 ${isPositive ? 'border-emerald-500/30' : 'border-red-500/30'}`}>
          <p className="text-white/40 text-sm">Overall ROI</p>
          <p className={`text-2xl font-semibold mt-1 ${isPositive ? 'text-emerald-400' : 'text-red-400'}`}>
            {isPositive ? '+' : ''}{totalROI}%
          </p>
        </div>
      </div>

      {(isAdding || editingInvestment) && (
        <div className="bg-[#1a1a2e] border border-white/10 rounded-2xl p-6">
          <h2 className="text-lg font-semibold text-white mb-4">{editingInvestment ? 'Edit Investment' : 'New Investment'}</h2>
          <form onSubmit={handleSubmit} className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div>
              <label className="block text-sm text-white/60 mb-1">Asset Name / Ticker</label>
              <input required type="text" value={form.name} onChange={e => setForm({...form, name: e.target.value})} className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-blue-500/50" placeholder="e.g. AAPL, BTC, DBBL FDR" />
            </div>
            <div>
              <label className="block text-sm text-white/60 mb-1">Type</label>
              <select value={form.type} onChange={e => setForm({...form, type: e.target.value})} className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-blue-500/50">
                <option value="stocks">Stocks</option>
                <option value="crypto">Cryptocurrency</option>
                <option value="mutual_funds">Mutual Funds</option>
                <option value="fdr">Fixed Deposit (FDR)</option>
                <option value="dps">Savings Scheme (DPS)</option>
              </select>
            </div>
            <div>
              <label className="block text-sm text-white/60 mb-1">Invested Amount (Cost Basis)</label>
              <input required type="number" step="0.01" value={form.invested_amount} onChange={e => setForm({...form, invested_amount: parseFloat(e.target.value)})} className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-blue-500/50" />
            </div>
            <div>
              <label className="block text-sm text-white/60 mb-1">Current Market Value</label>
              <input required type="number" step="0.01" value={form.current_value} onChange={e => setForm({...form, current_value: parseFloat(e.target.value)})} className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-blue-500/50" />
            </div>
            <div>
              <label className="block text-sm text-white/60 mb-1">Purchase Date</label>
              <input type="date" value={form.purchase_date} onChange={e => setForm({...form, purchase_date: e.target.value})} className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-blue-500/50" />
            </div>
            <div>
              <label className="block text-sm text-white/60 mb-1">Notes</label>
              <input type="text" value={form.notes} onChange={e => setForm({...form, notes: e.target.value})} className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-blue-500/50" placeholder="Optional notes..." />
            </div>
            <div className="sm:col-span-2 flex justify-end gap-3 mt-2">
              <button type="button" onClick={() => {setIsAdding(false); setEditingInvestment(null);}} className="px-5 py-2.5 rounded-xl text-white/60 hover:text-white hover:bg-white/5 transition-colors">Cancel</button>
              <button type="submit" className="bg-blue-500 hover:bg-blue-600 text-white px-6 py-2.5 rounded-xl shadow-lg shadow-blue-500/20 transition-all font-medium">Save Investment</button>
            </div>
          </form>
        </div>
      )}

      <div className="bg-[#1a1a2e] border border-white/10 rounded-2xl overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="bg-white/5 border-b border-white/10">
                <th className="text-left py-4 px-5 text-white/60 font-medium">Asset</th>
                <th className="text-left py-4 px-5 text-white/60 font-medium">Date</th>
                <th className="text-right py-4 px-5 text-white/60 font-medium">Invested</th>
                <th className="text-right py-4 px-5 text-white/60 font-medium">Current Value</th>
                <th className="text-right py-4 px-5 text-white/60 font-medium">Profit/Loss</th>
                <th className="text-right py-4 px-5 text-white/60 font-medium">ROI</th>
                <th className="text-right py-4 px-5 text-white/60 font-medium">Actions</th>
              </tr>
            </thead>
            <tbody>
              {investments.length === 0 ? (
                <tr>
                  <td colSpan="7" className="text-center py-12 text-white/40">
                    <TrendingUp className="mx-auto mb-3 opacity-20" size={32} />
                    No investments found. Start building your portfolio!
                  </td>
                </tr>
              ) : investments.map(inv => {
                const isProfitable = inv.profit_loss >= 0;
                return (
                  <tr key={inv.id} className="border-b border-white/5 hover:bg-white/[0.02] transition-colors">
                    <td className="py-4 px-5">
                      <div className="flex items-center gap-3">
                        <div className="w-8 h-8 rounded-full bg-[#12122a] flex items-center justify-center">
                          {getIcon(inv.type)}
                        </div>
                        <div>
                          <p className="text-white font-medium">{inv.name}</p>
                          <p className="text-white/40 text-xs capitalize">{inv.type.replace('_', ' ')}</p>
                          {inv.notes && <p className="text-white/30 text-xs mt-0.5 truncate max-w-[150px]">{inv.notes}</p>}
                        </div>
                      </div>
                    </td>
                    <td className="py-4 px-5 text-white/50 text-xs">
                      {inv.purchase_date ? new Date(inv.purchase_date).toLocaleDateString() : '—'}
                    </td>
                    <td className="py-4 px-5 text-right text-white/70">৳{Number(inv.invested_amount).toLocaleString()}</td>
                    <td className="py-4 px-5 text-right font-medium text-white">৳{Number(inv.current_value).toLocaleString()}</td>
                    <td className={`py-4 px-5 text-right font-medium ${isProfitable ? 'text-emerald-400' : 'text-red-400'}`}>
                      {isProfitable ? '+' : ''}৳{Number(inv.profit_loss).toLocaleString()}
                    </td>
                    <td className={`py-4 px-5 text-right font-medium ${isProfitable ? 'text-emerald-400' : 'text-red-400'}`}>
                      {isProfitable ? '+' : ''}{inv.roi}%
                    </td>
                    <td className="py-4 px-5 text-right">
                      <div className="flex justify-end gap-2">
                        <button onClick={() => { setEditingInvestment(inv); setForm({...inv, purchase_date: inv.purchase_date || '', notes: inv.notes || ''}); setIsAdding(false); }} className="text-white/40 hover:text-cyan-400 p-1.5 rounded-lg hover:bg-cyan-500/10">
                          <Edit2 size={16} />
                        </button>
                        <button onClick={() => { if (confirm(`Delete investment "${inv.name}"?`)) deleteInvestment(inv.id).catch(err => alert("Cannot delete: " + err.message)); }} className="text-white/40 hover:text-red-400 p-1.5 rounded-lg hover:bg-red-500/10">
                          <Trash2 size={16} />
                        </button>
                      </div>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}

import { useState, useMemo } from 'react';
import { Link } from 'react-router';
import { useEntityTable } from '../hooks/useEntityTable';
import { useRecurring } from '../hooks/useRecurring';
import { useAccounts } from '../context/AccountContext';
import { useCategories } from '../hooks/useCategories';
import { useAuth } from '../context/AuthContext';
import { useEntity } from '../context/EntityContext';
import { supabase } from '../lib/supabase';
import ChartCard from '../components/ChartCard';
import { Zap, Plus, Trash2, Repeat } from 'lucide-react';
import { BarChart, Bar, XAxis, YAxis, Tooltip, CartesianGrid, ResponsiveContainer } from 'recharts';

const fmt = (n) => `৳${Math.round(Number(n || 0)).toLocaleString()}`;
const today = () => new Date().toISOString().split('T')[0];
const thisMonth = () => today().slice(0, 7);
const TYPES = {
  electricity: { label: 'Electricity', icon: '⚡', unit: 'kWh' },
  gas: { label: 'Gas', icon: '🔥', unit: 'unit' },
  water: { label: 'Water', icon: '💧', unit: 'unit' },
  internet: { label: 'Internet', icon: '🌐', unit: '' },
  phone: { label: 'Phone', icon: '📱', unit: '' },
  tv: { label: 'TV', icon: '📺', unit: '' },
  other: { label: 'Other', icon: '📋', unit: '' }
};

export default function Utility() {
  const { user } = useAuth();
  const { currentEntity } = useEntity();
  const { rows: bills, loading, addRow, updateRow, deleteRow, fetchRows } = useEntityTable('utility_bills', { orderBy: 'bill_month' });
  const { recurring } = useRecurring();
  const { accounts, fetchAccounts } = useAccounts();
  const { categories } = useCategories();
  const expenseCategories = categories?.filter(c => c.type === 'expense') || [];

  const [activeType, setActiveType] = useState('electricity');
  const [isAdding, setIsAdding] = useState(false);
  const [payingBill, setPayingBill] = useState(null);
  const [payForm, setPayForm] = useState({ account_id: '', category_id: '', date: today() });
  const initialForm = { month: thisMonth(), units: '', amount: '', due_date: '', notes: '' };
  const [form, setForm] = useState(initialForm);

  const typeBills = useMemo(
    () => bills.filter(b => b.type === activeType).sort((a, b) => b.bill_month.localeCompare(a.bill_month)),
    [bills, activeType]
  );

  const chartData = useMemo(
    () => [...typeBills].reverse().slice(-12).map(b => ({
      name: new Date(b.bill_month).toLocaleDateString('en-US', { month: 'short', year: '2-digit' }),
      amount: Number(b.amount),
      units: Number(b.units || 0)
    })),
    [typeBills]
  );

  const unpaidTotal = bills.filter(b => !b.transaction_id).reduce((s, b) => s + Number(b.amount), 0);

  const linkedRecurring = useMemo(
    () => recurring.find(r => r.is_active && r.type === 'expense' && r.utility_type === activeType),
    [recurring, activeType]
  );

  const handleAdd = async (e) => {
    e.preventDefault();
    try {
      await addRow({
        type: activeType,
        bill_month: `${form.month}-01`,
        units: form.units ? parseFloat(form.units) : null,
        amount: parseFloat(form.amount),
        due_date: form.due_date || null,
        notes: form.notes || ''
      });
      setIsAdding(false);
      setForm(initialForm);
    } catch (err) {
      alert(err.code === '23505' ? 'A bill for this month already exists.' : 'Error saving bill: ' + err.message);
    }
  };

  const handlePay = async (e) => {
    e.preventDefault();
    try {
      const meta = TYPES[payingBill.type];
      const { data: txId, error } = await supabase.rpc('process_transaction', {
        p_user_id: user.id,
        p_entity_id: currentEntity.id,
        p_account_id: payForm.account_id,
        p_category_id: payForm.category_id,
        p_asset_id: null,
        p_type: 'expense',
        p_amount: Number(payingBill.amount),
        p_date: payForm.date,
        p_description: `${meta.label} bill — ${new Date(payingBill.bill_month).toLocaleDateString('en-US', { month: 'long', year: 'numeric' })}`
      });
      if (error) throw error;
      await updateRow(payingBill.id, { transaction_id: txId });
      await Promise.all([fetchAccounts(), fetchRows()]);
      setPayingBill(null);
    } catch (err) {
      alert('Error paying bill: ' + err.message);
    }
  };

  if (loading) return <div className="text-white/50 p-6">Loading utility bills...</div>;

  return (
    <div className="space-y-6 animate-in">
      <div className="flex justify-between items-center">
        <div>
          <h1 className="text-2xl font-bold text-white">Utility Bills</h1>
          <p className="text-white/40 text-sm mt-1">
            Month-wise bills with unit tracking.
            {unpaidTotal > 0 && <span className="text-amber-400"> Unpaid: {fmt(unpaidTotal)}</span>}
          </p>
        </div>
        <button
          onClick={() => { setIsAdding(true); setForm(initialForm); }}
          className="flex items-center gap-2 bg-amber-500 hover:bg-amber-600 text-white px-4 py-2 rounded-xl transition-colors shadow-lg shadow-amber-500/20"
        >
          <Plus size={18} /> Add Bill
        </button>
      </div>

      <div className="flex gap-2 flex-wrap">
        {Object.entries(TYPES).map(([k, v]) => {
          const count = bills.filter(b => b.type === k).length;
          return (
            <button
              key={k}
              onClick={() => setActiveType(k)}
              className={`px-3.5 py-2 rounded-xl text-sm font-medium transition-all border ${
                activeType === k
                  ? 'bg-amber-500/20 text-amber-400 border-amber-500/40'
                  : 'bg-white/5 text-white/40 border-white/10 hover:bg-white/10'
              }`}
            >
              {v.icon} {v.label}{count > 0 && <span className="ml-1.5 text-xs opacity-60">({count})</span>}
            </button>
          );
        })}
      </div>

      {linkedRecurring ? (
        <div className="flex items-center gap-3 bg-emerald-500/[0.07] border border-emerald-500/20 rounded-2xl px-4 py-3 text-sm">
          <Repeat size={16} className="text-emerald-400 shrink-0" />
          <p className="text-white/70">
            Auto-pay on: <strong className="text-white">{linkedRecurring.title}</strong> ({fmt(linkedRecurring.amount)}/{linkedRecurring.frequency.replace('ly', '')})
            {' '}posts the payment and marks each month's bill PAID here. Next run: {new Date(linkedRecurring.next_run_date).toLocaleDateString()}.
          </p>
          <Link to="/recurring" className="ml-auto shrink-0 text-emerald-400 hover:underline text-xs font-medium">Manage</Link>
        </div>
      ) : (
        <div className="flex items-center gap-3 bg-white/[0.03] border border-white/10 rounded-2xl px-4 py-3 text-sm">
          <Repeat size={16} className="text-white/30 shrink-0" />
          <p className="text-white/40">
            Fixed monthly {TYPES[activeType].label.toLowerCase()} bill? Add a recurring expense and set its "Utility Bill" type — bills will then appear here as PAID automatically.
          </p>
          <Link to="/recurring" className="ml-auto shrink-0 text-cyan-400 hover:underline text-xs font-medium">Set up</Link>
        </div>
      )}

      {isAdding && (
        <div className="bg-[#1a1a2e] border border-white/10 rounded-2xl p-6">
          <h2 className="text-lg font-semibold text-white mb-4">New {TYPES[activeType].label} Bill</h2>
          <form onSubmit={handleAdd} className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
            <div>
              <label className="block text-sm text-white/60 mb-1">Bill Month</label>
              <input required type="month" value={form.month} onChange={e => setForm({ ...form, month: e.target.value })} className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-amber-500/50" />
            </div>
            <div>
              <label className="block text-sm text-white/60 mb-1">Units {TYPES[activeType].unit && `(${TYPES[activeType].unit})`}</label>
              <input type="number" step="0.01" value={form.units} onChange={e => setForm({ ...form, units: e.target.value })} placeholder="Optional" className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-amber-500/50" />
            </div>
            <div>
              <label className="block text-sm text-white/60 mb-1">Amount</label>
              <input required type="number" step="0.01" value={form.amount} onChange={e => setForm({ ...form, amount: e.target.value })} className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-amber-500/50" />
            </div>
            <div>
              <label className="block text-sm text-white/60 mb-1">Due Date</label>
              <input type="date" value={form.due_date} onChange={e => setForm({ ...form, due_date: e.target.value })} className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-amber-500/50" />
            </div>
            <div className="sm:col-span-2 lg:col-span-4 flex justify-end gap-3">
              <button type="button" onClick={() => setIsAdding(false)} className="px-5 py-2.5 rounded-xl text-white/60 hover:text-white hover:bg-white/5 transition-colors">Cancel</button>
              <button type="submit" className="bg-amber-500 hover:bg-amber-600 text-white px-6 py-2.5 rounded-xl shadow-lg shadow-amber-500/20 transition-all font-medium">Save Bill</button>
            </div>
          </form>
        </div>
      )}

      {payingBill && (
        <div className="fixed inset-0 bg-black/60 backdrop-blur-sm z-50 flex items-center justify-center p-4">
          <div className="bg-[#1a1a2e] border border-white/10 rounded-2xl p-6 w-full max-w-md shadow-2xl">
            <h2 className="text-xl font-semibold text-white mb-2">Pay Bill</h2>
            <p className="text-sm text-white/50 mb-6">
              {TYPES[payingBill.type].icon} {TYPES[payingBill.type].label} — {new Date(payingBill.bill_month).toLocaleDateString('en-US', { month: 'long', year: 'numeric' })} · <strong className="text-white">{fmt(payingBill.amount)}</strong>
            </p>
            <form onSubmit={handlePay} className="space-y-4">
              <div>
                <label className="block text-sm text-white/60 mb-1">Pay From Account</label>
                <select required value={payForm.account_id} onChange={e => setPayForm({ ...payForm, account_id: e.target.value })} className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-amber-500/50">
                  <option value="">Select an account...</option>
                  {accounts.map(a => <option key={a.id} value={a.id}>{a.name} ({a.currency}{a.current_balance})</option>)}
                </select>
              </div>
              <div>
                <label className="block text-sm text-white/60 mb-1">Expense Category</label>
                <select required value={payForm.category_id} onChange={e => setPayForm({ ...payForm, category_id: e.target.value })} className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-amber-500/50">
                  <option value="">Select a category...</option>
                  {expenseCategories.map(c => <option key={c.id} value={c.id}>{c.icon} {c.name}</option>)}
                </select>
              </div>
              <div>
                <label className="block text-sm text-white/60 mb-1">Payment Date</label>
                <input required type="date" value={payForm.date} onChange={e => setPayForm({ ...payForm, date: e.target.value })} className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-amber-500/50" />
              </div>
              <div className="flex justify-end gap-3 mt-6">
                <button type="button" onClick={() => setPayingBill(null)} className="px-5 py-2.5 rounded-xl text-white/60 hover:text-white hover:bg-white/5 transition-colors">Cancel</button>
                <button type="submit" className="bg-emerald-500 hover:bg-emerald-600 text-white px-6 py-2.5 rounded-xl shadow-lg shadow-emerald-500/20 transition-all font-medium">Confirm Payment</button>
              </div>
            </form>
          </div>
        </div>
      )}

      {chartData.length > 1 && (
        <ChartCard title={`${TYPES[activeType].label} — Monthly Comparison`} subtitle="Spot the months that spiked">
          <ResponsiveContainer width="100%" height={240}>
            <BarChart data={chartData}>
              <CartesianGrid strokeDasharray="3 3" stroke="#ffffff08" />
              <XAxis dataKey="name" tick={{ fill: '#ffffff40', fontSize: 12 }} axisLine={false} tickLine={false} />
              <YAxis tick={{ fill: '#ffffff40', fontSize: 12 }} axisLine={false} tickLine={false} />
              <Tooltip
                contentStyle={{ background: '#12122a', border: '1px solid #ffffff1a', borderRadius: 12 }}
                labelStyle={{ color: '#ffffff80' }}
                formatter={(v, name) => [name === 'amount' ? fmt(v) : v, name === 'amount' ? 'Bill' : 'Units']}
              />
              <Bar dataKey="amount" fill="#f59e0b" radius={[6, 6, 0, 0]} name="amount" />
            </BarChart>
          </ResponsiveContainer>
        </ChartCard>
      )}

      <div className="bg-[#1a1a2e] border border-white/10 rounded-2xl overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="bg-white/5 border-b border-white/10">
                <th className="text-left py-3 px-5 text-white/60 font-medium">Month</th>
                <th className="text-right py-3 px-5 text-white/60 font-medium">Units</th>
                <th className="text-right py-3 px-5 text-white/60 font-medium">Amount</th>
                <th className="text-left py-3 px-5 text-white/60 font-medium">Status</th>
                <th className="text-right py-3 px-5 text-white/60 font-medium">Actions</th>
              </tr>
            </thead>
            <tbody>
              {typeBills.map(bill => {
                const paid = !!bill.transaction_id;
                const overdue = !paid && bill.due_date && bill.due_date < today();
                return (
                  <tr key={bill.id} className="border-b border-white/5 hover:bg-white/[0.02] transition-colors">
                    <td className="py-3 px-5 text-white font-medium">{new Date(bill.bill_month).toLocaleDateString('en-US', { month: 'long', year: 'numeric' })}</td>
                    <td className="py-3 px-5 text-right text-white/60">{bill.units ?? '—'}</td>
                    <td className="py-3 px-5 text-right text-white font-medium">{fmt(bill.amount)}</td>
                    <td className="py-3 px-5">
                      {paid
                        ? <span className="px-2 py-0.5 rounded text-[10px] font-bold bg-emerald-500/20 text-emerald-400">PAID</span>
                        : overdue
                          ? <span className="px-2 py-0.5 rounded text-[10px] font-bold bg-red-500/20 text-red-400">OVERDUE</span>
                          : <span className="px-2 py-0.5 rounded text-[10px] font-bold bg-amber-500/20 text-amber-400">DUE{bill.due_date ? ` ${new Date(bill.due_date).toLocaleDateString()}` : ''}</span>}
                    </td>
                    <td className="py-3 px-5 text-right">
                      <div className="flex justify-end gap-2">
                        {!paid && (
                          <button
                            onClick={() => { setPayingBill(bill); setPayForm({ account_id: '', category_id: '', date: today() }); }}
                            className="text-xs bg-emerald-500 hover:bg-emerald-600 text-white px-3 py-1.5 rounded-lg font-medium"
                          >
                            Pay
                          </button>
                        )}
                        <button
                          onClick={() => { if (confirm('Delete this bill record? (Any linked payment transaction stays.)')) deleteRow(bill.id).catch(err => alert(err.message)); }}
                          className="text-white/30 hover:text-red-400 p-1.5 rounded-lg hover:bg-red-500/10"
                        >
                          <Trash2 size={14} />
                        </button>
                      </div>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
        {typeBills.length === 0 && (
          <div className="text-center py-10">
            <Zap className="mx-auto text-white/20 mb-3" size={40} />
            <p className="text-white/40 text-sm">No {TYPES[activeType].label.toLowerCase()} bills yet — add the first one.</p>
          </div>
        )}
      </div>
    </div>
  );
}

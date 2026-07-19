import { useState } from 'react';
import { useNavigate } from 'react-router';
import { useTransactions } from '../hooks/useTransactions';
import { useCategories } from '../hooks/useCategories';
import { useAttachments } from '../hooks/useAttachments';
import TransactionForm from '../components/TransactionForm';
import TransactionList from '../components/TransactionList';
import VoucherModal from '../components/VoucherModal';
import { useEntity } from '../context/EntityContext';
import { Plus, Search, CalendarDays, Upload } from 'lucide-react';

const MONTHS = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];

export default function Transactions() {
  const navigate = useNavigate();
  const { transactions, loading, addTransaction, updateTransaction, deleteTransaction } = useTransactions();
  const { categories } = useCategories();
  const { uploadMany } = useAttachments();
  const { currentEntity } = useEntity();
  const [showForm, setShowForm] = useState(false);
  const [editData, setEditData] = useState(null);
  const [voucherTx, setVoucherTx] = useState(null);
  const [search, setSearch] = useState('');
  const [typeFilter, setTypeFilter] = useState('all');
  const [categoryFilter, setCategoryFilter] = useState('all');

  const now = new Date();
  const [filterMode, setFilterMode] = useState('month'); // 'month' | 'all'
  const [month, setMonth] = useState(now.getMonth() + 1);
  const [year, setYear] = useState(now.getFullYear());

  const filtered = transactions.filter(t => {
    // Date filter
    if (filterMode === 'month') {
      const d = new Date(t.date);
      if (d.getMonth() + 1 !== month || d.getFullYear() !== year) return false;
    }
    // Type filter
    if (typeFilter !== 'all' && t.type !== typeFilter) return false;
    // Category filter
    if (categoryFilter !== 'all' && t.category_id !== categoryFilter) return false;
    // Search filter
    if (search) {
      const s = search.toLowerCase();
      return (t.description?.toLowerCase().includes(s) || t.categories?.name?.toLowerCase().includes(s));
    }
    return true;
  });

  const handleSubmit = async (data, editId, files = []) => {
    if (editId) {
      await updateTransaction(editId, data);
      if (files.length) await uploadMany(files, { transactionId: editId });
    } else {
      const newId = await addTransaction(data);
      if (newId && files.length) await uploadMany(files, { transactionId: newId });
    }
  };

  const handleEdit = (t) => {
    setEditData(t);
    setShowForm(true);
  };

  const handleDelete = async (id) => {
    if (confirm('Delete this transaction?')) {
      await deleteTransaction(id);
    }
  };

  const totalIncome = filtered.filter(t => t.type === 'income').reduce((s, t) => s + t.amount, 0);
  const totalExpense = filtered.filter(t => t.type === 'expense').reduce((s, t) => s + t.amount, 0);

  return (
    <div className="space-y-6 animate-in">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-foreground">Transactions</h1>
          <p className="text-foreground/40 text-sm mt-1">Manage your income and expenses</p>
        </div>
        <div className="flex items-center gap-3">
          <button
            onClick={() => navigate('/import')}
            className="flex items-center gap-2 px-4 py-2.5 rounded-xl bg-foreground/5 border border-foreground/10 text-foreground/70 hover:text-foreground text-sm font-medium transition-all"
          >
            <Upload className="w-4 h-4" /> Import CSV
          </button>
          <button
            onClick={() => { setEditData(null); setShowForm(true); }}
            className="flex items-center gap-2 px-5 py-2.5 rounded-xl bg-gradient-to-r from-cyan-500 to-purple-600 text-white text-sm font-semibold hover:shadow-lg hover:shadow-cyan-500/25 transition-all"
          >
            <Plus className="w-4 h-4" /> Add Transaction
          </button>
        </div>
      </div>

      {/* Summary */}
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
        <div className="rounded-xl bg-foreground/5 border border-foreground/10 p-4">
          <p className="text-xs text-foreground/40">Total Income</p>
          <p className="text-xl font-bold text-emerald-400 mt-1">৳{totalIncome.toLocaleString()}</p>
        </div>
        <div className="rounded-xl bg-foreground/5 border border-foreground/10 p-4">
          <p className="text-xs text-foreground/40">Total Expense</p>
          <p className="text-xl font-bold text-red-400 mt-1">৳{totalExpense.toLocaleString()}</p>
        </div>
        <div className="rounded-xl bg-foreground/5 border border-foreground/10 p-4">
          <p className="text-xs text-foreground/40">Net</p>
          <p className={`text-xl font-bold mt-1 ${totalIncome - totalExpense >= 0 ? 'text-cyan-400' : 'text-red-400'}`}>
            ৳{(totalIncome - totalExpense).toLocaleString()}
          </p>
        </div>
      </div>

      {/* Filters Row */}
      <div className="flex flex-wrap gap-3">
        {/* Search */}
        <div className="relative flex-1 min-w-[200px]">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-foreground/30" />
          <input
            type="text"
            value={search}
            onChange={e => setSearch(e.target.value)}
            placeholder="Search transactions..."
            className="w-full bg-foreground/5 border border-foreground/10 rounded-xl pl-10 pr-4 py-2.5 text-foreground text-sm focus:outline-none focus:border-cyan-500/50 transition-colors placeholder:text-foreground/20"
          />
        </div>

        {/* Type Filter */}
        <select
          value={typeFilter}
          onChange={e => setTypeFilter(e.target.value)}
          className="bg-foreground/5 border border-foreground/10 rounded-xl px-4 py-2.5 text-foreground text-sm focus:outline-none focus:border-cyan-500/50 appearance-none cursor-pointer min-w-[130px]"
        >
          <option value="all" className="bg-muted">All Types</option>
          <option value="income" className="bg-muted">💰 Income</option>
          <option value="expense" className="bg-muted">💸 Expense</option>
        </select>

        {/* Category Filter */}
        <select
          value={categoryFilter}
          onChange={e => setCategoryFilter(e.target.value)}
          className="bg-foreground/5 border border-foreground/10 rounded-xl px-4 py-2.5 text-foreground text-sm focus:outline-none focus:border-cyan-500/50 appearance-none cursor-pointer min-w-[160px]"
        >
          <option value="all" className="bg-muted">All Categories</option>
          {categories.map(c => (
            <option key={c.id} value={c.id} className="bg-muted">{c.icon} {c.name}</option>
          ))}
        </select>
      </div>

      {/* Date Filter Row */}
      <div className="flex flex-wrap items-center gap-3 p-3 bg-white/[0.03] border border-foreground/8 rounded-xl">
        <CalendarDays className="w-4 h-4 text-foreground/40 shrink-0" />
        
        {/* Mode Toggle */}
        <div className="flex gap-1 bg-foreground/5 p-1 rounded-lg">
          <button
            onClick={() => setFilterMode('month')}
            className={`px-3 py-1 rounded-md text-xs font-medium transition-all ${filterMode === 'month' ? 'bg-cyan-500/20 text-cyan-400' : 'text-white/40 hover:text-white'}`}
          >
            Monthly
          </button>
          <button
            onClick={() => setFilterMode('all')}
            className={`px-3 py-1 rounded-md text-xs font-medium transition-all ${filterMode === 'all' ? 'bg-cyan-500/20 text-cyan-400' : 'text-white/40 hover:text-white'}`}
          >
            All Time
          </button>
        </div>

        {filterMode === 'month' && (
          <>
            <select
              value={month}
              onChange={e => setMonth(parseInt(e.target.value))}
              className="bg-foreground/5 border border-foreground/10 rounded-lg px-3 py-1.5 text-foreground text-xs focus:outline-none focus:border-cyan-500/50 appearance-none cursor-pointer"
            >
              {MONTHS.map((m, i) => (
                <option key={i} value={i + 1} className="bg-muted">{m}</option>
              ))}
            </select>
            <select
              value={year}
              onChange={e => setYear(parseInt(e.target.value))}
              className="bg-foreground/5 border border-foreground/10 rounded-lg px-3 py-1.5 text-foreground text-xs focus:outline-none focus:border-cyan-500/50 appearance-none cursor-pointer"
            >
              {[2024, 2025, 2026, 2027].map(y => (
                <option key={y} value={y} className="bg-muted">{y}</option>
              ))}
            </select>
            <span className="text-foreground/30 text-xs ml-1">
              Showing: {MONTHS[month - 1]} {year} ({filtered.length} transactions)
            </span>
          </>
        )}
        {filterMode === 'all' && (
          <span className="text-foreground/30 text-xs">Showing all {filtered.length} transactions</span>
        )}
      </div>

      {/* Transaction List */}
      <div className="rounded-2xl bg-foreground/5 backdrop-blur-xl border border-foreground/10 p-6">
        {loading ? (
          <div className="flex justify-center py-12">
            <div className="w-8 h-8 border-3 border-cyan-500/30 border-t-cyan-500 rounded-full animate-spin" />
          </div>
        ) : (
          <TransactionList transactions={filtered} onEdit={handleEdit} onDelete={handleDelete} onVoucher={setVoucherTx} />
        )}
      </div>

      <TransactionForm
        isOpen={showForm}
        onClose={() => { setShowForm(false); setEditData(null); }}
        onSubmit={handleSubmit}
        categories={categories}
        editData={editData}
      />

      {voucherTx && (
        <VoucherModal
          transaction={voucherTx}
          entityName={currentEntity?.name ? `${currentEntity.name} — TakaKhata` : 'TakaKhata'}
          onClose={() => setVoucherTx(null)}
        />
      )}
    </div>
  );
}

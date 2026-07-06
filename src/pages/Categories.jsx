import { useState, useMemo } from 'react';
import { useCategories } from '../hooks/useCategories';
import { useTransactions } from '../hooks/useTransactions';
import { Plus, Edit2, Trash2, Check, X, ShieldAlert } from 'lucide-react';

const COLORS = [
  '#ef4444', '#f97316', '#f59e0b', '#84cc16', '#10b981', '#14b8a6',
  '#06b6d4', '#0ea5e9', '#3b82f6', '#6366f1', '#8b5cf6', '#a855f7',
  '#d946ef', '#ec4899', '#f43f5e', '#64748b'
];

const ICONS = ['💰', '💻', '📈', '🎁', '💵', '🍔', '🚗', '🛍️', '📄', '🎮', '🏥', '📚', '🏠', '💸', '✈️', '🐶', '☕', '🛠️', '📱', '🏋️', '⚡', '💧', '💳', '🛒', '🎓'];

export default function Categories() {
  const { categories, loading, addCategory, updateCategory, deleteCategory } = useCategories();
  const { transactions } = useTransactions();

  const now = new Date();
  const currentMonth = now.getMonth();
  const currentYear = now.getFullYear();

  // Count transactions per category for this month
  const txCountByCategory = useMemo(() => {
    const map = {};
    transactions.forEach(t => {
      const d = new Date(t.date);
      if (d.getMonth() === currentMonth && d.getFullYear() === currentYear && t.category_id) {
        map[t.category_id] = (map[t.category_id] || 0) + 1;
      }
    });
    return map;
  }, [transactions, currentMonth, currentYear]);
  const [activeTab, setActiveTab] = useState('expense');
  const [isAdding, setIsAdding] = useState(false);
  const [editingCategory, setEditingCategory] = useState(null);
  const [form, setForm] = useState({ name: '', type: 'expense', icon: '💸', color: '#ef4444' });

  const filteredCategories = categories.filter(c => c.type === activeTab);

  const handleSubmit = async (e) => {
    e.preventDefault();
    try {
      if (editingCategory) {
        await updateCategory(editingCategory.id, form);
      } else {
        await addCategory(form);
      }
      setIsAdding(false);
      setEditingCategory(null);
      setForm({ name: '', type: activeTab, icon: '💸', color: '#ef4444' });
    } catch (err) {
      console.error(err);
      alert('Error saving category');
    }
  };

  const handleDelete = async (id) => {
    if (confirm('Are you sure you want to delete this category? Any transactions using this category might lose their label.')) {
      try {
        await deleteCategory(id);
      } catch (err) {
        console.error(err);
        alert('Cannot delete category. It might be in use.');
      }
    }
  };

  if (loading) return <div className="text-white/50 p-6">Loading categories...</div>;

  return (
    <div className="space-y-6 animate-in relative">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-white">Categories</h1>
          <p className="text-white/40 text-sm mt-1">Manage custom income and expense categories.</p>
        </div>
        <button
          onClick={() => { setIsAdding(true); setEditingCategory(null); setForm({ name: '', type: activeTab, icon: '💸', color: '#ef4444' }); }}
          className="flex items-center gap-2 px-5 py-2.5 rounded-xl bg-gradient-to-r from-cyan-500 to-purple-600 text-white text-sm font-semibold hover:shadow-lg hover:shadow-cyan-500/25 transition-all"
        >
          <Plus className="w-4 h-4" /> Add Category
        </button>
      </div>

      <div className="flex bg-[#12122a] border border-white/5 p-1 rounded-xl w-fit">
        {['expense', 'income'].map(type => (
          <button
            key={type}
            onClick={() => { setActiveTab(type); if(isAdding || editingCategory) setForm({...form, type}); }}
            className={`px-6 py-2 rounded-lg text-sm font-medium capitalize transition-all ${
              activeTab === type
                ? type === 'expense' ? 'bg-red-500/20 text-red-400' : 'bg-emerald-500/20 text-emerald-400'
                : 'text-white/40 hover:text-white hover:bg-white/5'
            }`}
          >
            {type}s
          </button>
        ))}
      </div>

      {(isAdding || editingCategory) && (
        <div className="bg-[#1a1a2e] border border-white/10 rounded-2xl p-6 mb-6">
          <div className="flex justify-between items-center mb-4">
            <h2 className="text-lg font-semibold text-white">{editingCategory ? 'Edit Category' : 'New Category'}</h2>
            <button onClick={() => { setIsAdding(false); setEditingCategory(null); }} className="text-white/40 hover:text-white p-1">
              <X size={20} />
            </button>
          </div>
          
          <form onSubmit={handleSubmit} className="space-y-6">
            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              <div>
                <label className="block text-sm text-white/60 mb-2">Category Name</label>
                <input required type="text" value={form.name} onChange={e => setForm({...form, name: e.target.value})} className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-cyan-500/50" placeholder="e.g. Office Supplies" />
              </div>

              <div>
                <label className="block text-sm text-white/60 mb-2">Preview</label>
                <div className="flex items-center gap-3 p-3 rounded-xl border border-white/5 bg-white/[0.02] w-full max-w-[250px]">
                  <div className="w-10 h-10 rounded-full flex items-center justify-center text-xl shrink-0" style={{ backgroundColor: `${form.color}20`, color: form.color }}>
                    {form.icon}
                  </div>
                  <span className="text-white font-medium truncate">{form.name || 'Category Name'}</span>
                </div>
              </div>
            </div>

            <div>
              <label className="block text-sm text-white/60 mb-2">Select Icon</label>
              <div className="grid grid-cols-6 sm:grid-cols-10 md:grid-cols-12 lg:grid-cols-16 gap-2 max-h-40 overflow-y-auto p-2 bg-[#12122a] rounded-xl border border-white/5">
                {ICONS.map(icon => (
                  <button key={icon} type="button" onClick={() => setForm({...form, icon})} className={`text-xl p-2 rounded-lg transition-all ${form.icon === icon ? 'bg-white/20 scale-110' : 'hover:bg-white/10 opacity-70 hover:opacity-100'}`}>
                    {icon}
                  </button>
                ))}
              </div>
            </div>

            <div>
              <label className="block text-sm text-white/60 mb-2">Select Color</label>
              <div className="flex flex-wrap gap-3 p-2 bg-[#12122a] rounded-xl border border-white/5">
                {COLORS.map(color => (
                  <button key={color} type="button" onClick={() => setForm({...form, color})} className="w-8 h-8 rounded-full transition-transform hover:scale-110 flex items-center justify-center shadow-inner" style={{ backgroundColor: color }}>
                    {form.color === color && <Check size={16} className="text-white drop-shadow-md" />}
                  </button>
                ))}
              </div>
            </div>

            <div className="flex justify-end pt-4 border-t border-white/10">
              <button type="submit" className="bg-cyan-500 hover:bg-cyan-600 text-white px-6 py-2.5 rounded-xl shadow-lg shadow-cyan-500/20 transition-all font-medium">Save Category</button>
            </div>
          </form>
        </div>
      )}

      <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4">
        {filteredCategories.map(category => {
          const txCount = txCountByCategory[category.id] || 0;
          return (
            <div key={category.id} className="bg-[#1a1a2e] border border-white/10 rounded-2xl p-5 hover:border-white/20 transition-all group flex items-center justify-between">
              <div className="flex items-center gap-3">
                <div className="w-12 h-12 rounded-xl flex items-center justify-center text-2xl shadow-inner shrink-0 relative" style={{ backgroundColor: `${category.color}15`, color: category.color, border: `1px solid ${category.color}30` }}>
                  {category.icon}
                  {txCount > 0 && (
                    <span className="absolute -top-1 -right-1 w-5 h-5 rounded-full bg-cyan-500 text-white text-[10px] font-bold flex items-center justify-center shadow-lg">
                      {txCount > 99 ? '99+' : txCount}
                    </span>
                  )}
                </div>
                <div className="overflow-hidden">
                  <h3 className="text-white font-medium truncate" title={category.name}>{category.name}</h3>
                  <p className="text-xs text-white/40">
                    {category.is_default ? 'System Default' : 'Custom'}
                    {txCount > 0 && <span className="text-cyan-400 ml-1">· {txCount} this month</span>}
                  </p>
                </div>
              </div>
              
              <div className="flex flex-col gap-2 opacity-100 sm:opacity-0 sm:group-hover:opacity-100 transition-opacity">
                <button onClick={() => { setEditingCategory(category); setForm(category); setIsAdding(false); }} className="text-white/40 hover:text-cyan-400 p-1.5 bg-white/5 hover:bg-cyan-500/10 rounded-lg shrink-0">
                  <Edit2 size={16} />
                </button>
                {!category.is_default && (
                  <button onClick={() => handleDelete(category.id)} className="text-white/40 hover:text-red-400 p-1.5 bg-white/5 hover:bg-red-500/10 rounded-lg shrink-0">
                    <Trash2 size={16} />
                  </button>
                )}
              </div>
            </div>
          );
        })}
      </div>

      {filteredCategories.length === 0 && !isAdding && (
        <div className="text-center py-12 border border-white/5 rounded-2xl bg-white/[0.02]">
          <ShieldAlert className="mx-auto text-white/20 mb-4" size={48} />
          <h3 className="text-white/60 font-medium">No categories found</h3>
          <p className="text-white/40 text-sm mt-1">Add some categories to get started.</p>
        </div>
      )}
    </div>
  );
}

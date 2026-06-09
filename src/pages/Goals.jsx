import { useState } from 'react';
import { useGoals } from '../hooks/useGoals';
import { Target, Plus, TrendingUp, Edit2, Trash2 } from 'lucide-react';

export default function Goals() {
  const { goals, loading, addGoal, updateGoal, deleteGoal } = useGoals();
  const [isAdding, setIsAdding] = useState(false);
  const [editingGoal, setEditingGoal] = useState(null);

  const initialForm = {
    title: '',
    target_amount: 0,
    saved_amount: 0,
    target_date: new Date().toISOString().split('T')[0],
    notes: ''
  };
  const [form, setForm] = useState(initialForm);

  const handleSubmit = async (e) => {
    e.preventDefault();
    try {
      if (editingGoal) {
        await updateGoal(editingGoal.id, form);
      } else {
        await addGoal(form);
      }
      setIsAdding(false);
      setEditingGoal(null);
      setForm(initialForm);
    } catch (err) {
      console.error(err);
      alert('Error saving goal');
    }
  };

  if (loading) return <div className="text-white/50 p-6">Loading goals...</div>;

  return (
    <div className="space-y-6 animate-in">
      <div className="flex justify-between items-center">
        <div>
          <h1 className="text-2xl font-bold text-white">Financial Goals</h1>
          <p className="text-white/40 text-sm mt-1">Track your progress towards your dreams.</p>
        </div>
        <button
          onClick={() => { setIsAdding(true); setEditingGoal(null); setForm(initialForm); }}
          className="flex items-center gap-2 bg-purple-500 hover:bg-purple-600 text-white px-4 py-2 rounded-xl transition-colors shadow-lg shadow-purple-500/20"
        >
          <Plus size={18} /> Add Goal
        </button>
      </div>

      {(isAdding || editingGoal) && (
        <div className="bg-[#1a1a2e] border border-white/10 rounded-2xl p-6">
          <h2 className="text-lg font-semibold text-white mb-4">{editingGoal ? 'Edit Goal' : 'New Goal'}</h2>
          <form onSubmit={handleSubmit} className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div>
              <label className="block text-sm text-white/60 mb-1">Goal Title</label>
              <input required type="text" value={form.title} onChange={e => setForm({...form, title: e.target.value})} className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-purple-500/50" placeholder="e.g. Buy a Car" />
            </div>
            <div>
              <label className="block text-sm text-white/60 mb-1">Target Date</label>
              <input type="date" value={form.target_date} onChange={e => setForm({...form, target_date: e.target.value})} className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-purple-500/50" />
            </div>
            <div>
              <label className="block text-sm text-white/60 mb-1">Target Amount</label>
              <input required type="number" step="0.01" min="1" value={form.target_amount} onChange={e => setForm({...form, target_amount: parseFloat(e.target.value)})} className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-purple-500/50" />
            </div>
            <div>
              <label className="block text-sm text-white/60 mb-1">Currently Saved</label>
              <input required type="number" step="0.01" min="0" value={form.saved_amount} onChange={e => setForm({...form, saved_amount: parseFloat(e.target.value)})} className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-purple-500/50" />
            </div>
            <div className="sm:col-span-2">
              <label className="block text-sm text-white/60 mb-1">Notes</label>
              <textarea value={form.notes} onChange={e => setForm({...form, notes: e.target.value})} className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-purple-500/50" rows={2} />
            </div>
            <div className="sm:col-span-2 flex justify-end gap-3 mt-2">
              <button type="button" onClick={() => {setIsAdding(false); setEditingGoal(null);}} className="px-5 py-2.5 rounded-xl text-white/60 hover:text-white hover:bg-white/5 transition-colors">Cancel</button>
              <button type="submit" className="bg-purple-500 hover:bg-purple-600 text-white px-6 py-2.5 rounded-xl shadow-lg shadow-purple-500/20 transition-all font-medium">Save Goal</button>
            </div>
          </form>
        </div>
      )}

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        {goals.map(goal => {
          const progress = Math.min((goal.saved_amount / goal.target_amount) * 100, 100);
          return (
            <div key={goal.id} className="bg-[#1a1a2e] border border-white/10 rounded-2xl p-5 hover:border-white/20 transition-all group relative overflow-hidden">
              <div className="flex justify-between items-start mb-4 relative z-10">
                <div className="flex items-center gap-3">
                  <div className="w-10 h-10 rounded-xl bg-purple-500/10 flex items-center justify-center">
                    <Target className="text-purple-400 w-5 h-5" />
                  </div>
                  <div>
                    <h3 className="text-white font-semibold text-lg leading-tight">{goal.title}</h3>
                    <p className="text-white/40 text-xs mt-0.5">Target: {new Date(goal.target_date).toLocaleDateString()}</p>
                  </div>
                </div>
                <div className="flex gap-2 opacity-0 group-hover:opacity-100 transition-opacity">
                  <button onClick={() => { setEditingGoal(goal); setForm(goal); setIsAdding(false); }} className="text-white/40 hover:text-purple-400 p-1.5 bg-white/5 hover:bg-purple-500/10 rounded-lg">
                    <Edit2 size={14} />
                  </button>
                  <button onClick={() => deleteGoal(goal.id)} className="text-white/40 hover:text-red-400 p-1.5 bg-white/5 hover:bg-red-500/10 rounded-lg">
                    <Trash2 size={14} />
                  </button>
                </div>
              </div>
              
              <div className="space-y-2 relative z-10">
                <div className="flex justify-between text-sm">
                  <span className="text-white/60">Saved: ৳{goal.saved_amount.toLocaleString()}</span>
                  <span className="text-white font-medium">৳{goal.target_amount.toLocaleString()}</span>
                </div>
                <div className="h-2 w-full bg-[#12122a] rounded-full overflow-hidden">
                  <div className="h-full bg-gradient-to-r from-purple-500 to-cyan-500 rounded-full transition-all duration-1000" style={{ width: `${progress}%` }} />
                </div>
                <div className="text-right text-xs text-white/40 font-medium">
                  {progress.toFixed(1)}% Completed
                </div>
              </div>
            </div>
          );
        })}
      </div>

      {goals.length === 0 && !isAdding && (
        <div className="text-center py-16 border border-white/5 rounded-2xl bg-white/[0.02]">
          <TrendingUp className="mx-auto text-white/20 mb-4" size={48} />
          <h3 className="text-white/60 font-medium text-lg">No goals yet</h3>
          <p className="text-white/40 text-sm mt-1">Set a new financial goal to track your savings journey.</p>
        </div>
      )}
    </div>
  );
}

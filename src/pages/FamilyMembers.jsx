import { useState } from 'react';
import { useFamily } from '../hooks/useFamily';
import { useEntity } from '../context/EntityContext';
import { Users, Plus, Edit2, Trash2, User } from 'lucide-react';

export default function FamilyMembers() {
  const { members, loading, addMember, updateMember, deleteMember } = useFamily();
  const { currentEntity } = useEntity();
  const [isAdding, setIsAdding] = useState(false);
  const [editingMember, setEditingMember] = useState(null);

  const initialForm = {
    name: '',
    relationship: 'spouse',
    date_of_birth: '',
    notes: ''
  };
  const [form, setForm] = useState(initialForm);

  // Note: For family members, it makes sense to only show them if we are in the "Family" entity
  // However, users might add them under Personal. We'll show a gentle banner if not in family mode.
  const isFamilyEntity = currentEntity?.type === 'family';

  const handleSubmit = async (e) => {
    e.preventDefault();
    try {
      if (editingMember) {
        await updateMember(editingMember.id, form);
      } else {
        await addMember(form);
      }
      setIsAdding(false);
      setEditingMember(null);
      setForm(initialForm);
    } catch (err) {
      console.error(err);
      alert('Error saving family member');
    }
  };

  const calculateAge = (dob) => {
    if (!dob) return '?';
    const diff = Date.now() - new Date(dob).getTime();
    return Math.abs(new Date(diff).getUTCFullYear() - 1970);
  };

  if (loading) return <div className="text-white/50 p-6">Loading family members...</div>;

  return (
    <div className="space-y-6 animate-in">
      <div className="flex justify-between items-center">
        <div>
          <h1 className="text-2xl font-bold text-white">Family Members</h1>
          <p className="text-white/40 text-sm mt-1">Manage profiles for shared tracking.</p>
        </div>
        <button
          onClick={() => { setIsAdding(true); setEditingMember(null); setForm(initialForm); }}
          className="flex items-center gap-2 bg-pink-500 hover:bg-pink-600 text-white px-4 py-2 rounded-xl transition-colors shadow-lg shadow-pink-500/20"
        >
          <Plus size={18} /> Add Member
        </button>
      </div>

      {!isFamilyEntity && (
        <div className="bg-orange-500/10 border border-orange-500/20 text-orange-400 p-4 rounded-xl text-sm flex gap-3">
          <Users className="w-5 h-5 shrink-0" />
          <p>You are currently in your <strong>{currentEntity?.name}</strong> workspace. Members added here are only visible in this workspace. Consider creating or switching to a <strong>Family</strong> entity from the top bar to track shared household finances!</p>
        </div>
      )}

      {(isAdding || editingMember) && (
        <div className="bg-[#1a1a2e] border border-white/10 rounded-2xl p-6">
          <h2 className="text-lg font-semibold text-white mb-4">{editingMember ? 'Edit Member' : 'New Member'}</h2>
          <form onSubmit={handleSubmit} className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div>
              <label className="block text-sm text-white/60 mb-1">Full Name</label>
              <input required type="text" value={form.name} onChange={e => setForm({...form, name: e.target.value})} className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-pink-500/50" placeholder="e.g. Jane Doe" />
            </div>
            <div>
              <label className="block text-sm text-white/60 mb-1">Relationship</label>
              <select value={form.relationship} onChange={e => setForm({...form, relationship: e.target.value})} className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-pink-500/50">
                <option value="spouse">Spouse / Partner</option>
                <option value="child">Child</option>
                <option value="parent">Parent</option>
                <option value="sibling">Sibling</option>
                <option value="other">Other</option>
              </select>
            </div>
            <div>
              <label className="block text-sm text-white/60 mb-1">Date of Birth</label>
              <input type="date" value={form.date_of_birth} onChange={e => setForm({...form, date_of_birth: e.target.value})} className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-pink-500/50" />
            </div>
            <div className="sm:col-span-2">
              <label className="block text-sm text-white/60 mb-1">Notes</label>
              <textarea value={form.notes} onChange={e => setForm({...form, notes: e.target.value})} className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-pink-500/50" rows={2} />
            </div>
            <div className="sm:col-span-2 flex justify-end gap-3 mt-2">
              <button type="button" onClick={() => {setIsAdding(false); setEditingMember(null);}} className="px-5 py-2.5 rounded-xl text-white/60 hover:text-white hover:bg-white/5 transition-colors">Cancel</button>
              <button type="submit" className="bg-pink-500 hover:bg-pink-600 text-white px-6 py-2.5 rounded-xl shadow-lg shadow-pink-500/20 transition-all font-medium">Save Member</button>
            </div>
          </form>
        </div>
      )}

      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        {members.map(member => (
          <div key={member.id} className="bg-[#1a1a2e] border border-white/10 rounded-2xl p-5 hover:border-white/20 transition-all group flex flex-col items-center text-center">
            <div className="w-16 h-16 rounded-full bg-gradient-to-br from-pink-500 to-purple-600 flex items-center justify-center text-white mb-3 shadow-lg shadow-pink-500/20 relative">
              <User size={28} />
              <div className="absolute top-0 right-0 flex gap-1 opacity-0 group-hover:opacity-100 transition-opacity translate-x-8">
                <button onClick={() => { setEditingMember(member); setForm(member); setIsAdding(false); }} className="text-white hover:text-cyan-400 p-1 bg-[#12122a] border border-white/10 rounded-lg">
                  <Edit2 size={14} />
                </button>
                <button onClick={() => deleteMember(member.id)} className="text-white hover:text-red-400 p-1 bg-[#12122a] border border-white/10 rounded-lg">
                  <Trash2 size={14} />
                </button>
              </div>
            </div>
            <h3 className="text-white font-semibold text-lg">{member.name}</h3>
            <p className="text-pink-400 text-sm font-medium capitalize mt-0.5">{member.relationship}</p>
            {member.date_of_birth && (
              <p className="text-white/40 text-xs mt-2">{calculateAge(member.date_of_birth)} years old</p>
            )}
          </div>
        ))}
      </div>
      {members.length === 0 && !isAdding && (
        <div className="text-center py-12 border border-white/5 rounded-2xl bg-white/[0.02]">
          <Users className="mx-auto text-white/20 mb-4" size={48} />
          <h3 className="text-white/60 font-medium">No family members yet</h3>
          <p className="text-white/40 text-sm mt-1">Add your spouse or children to track shared finances.</p>
        </div>
      )}
    </div>
  );
}

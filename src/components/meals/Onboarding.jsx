import { useState } from 'react';
import { useNavigate } from 'react-router';
import { useMeal } from '../../context/MealContext';
import { UtensilsCrossed, KeyRound, Hourglass, ArrowLeft, Check } from 'lucide-react';

// Create/join a mess. Shown full-page when the user has no approved group,
// and at /meals/groups to create or join another mess.
export default function Onboarding() {
  const { approved, pending, activeMembership, createGroup, joinByCode, switchGroup } = useMeal();
  const navigate = useNavigate();
  const [createForm, setCreateForm] = useState({ name: '', displayName: '' });
  const [joinForm, setJoinForm] = useState({ code: '', displayName: '' });
  const [busy, setBusy] = useState(false);

  const handleCreate = async (e) => {
    e.preventDefault();
    setBusy(true);
    try {
      await createGroup(createForm.name, createForm.displayName);
      navigate('/meals');
    } catch (err) {
      alert('Error creating group: ' + err.message);
    } finally {
      setBusy(false);
    }
  };

  const handleJoin = async (e) => {
    e.preventDefault();
    setBusy(true);
    try {
      await joinByCode(joinForm.code, joinForm.displayName);
      setJoinForm({ code: '', displayName: '' });
    } catch (err) {
      alert('Error joining group: ' + err.message);
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="space-y-6 animate-in max-w-4xl">
      <div>
        <h1 className="text-2xl font-bold text-white">
          {approved.length > 0 ? 'My Messes' : 'Meal Management'}
        </h1>
        <p className="text-white/40 text-sm mt-1">Track mess meals, bazar, deposits and duties with your mess mates.</p>
      </div>

      {approved.length > 0 && (
        <div className="bg-[#1a1a2e] border border-white/10 rounded-2xl p-5 space-y-2">
          {approved.map(m => (
            <div key={m.id} className="flex items-center gap-3 bg-[#12122a] border border-white/10 rounded-xl px-4 py-3">
              <UtensilsCrossed size={16} className="text-cyan-400 shrink-0" />
              <span className="flex-1 text-white text-sm font-medium truncate">{m.meal_groups?.name || 'Mess'}</span>
              <span className="text-white/40 text-xs capitalize">{m.role}</span>
              {activeMembership?.group_id === m.group_id ? (
                <span className="flex items-center gap-1 text-emerald-400 text-xs"><Check size={13} /> Active</span>
              ) : (
                <button
                  onClick={() => { switchGroup(m.group_id); navigate('/meals'); }}
                  className="text-xs px-3 py-1.5 rounded-lg bg-white/5 border border-white/10 text-white/60 hover:text-cyan-400"
                >
                  Switch
                </button>
              )}
            </div>
          ))}
          <button onClick={() => navigate('/meals')} className="flex items-center gap-1.5 text-white/40 hover:text-white text-xs mt-1">
            <ArrowLeft size={13} /> Back to the mess dashboard
          </button>
        </div>
      )}

      {pending.length > 0 && (
        <div className="bg-orange-500/10 border border-orange-500/20 rounded-2xl p-5 flex items-center gap-4">
          <Hourglass className="text-orange-400 shrink-0" size={24} />
          <div>
            <p className="text-orange-300 font-medium">Waiting for approval</p>
            <p className="text-white/50 text-sm">
              {pending.map(p => p.meal_groups?.name || 'a group').join(', ')} — the manager needs to approve your request.
            </p>
          </div>
        </div>
      )}

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <form onSubmit={handleCreate} className="bg-[#1a1a2e] border border-white/10 rounded-2xl p-6 space-y-4">
          <div className="w-12 h-12 rounded-2xl bg-gradient-to-br from-cyan-500 to-purple-600 flex items-center justify-center text-white shadow-lg shadow-cyan-500/20">
            <UtensilsCrossed size={22} />
          </div>
          <div>
            <h2 className="text-lg font-semibold text-white">Create a Mess</h2>
            <p className="text-white/40 text-sm">Start a new meal group. You become the manager and get an invite code.</p>
          </div>
          <input required type="text" placeholder="Mess name, e.g. Green House Mess" value={createForm.name} onChange={e => setCreateForm({ ...createForm, name: e.target.value })} className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-cyan-500/50" />
          <input type="text" placeholder="Your display name (optional)" value={createForm.displayName} onChange={e => setCreateForm({ ...createForm, displayName: e.target.value })} className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-cyan-500/50" />
          <button type="submit" disabled={busy} className="w-full bg-cyan-500 hover:bg-cyan-600 text-white px-6 py-2.5 rounded-xl shadow-lg shadow-cyan-500/20 font-medium disabled:opacity-50">
            Create Group
          </button>
        </form>

        <form onSubmit={handleJoin} className="bg-[#1a1a2e] border border-white/10 rounded-2xl p-6 space-y-4">
          <div className="w-12 h-12 rounded-2xl bg-white/5 border border-white/10 flex items-center justify-center text-white/70">
            <KeyRound size={22} />
          </div>
          <div>
            <h2 className="text-lg font-semibold text-white">Join a Mess</h2>
            <p className="text-white/40 text-sm">Got an invite code from your mess manager? Enter it here.</p>
          </div>
          <input required type="text" placeholder="Invite code, e.g. ABCD2345" value={joinForm.code} onChange={e => setJoinForm({ ...joinForm, code: e.target.value.toUpperCase() })} className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white tracking-widest uppercase focus:outline-none focus:border-purple-500/50" />
          <input type="text" placeholder="Your display name (optional)" value={joinForm.displayName} onChange={e => setJoinForm({ ...joinForm, displayName: e.target.value })} className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-purple-500/50" />
          <button type="submit" disabled={busy} className="w-full bg-purple-500 hover:bg-purple-600 text-white px-6 py-2.5 rounded-xl shadow-lg shadow-purple-500/20 font-medium disabled:opacity-50">
            Request to Join
          </button>
        </form>
      </div>
    </div>
  );
}

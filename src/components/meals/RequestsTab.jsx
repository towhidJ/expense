import { useState } from 'react';
import { Send, Check, X, Ban, UtensilsCrossed, UserPlus } from 'lucide-react';

const pad = (n) => String(n).padStart(2, '0');
const tomorrow = () => {
  const d = new Date();
  d.setDate(d.getDate() + 1);
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
};

const SLOT_LABELS = { breakfast: 'Breakfast', lunch: 'Lunch', dinner: 'Dinner' };

const STATUS_STYLES = {
  pending: 'bg-orange-500/10 text-orange-400 border-orange-500/20',
  approved: 'bg-emerald-500/10 text-emerald-400 border-emerald-500/20',
  rejected: 'bg-red-500/10 text-red-400 border-red-500/20',
  cancelled: 'bg-white/5 text-white/40 border-white/10'
};

function slotSummary(req) {
  const parts = ['breakfast', 'lunch', 'dinner']
    .filter(s => Number(req[s]) > 0)
    .map(s => req.type === 'guest' ? `${SLOT_LABELS[s]} ×${Number(req[s])}` : SLOT_LABELS[s]);
  return parts.join(', ');
}

// Members request "meal off" or "guest meal" themselves; the manager
// approves (which writes the meal entry) or rejects. The cutoff time, if the
// group has one, is enforced by the submit RPC.
export default function RequestsTab({
  group, requests, members, isManager, currentUserId,
  submitRequest, cancelRequest, respondRequest
}) {
  const [form, setForm] = useState({
    type: 'off', date: tomorrow(),
    breakfast: 0, lunch: 0, dinner: 0, note: ''
  });
  const [saving, setSaving] = useState(false);

  const myMember = members.find(m => m.user_id === currentUserId && m.status === 'approved');
  const memberName = (id) => members.find(m => m.id === id)?.display_name || 'Member';

  const isOff = form.type === 'off';
  const cutoff = group?.cutoff_time ? group.cutoff_time.slice(0, 5) : null;

  const setType = (type) => setForm({ ...form, type, breakfast: 0, lunch: 0, dinner: 0 });

  const handleSubmit = async (e) => {
    e.preventDefault();
    setSaving(true);
    try {
      await submitRequest({
        date: form.date, type: form.type,
        breakfast: Number(form.breakfast) || 0,
        lunch: Number(form.lunch) || 0,
        dinner: Number(form.dinner) || 0,
        note: form.note
      });
      setForm({ type: form.type, date: tomorrow(), breakfast: 0, lunch: 0, dinner: 0, note: '' });
    } catch (err) {
      console.error(err);
      alert(err.message);
    } finally {
      setSaving(false);
    }
  };

  const act = async (fn) => {
    try {
      await fn();
    } catch (err) {
      console.error(err);
      alert(err.message);
    }
  };

  return (
    <div className="space-y-6">
      {myMember && (
        <form onSubmit={handleSubmit} className="bg-[#1a1a2e] border border-white/10 rounded-2xl p-6 space-y-4">
          <div className="flex flex-wrap items-center justify-between gap-2">
            <h3 className="text-white font-semibold">New Request</h3>
            {cutoff && (
              <span className="text-xs text-orange-400/80 bg-orange-500/10 border border-orange-500/20 rounded-lg px-2.5 py-1">
                Cutoff: request for a date must be in by {cutoff} the day before
              </span>
            )}
          </div>

          <div className="grid grid-cols-2 gap-3">
            <button type="button" onClick={() => setType('off')}
              className={`flex items-center justify-center gap-2 rounded-xl px-4 py-3 text-sm border transition-colors ${
                isOff ? 'bg-cyan-500/15 border-cyan-500/40 text-cyan-400' : 'bg-[#12122a] border-white/10 text-white/50 hover:text-white'
              }`}>
              <UtensilsCrossed size={16} /> Meal Off
            </button>
            <button type="button" onClick={() => setType('guest')}
              className={`flex items-center justify-center gap-2 rounded-xl px-4 py-3 text-sm border transition-colors ${
                !isOff ? 'bg-purple-500/15 border-purple-500/40 text-purple-400' : 'bg-[#12122a] border-white/10 text-white/50 hover:text-white'
              }`}>
              <UserPlus size={16} /> Guest Meal
            </button>
          </div>

          <div className="grid sm:grid-cols-2 gap-4">
            <div>
              <label className="block text-sm text-white/60 mb-1">Date</label>
              <input required type="date" value={form.date}
                onChange={e => setForm({ ...form, date: e.target.value })}
                className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-cyan-500/50" />
            </div>
            <div>
              <label className="block text-sm text-white/60 mb-1">
                {isOff ? 'Which meals are off?' : 'Guests per meal'}
              </label>
              <div className="grid grid-cols-3 gap-2">
                {['breakfast', 'lunch', 'dinner'].map(slot => (
                  isOff ? (
                    <label key={slot} className={`flex items-center justify-center gap-1.5 rounded-xl px-2 py-2.5 text-xs border cursor-pointer ${
                      Number(form[slot]) > 0 ? 'bg-cyan-500/15 border-cyan-500/40 text-cyan-400' : 'bg-[#12122a] border-white/10 text-white/50'
                    }`}>
                      <input type="checkbox" className="hidden"
                        checked={Number(form[slot]) > 0}
                        onChange={e => setForm({ ...form, [slot]: e.target.checked ? 1 : 0 })} />
                      {SLOT_LABELS[slot]}
                    </label>
                  ) : (
                    <div key={slot}>
                      <input type="number" min="0" step="1" value={form[slot]}
                        onChange={e => setForm({ ...form, [slot]: e.target.value })}
                        className="w-full bg-[#12122a] border border-white/10 rounded-xl px-2 py-2 text-white text-center text-sm focus:outline-none focus:border-purple-500/50" />
                      <p className="text-[10px] text-white/30 text-center mt-1">{SLOT_LABELS[slot]}</p>
                    </div>
                  )
                ))}
              </div>
            </div>
          </div>

          <div>
            <label className="block text-sm text-white/60 mb-1">Note (optional)</label>
            <input type="text" value={form.note} placeholder={isOff ? 'Going home for the weekend...' : 'My cousin is visiting...'}
              onChange={e => setForm({ ...form, note: e.target.value })}
              className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-cyan-500/50" />
          </div>

          <div className="flex justify-end">
            <button type="submit" disabled={saving}
              className="flex items-center gap-2 bg-cyan-500 hover:bg-cyan-600 text-white px-6 py-2.5 rounded-xl shadow-lg shadow-cyan-500/20 font-medium disabled:opacity-50">
              <Send size={16} /> {saving ? 'Sending...' : 'Send Request'}
            </button>
          </div>
        </form>
      )}

      <div className="bg-[#1a1a2e] border border-white/10 rounded-2xl overflow-hidden">
        <div className="px-5 py-4 border-b border-white/10">
          <h3 className="text-white font-semibold">This Month's Requests</h3>
        </div>
        <div className="divide-y divide-white/5">
          {requests.map(req => {
            const mine = myMember && req.member_id === myMember.id;
            return (
              <div key={req.id} className="px-5 py-4 flex flex-wrap items-center gap-3">
                <div className="flex-1 min-w-[220px]">
                  <p className="text-white text-sm">
                    {memberName(req.member_id)}
                    {mine && <span className="text-cyan-400 text-xs ml-1">(you)</span>}
                    <span className={`ml-2 text-xs ${req.type === 'off' ? 'text-cyan-400' : 'text-purple-400'}`}>
                      {req.type === 'off' ? 'Meal Off' : 'Guest Meal'}
                    </span>
                  </p>
                  <p className="text-white/50 text-xs mt-0.5">
                    {new Date(req.date + 'T00:00:00').toLocaleDateString(undefined, { weekday: 'short', day: 'numeric', month: 'short' })}
                    {' — '}{slotSummary(req)}
                    {req.note && <span className="text-white/30"> · {req.note}</span>}
                  </p>
                </div>
                <span className={`text-xs px-2.5 py-1 rounded-lg border capitalize ${STATUS_STYLES[req.status]}`}>
                  {req.status}
                </span>
                {req.status === 'pending' && isManager && (
                  <div className="flex gap-2">
                    <button onClick={() => act(() => respondRequest(req.id, true))}
                      className="flex items-center gap-1 px-3 py-1.5 rounded-lg bg-emerald-500/10 border border-emerald-500/20 text-emerald-400 hover:bg-emerald-500/20 text-xs">
                      <Check size={13} /> Approve
                    </button>
                    <button onClick={() => act(() => respondRequest(req.id, false))}
                      className="flex items-center gap-1 px-3 py-1.5 rounded-lg bg-red-500/10 border border-red-500/20 text-red-400 hover:bg-red-500/20 text-xs">
                      <X size={13} /> Reject
                    </button>
                  </div>
                )}
                {req.status === 'pending' && !isManager && mine && (
                  <button onClick={() => act(() => cancelRequest(req.id))}
                    className="flex items-center gap-1 px-3 py-1.5 rounded-lg bg-white/5 border border-white/10 text-white/50 hover:text-white text-xs">
                    <Ban size={13} /> Cancel
                  </button>
                )}
              </div>
            );
          })}
          {requests.length === 0 && (
            <p className="px-5 py-8 text-center text-white/40 text-sm">No requests this month.</p>
          )}
        </div>
      </div>
      <p className="text-white/30 text-xs">
        Approving a meal-off sets those meal slots to 0 for that date; approving a guest request adds the guest counts.
      </p>
    </div>
  );
}

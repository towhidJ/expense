import { useState, useEffect, Fragment } from 'react';
import { ChevronLeft, ChevronRight, Minus, Plus, UserPlus, PartyPopper, X } from 'lucide-react';

const pad = (n) => String(n).padStart(2, '0');
const toISO = (d) => `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;

function Stepper({ value, onChange, disabled }) {
  return (
    <div className="inline-flex items-center gap-1">
      <button
        type="button"
        disabled={disabled || value <= 0}
        onClick={() => onChange(value - 1)}
        className="w-7 h-7 flex items-center justify-center rounded-lg bg-[#12122a] border border-white/10 text-white/60 hover:text-white disabled:opacity-30"
      >
        <Minus size={13} />
      </button>
      <span className="w-8 text-center text-white font-medium">{value}</span>
      <button
        type="button"
        disabled={disabled}
        onClick={() => onChange(value + 1)}
        className="w-7 h-7 flex items-center justify-center rounded-lg bg-[#12122a] border border-white/10 text-white/60 hover:text-white disabled:opacity-30"
      >
        <Plus size={13} />
      </button>
    </div>
  );
}

const SLOTS = [
  { key: 'breakfast', guestKey: 'guest_breakfast', label: 'Breakfast' },
  { key: 'lunch', guestKey: 'guest_lunch', label: 'Lunch' },
  { key: 'dinner', guestKey: 'guest_dinner', label: 'Dinner' }
];

export default function MealEntryGrid({ members, entries, upsertEntry, isManager, currentUserId, year, month, holidays = [], upsertHoliday, deleteHoliday }) {
  const today = new Date();
  const inThisMonth = today.getFullYear() === year && today.getMonth() + 1 === month;
  const [date, setDate] = useState(inThisMonth ? toISO(today) : `${year}-${pad(month)}-01`);
  const [guestOpen, setGuestOpen] = useState({});
  const [saving, setSaving] = useState(null);
  const [holidayModal, setHolidayModal] = useState(null); // { title, menu }

  useEffect(() => {
    const now = new Date();
    const isCurrent = now.getFullYear() === year && now.getMonth() + 1 === month;
    setDate(isCurrent ? toISO(now) : `${year}-${pad(month)}-01`);
  }, [year, month]);

  const approvedMembers = members.filter(m => m.status === 'approved');
  const entryFor = (memberId) =>
    entries.find(e => e.member_id === memberId && e.date === date) || {
      breakfast: 0, lunch: 0, dinner: 0,
      guest_breakfast: 0, guest_lunch: 0, guest_dinner: 0
    };

  const shiftDate = (days) => {
    const d = new Date(date + 'T00:00:00');
    d.setDate(d.getDate() + days);
    setDate(toISO(d));
  };

  const canEdit = (member) => isManager || member.user_id === currentUserId;

  const save = async (member, patch) => {
    const current = entryFor(member.id);
    setSaving(member.id);
    try {
      await upsertEntry(member.id, date, { ...current, ...patch });
    } catch (err) {
      console.error(err);
      alert('Error saving meal: ' + err.message);
    } finally {
      setSaving(null);
    }
  };

  const dayName = new Date(date + 'T00:00:00').toLocaleDateString('en-US', { weekday: 'long' });
  const holiday = holidays.find(h => h.date === date);

  const saveHoliday = async (e) => {
    e.preventDefault();
    try {
      await upsertHoliday({ date, title: holidayModal.title, menu: holidayModal.menu });
      setHolidayModal(null);
    } catch (err) {
      alert('Error saving holiday: ' + err.message);
    }
  };

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap items-center gap-3">
        <button onClick={() => shiftDate(-1)} className="p-2 rounded-xl bg-[#1a1a2e] border border-white/10 text-white/60 hover:text-white">
          <ChevronLeft size={18} />
        </button>
        <input
          type="date"
          value={date}
          onChange={e => e.target.value && setDate(e.target.value)}
          className="bg-[#1a1a2e] border border-white/10 rounded-xl px-4 py-2 text-white focus:outline-none focus:border-cyan-500/50"
        />
        <button onClick={() => shiftDate(1)} className="p-2 rounded-xl bg-[#1a1a2e] border border-white/10 text-white/60 hover:text-white">
          <ChevronRight size={18} />
        </button>
        <span className="text-white/40 text-sm">{dayName}</span>
        {isManager && (
          <button
            onClick={() => setHolidayModal({ title: holiday?.title || 'Meal Holiday', menu: holiday?.menu || '' })}
            className={`ml-auto flex items-center gap-1.5 px-3 py-2 rounded-xl border text-xs ${holiday ? 'border-pink-500/40 bg-pink-500/10 text-pink-300' : 'border-white/10 bg-[#1a1a2e] text-white/50 hover:text-white'}`}
          >
            <PartyPopper size={14} /> {holiday ? 'Edit Holiday' : 'Mark Holiday'}
          </button>
        )}
      </div>

      {holiday && (
        <div className="bg-pink-500/10 border border-pink-500/20 rounded-2xl p-4 flex items-start gap-3">
          <PartyPopper className="text-pink-400 shrink-0 mt-0.5" size={20} />
          <div>
            <p className="text-pink-300 font-medium">{holiday.title}</p>
            {holiday.menu && <p className="text-white/60 text-sm mt-0.5">Special food / nasta: {holiday.menu}</p>}
            <p className="text-white/30 text-xs mt-1">Meal holiday — regular meals are usually off; record the feast cost as a "Feast / Special" expense.</p>
          </div>
        </div>
      )}

      {holidayModal && isManager && (
        <div className="fixed inset-0 bg-black/60 backdrop-blur-sm flex items-center justify-center z-50 p-4" onClick={() => setHolidayModal(null)}>
          <form onSubmit={saveHoliday} className="bg-[#1a1a2e] border border-white/10 rounded-2xl p-6 w-full max-w-sm space-y-4" onClick={e => e.stopPropagation()}>
            <div className="flex justify-between items-center">
              <h3 className="text-white font-semibold flex items-center gap-2"><PartyPopper size={16} className="text-pink-400" /> Holiday — {date}</h3>
              <button type="button" onClick={() => setHolidayModal(null)} className="text-white/40 hover:text-white"><X size={18} /></button>
            </div>
            <div>
              <label className="block text-sm text-white/60 mb-1">Title</label>
              <input required type="text" value={holidayModal.title} onChange={e => setHolidayModal({ ...holidayModal, title: e.target.value })} className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-pink-500/50" placeholder="e.g. Eid Day, Friday Feast" />
            </div>
            <div>
              <label className="block text-sm text-white/60 mb-1">Special food / nasta plan (optional)</label>
              <textarea rows={2} value={holidayModal.menu} onChange={e => setHolidayModal({ ...holidayModal, menu: e.target.value })} className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-pink-500/50" placeholder="e.g. Biriyani + borhani, morning khichuri" />
            </div>
            <div className="flex justify-between gap-3">
              {holiday ? (
                <button type="button" onClick={() => { if (confirm('Remove this holiday?')) deleteHoliday(holiday.id).then(() => setHolidayModal(null)).catch(err => alert(err.message)); }} className="px-4 py-2 rounded-xl text-red-400 border border-red-500/20 hover:bg-red-500/10 text-sm">
                  Remove
                </button>
              ) : <span />}
              <div className="flex gap-2">
                <button type="button" onClick={() => setHolidayModal(null)} className="px-4 py-2 rounded-xl text-white/60 hover:text-white hover:bg-white/5 text-sm">Cancel</button>
                <button type="submit" className="bg-pink-500 hover:bg-pink-600 text-white px-5 py-2 rounded-xl text-sm font-medium shadow-lg shadow-pink-500/20">Save</button>
              </div>
            </div>
          </form>
        </div>
      )}

      <div className="bg-[#1a1a2e] border border-white/10 rounded-2xl overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-white/10 text-white/40 text-left">
                <th className="px-4 py-3 font-medium">Member</th>
                {SLOTS.map(s => <th key={s.key} className="px-4 py-3 font-medium text-center">{s.label}</th>)}
                <th className="px-4 py-3 font-medium text-center">Guests</th>
              </tr>
            </thead>
            <tbody>
              {approvedMembers.map(member => {
                const entry = entryFor(member.id);
                const editable = canEdit(member) && saving !== member.id;
                const guestTotal = Number(entry.guest_breakfast) + Number(entry.guest_lunch) + Number(entry.guest_dinner);
                return (
                  <Fragment key={member.id}>
                    <tr className="border-b border-white/5">
                      <td className="px-4 py-3 text-white">
                        {member.display_name}
                        {member.user_id === currentUserId && <span className="text-cyan-400 text-xs ml-1">(you)</span>}
                      </td>
                      {SLOTS.map(s => (
                        <td key={s.key} className="px-4 py-3 text-center">
                          <Stepper
                            value={Number(entry[s.key])}
                            disabled={!editable}
                            onChange={v => save(member, { [s.key]: v })}
                          />
                        </td>
                      ))}
                      <td className="px-4 py-3 text-center">
                        <button
                          type="button"
                          onClick={() => setGuestOpen(g => ({ ...g, [member.id]: !g[member.id] }))}
                          className={`inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg border text-xs ${guestTotal > 0 ? 'border-purple-500/40 text-purple-300 bg-purple-500/10' : 'border-white/10 text-white/50 bg-[#12122a]'}`}
                        >
                          <UserPlus size={13} /> {guestTotal > 0 ? `${guestTotal} guest` : 'Guests'}
                        </button>
                      </td>
                    </tr>
                    {guestOpen[member.id] && (
                      <tr className="border-b border-white/5 bg-white/[0.02]">
                        <td className="px-4 py-2 text-white/40 text-xs">Guest meals</td>
                        {SLOTS.map(s => (
                          <td key={s.guestKey} className="px-4 py-2 text-center">
                            <Stepper
                              value={Number(entry[s.guestKey])}
                              disabled={!editable}
                              onChange={v => save(member, { [s.guestKey]: v })}
                            />
                          </td>
                        ))}
                        <td />
                      </tr>
                    )}
                  </Fragment>
                );
              })}
              {approvedMembers.length === 0 && (
                <tr><td colSpan={5} className="px-4 py-8 text-center text-white/40">No approved members yet.</td></tr>
              )}
            </tbody>
          </table>
        </div>
      </div>
      {!isManager && (
        <p className="text-white/30 text-xs">You can only record your own meals. The manager can edit everyone's.</p>
      )}
    </div>
  );
}

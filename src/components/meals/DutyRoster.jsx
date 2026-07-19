import { useState, useEffect } from 'react';
import { ChevronLeft, ChevronRight, Plus, X, Trash2, ClipboardList, Repeat, ArrowUp, ArrowDown } from 'lucide-react';

const pad = (n) => String(n).padStart(2, '0');
// Bangladeshi week: Saturday first
const DAY_LABELS = ['Sat', 'Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri'];

function buildWeeks(year, month) {
  const daysInMonth = new Date(year, month, 0).getDate();
  const firstDay = new Date(year, month - 1, 1);
  const offset = (firstDay.getDay() + 1) % 7; // Sat=0 ... Fri=6
  const weeks = [];
  let week = new Array(offset).fill(null);
  for (let d = 1; d <= daysInMonth; d++) {
    week.push(`${year}-${pad(month)}-${pad(d)}`);
    if (week.length === 7) {
      weeks.push(week);
      week = [];
    }
  }
  if (week.length > 0) weeks.push([...week, ...new Array(7 - week.length).fill(null)]);
  return weeks;
}

export default function DutyRoster({
  group, dutyTypes, dutyAssignments, members, isManager, year, month,
  assignDuty, removeDutyAssignment, addDutyType, updateDutyType, deleteDutyType,
  rotationOrders, setRotationOrder, generateDutyRotation
}) {
  const weeks = buildWeeks(year, month);
  const today = new Date();
  const todayISO = `${today.getFullYear()}-${pad(today.getMonth() + 1)}-${pad(today.getDate())}`;
  const initialWeek = Math.max(0, weeks.findIndex(w => w.includes(todayISO)));
  const [weekIndex, setWeekIndex] = useState(initialWeek);
  const [picker, setPicker] = useState(null); // { dutyTypeId, date }
  const [newTypeName, setNewTypeName] = useState('');
  const [rotationPanel, setRotationPanel] = useState(null); // duty_type_id
  const [genDays, setGenDays] = useState(7);
  const [generating, setGenerating] = useState(false);

  useEffect(() => {
    const w = buildWeeks(year, month);
    const now = new Date();
    const iso = `${now.getFullYear()}-${pad(now.getMonth() + 1)}-${pad(now.getDate())}`;
    setWeekIndex(Math.max(0, w.findIndex(wk => wk.includes(iso))));
  }, [year, month]);

  const week = weeks[Math.min(weekIndex, weeks.length - 1)] || [];
  const approvedMembers = members.filter(m => m.status === 'approved');
  const memberName = (id) => members.find(m => m.id === id)?.display_name || '?';

  // Cooking disappears from the roster when the mess has a maid (kajer bua)
  const activeTypes = dutyTypes.filter(t => t.is_active && !(group?.has_maid && t.excluded_when_maid));

  const cellAssignments = (dutyTypeId, date) =>
    dutyAssignments.filter(a => a.duty_type_id === dutyTypeId && a.date === date);

  const handleAssign = async (memberId) => {
    try {
      await assignDuty({ duty_type_id: picker.dutyTypeId, member_id: memberId, date: picker.date });
      setPicker(null);
    } catch (err) {
      console.error(err);
      alert('Error assigning duty: ' + err.message);
    }
  };

  const handleAddType = async (e) => {
    e.preventDefault();
    if (!newTypeName.trim()) return;
    try {
      await addDutyType(newTypeName.trim());
      setNewTypeName('');
    } catch (err) {
      alert('Error adding duty type: ' + err.message);
    }
  };

  const orderForType = (dutyTypeId) =>
    (rotationOrders || []).filter(r => r.duty_type_id === dutyTypeId).sort((a, b) => a.sort_order - b.sort_order);

  const toggleInRotation = async (dutyTypeId, memberId) => {
    const current = orderForType(dutyTypeId).map(r => r.member_id);
    const next = current.includes(memberId) ? current.filter(id => id !== memberId) : [...current, memberId];
    try {
      await setRotationOrder(dutyTypeId, next);
    } catch (err) {
      alert('Error updating rotation: ' + err.message);
    }
  };

  const moveInRotation = async (dutyTypeId, index, dir) => {
    const current = orderForType(dutyTypeId).map(r => r.member_id);
    const target = index + dir;
    if (target < 0 || target >= current.length) return;
    [current[index], current[target]] = [current[target], current[index]];
    try {
      await setRotationOrder(dutyTypeId, current);
    } catch (err) {
      alert('Error reordering: ' + err.message);
    }
  };

  const handleGenerate = async (dutyTypeId) => {
    setGenerating(true);
    try {
      const startDate = week.find(d => d) || todayISO;
      const created = await generateDutyRotation(dutyTypeId, startDate, Number(genDays));
      if (created.length === 0) alert('No new days to fill (all upcoming days already assigned or holidays).');
    } catch (err) {
      alert('Error generating rotation: ' + err.message);
    } finally {
      setGenerating(false);
    }
  };

  return (
    <div className="space-y-6">
      <div className="flex items-center gap-3">
        <button onClick={() => setWeekIndex(i => Math.max(0, i - 1))} disabled={weekIndex === 0} className="p-2 rounded-xl bg-card border border-foreground/10 text-foreground/60 hover:text-foreground disabled:opacity-30">
          <ChevronLeft size={18} />
        </button>
        <span className="text-foreground/60 text-sm">Week {Math.min(weekIndex, weeks.length - 1) + 1} of {weeks.length}</span>
        <button onClick={() => setWeekIndex(i => Math.min(weeks.length - 1, i + 1))} disabled={weekIndex >= weeks.length - 1} className="p-2 rounded-xl bg-card border border-foreground/10 text-foreground/60 hover:text-foreground disabled:opacity-30">
          <ChevronRight size={18} />
        </button>
        {group?.has_maid && (
          <span className="text-purple-300 text-xs bg-purple-500/10 border border-purple-500/20 rounded-lg px-3 py-1.5">
            Maid cooks — cooking duty hidden
          </span>
        )}
      </div>

      <div className="bg-card border border-foreground/10 rounded-2xl overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-sm min-w-[760px]">
            <thead>
              <tr className="border-b border-foreground/10 text-foreground/40 text-left">
                <th className="px-4 py-3 font-medium w-40">Duty</th>
                {week.map((date, i) => (
                  <th key={i} className={`px-2 py-3 font-medium text-center ${date === todayISO ? 'text-cyan-400' : ''}`}>
                    {DAY_LABELS[i]}
                    <div className="text-xs font-normal">{date ? Number(date.slice(-2)) : ''}</div>
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {activeTypes.map(type => (
                <tr key={type.id} className="border-b border-foreground/5 last:border-0">
                  <td className="px-4 py-3 text-foreground font-medium">{type.name}</td>
                  {week.map((date, i) => (
                    <td key={i} className={`px-2 py-2 text-center align-top ${date === todayISO ? 'bg-cyan-500/5' : ''}`}>
                      {date && (
                        <div className="flex flex-col items-center gap-1">
                          {cellAssignments(type.id, date).map(a => (
                            <span key={a.id} className="inline-flex items-center gap-1 bg-foreground/5 border border-foreground/10 text-foreground/80 text-xs rounded-lg px-2 py-1 max-w-full">
                              <span className="truncate">{memberName(a.member_id)}</span>
                              {isManager && (
                                <button onClick={() => removeDutyAssignment(a.id).catch(err => alert(err.message))} className="text-foreground/40 hover:text-red-400 shrink-0">
                                  <X size={11} />
                                </button>
                              )}
                            </span>
                          ))}
                          {isManager && (
                            <button
                              onClick={() => setPicker({ dutyTypeId: type.id, date, dutyName: type.name })}
                              className="w-6 h-6 flex items-center justify-center rounded-lg border border-dashed border-foreground/15 text-foreground/30 hover:text-cyan-400 hover:border-cyan-500/40"
                            >
                              <Plus size={12} />
                            </button>
                          )}
                        </div>
                      )}
                    </td>
                  ))}
                </tr>
              ))}
              {activeTypes.length === 0 && (
                <tr><td colSpan={8} className="px-4 py-8 text-center text-foreground/40">No active duty types.</td></tr>
              )}
            </tbody>
          </table>
        </div>
      </div>

      {picker && (
        <div className="fixed inset-0 bg-black/60 backdrop-blur-sm flex items-center justify-center z-50 p-4" onClick={() => setPicker(null)}>
          <div className="bg-card border border-foreground/10 rounded-2xl p-6 w-full max-w-sm" onClick={e => e.stopPropagation()}>
            <h3 className="text-foreground font-semibold mb-1">{picker.dutyName}</h3>
            <p className="text-foreground/40 text-sm mb-4">{picker.date} — pick a member</p>
            <div className="space-y-2 max-h-64 overflow-y-auto">
              {approvedMembers.map(m => (
                <button key={m.id} onClick={() => handleAssign(m.id)} className="w-full text-left px-4 py-2.5 rounded-xl bg-muted border border-foreground/10 text-foreground hover:border-cyan-500/50 transition-colors">
                  {m.display_name}
                </button>
              ))}
            </div>
            <button onClick={() => setPicker(null)} className="mt-4 w-full px-4 py-2 rounded-xl text-foreground/60 hover:text-foreground hover:bg-foreground/5">Cancel</button>
          </div>
        </div>
      )}

      {isManager && (
        <div className="bg-card border border-foreground/10 rounded-2xl p-6">
          <h3 className="text-foreground font-semibold mb-4 flex items-center gap-2"><ClipboardList size={18} /> Duty Types</h3>
          <div className="space-y-2 mb-4">
            {dutyTypes.map(type => (
              <div key={type.id}>
                <div className="flex items-center gap-3 bg-muted border border-foreground/10 rounded-xl px-4 py-2.5">
                  <span className="flex-1 text-foreground text-sm">
                    {type.name}
                    {type.excluded_when_maid && <span className="text-purple-400/60 text-xs ml-2">(skipped when maid)</span>}
                  </span>
                  <label className="flex items-center gap-2 text-foreground/50 text-xs cursor-pointer">
                    <input
                      type="checkbox"
                      checked={type.is_active}
                      onChange={e => updateDutyType(type.id, { is_active: e.target.checked }).catch(err => alert(err.message))}
                      className="accent-cyan-500"
                    />
                    Active
                  </label>
                  <button
                    onClick={() => setRotationPanel(rotationPanel === type.id ? null : type.id)}
                    className={`flex items-center gap-1.5 px-2.5 py-1.5 rounded-lg text-xs border ${rotationPanel === type.id ? 'bg-cyan-500/20 border-cyan-500/40 text-cyan-400' : 'bg-card border-foreground/10 text-white/50 hover:text-white'}`}
                  >
                    <Repeat size={13} /> Auto-rotate
                  </button>
                  {!type.is_builtin && (
                    <button onClick={() => { if (confirm(`Delete duty "${type.name}" and its assignments?`)) deleteDutyType(type.id).catch(err => alert(err.message)); }} className="p-1.5 rounded-lg text-foreground/40 hover:text-red-400">
                      <Trash2 size={14} />
                    </button>
                  )}
                </div>

                {rotationPanel === type.id && (
                  <div className="mt-2 bg-muted border border-foreground/10 rounded-xl p-4 space-y-3">
                    <p className="text-foreground/40 text-xs">Pick who's in the rotation and their order, then generate assignments.</p>
                    <div className="space-y-1.5">
                      {approvedMembers.map(m => {
                        const order = orderForType(type.id);
                        const idx = order.findIndex(r => r.member_id === m.id);
                        const inRotation = idx !== -1;
                        return (
                          <div key={m.id} className="flex items-center gap-2 bg-card border border-foreground/10 rounded-lg px-3 py-1.5">
                            <input type="checkbox" checked={inRotation} onChange={() => toggleInRotation(type.id, m.id)} className="accent-cyan-500" />
                            <span className={`flex-1 text-sm ${inRotation ? 'text-foreground' : 'text-foreground/40'}`}>{m.display_name}</span>
                            {inRotation && (
                              <>
                                <span className="text-foreground/30 text-xs">#{idx + 1}</span>
                                <button disabled={idx === 0} onClick={() => moveInRotation(type.id, idx, -1)} className="p-1 text-foreground/40 hover:text-foreground disabled:opacity-20"><ArrowUp size={13} /></button>
                                <button disabled={idx === order.length - 1} onClick={() => moveInRotation(type.id, idx, 1)} className="p-1 text-foreground/40 hover:text-foreground disabled:opacity-20"><ArrowDown size={13} /></button>
                              </>
                            )}
                          </div>
                        );
                      })}
                    </div>
                    <div className="flex items-center gap-2 pt-1">
                      <input type="number" min="1" max="62" value={genDays} onChange={e => setGenDays(e.target.value)} className="w-20 bg-card border border-foreground/10 rounded-lg px-2 py-1.5 text-foreground text-sm" />
                      <span className="text-foreground/40 text-xs">days from this week</span>
                      <button
                        onClick={() => handleGenerate(type.id)}
                        disabled={generating || orderForType(type.id).length === 0}
                        className="ml-auto bg-cyan-500 hover:bg-cyan-600 text-white px-3 py-1.5 rounded-lg text-xs font-medium disabled:opacity-40"
                      >
                        {generating ? 'Filling...' : 'Fill Duty'}
                      </button>
                    </div>
                  </div>
                )}
              </div>
            ))}
          </div>
          <form onSubmit={handleAddType} className="flex gap-3">
            <input
              type="text"
              value={newTypeName}
              onChange={e => setNewTypeName(e.target.value)}
              placeholder="New duty type, e.g. Sweeping"
              className="flex-1 bg-muted border border-foreground/10 rounded-xl px-4 py-2.5 text-foreground focus:outline-none focus:border-cyan-500/50"
            />
            <button type="submit" className="bg-cyan-500 hover:bg-cyan-600 text-white px-4 py-2 rounded-xl flex items-center gap-2">
              <Plus size={16} /> Add
            </button>
          </form>
        </div>
      )}
    </div>
  );
}

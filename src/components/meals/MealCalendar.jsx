import { PartyPopper } from 'lucide-react';

const pad = (n) => String(n).padStart(2, '0');

// Whole-month grid: one row per day, one column per member, so "ke kobe koy
// bela kheyeche" is visible at a glance. Pure view over the entries the month
// already fetched — no extra queries.
export default function MealCalendar({ members, entries, holidays, year, month, currentUserId }) {
  const daysInMonth = new Date(year, month, 0).getDate();
  const todayStr = (() => {
    const d = new Date();
    return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
  })();

  const entryMap = {}; // date -> member_id -> entry
  entries.forEach(e => {
    (entryMap[e.date] = entryMap[e.date] || {})[e.member_id] = e;
  });
  const holidayMap = {};
  holidays.forEach(h => { holidayMap[h.date] = h; });

  // Approved members plus anyone with an entry this month (left/removed)
  const activeIds = new Set(entries.map(e => e.member_id));
  const cols = members.filter(m => m.status === 'approved' || activeIds.has(m.id));

  const own = (e) => Number(e.breakfast) + Number(e.lunch) + Number(e.dinner);
  const guests = (e) => Number(e.guest_breakfast) + Number(e.guest_lunch) + Number(e.guest_dinner);

  const memberTotals = {};
  let grandTotal = 0;

  const rows = [];
  for (let day = 1; day <= daysInMonth; day++) {
    const date = `${year}-${pad(month)}-${pad(day)}`;
    const weekday = new Date(year, month - 1, day).toLocaleDateString(undefined, { weekday: 'short' });
    let dayTotal = 0;
    const cells = cols.map(m => {
      const e = entryMap[date]?.[m.id];
      const o = e ? own(e) : 0;
      const g = e ? guests(e) : 0;
      dayTotal += o + g;
      memberTotals[m.id] = (memberTotals[m.id] || 0) + o + g;
      return { key: m.id, o, g, has: !!e };
    });
    grandTotal += dayTotal;
    rows.push({ day, date, weekday, cells, dayTotal, holiday: holidayMap[date] });
  }

  return (
    <div className="space-y-4">
      <div className="bg-card border border-foreground/10 rounded-2xl overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-foreground/10 text-foreground/40 text-left">
                <th className="px-3 py-3 font-medium sticky left-0 bg-card">Date</th>
                {cols.map(m => (
                  <th key={m.id} className="px-3 py-3 font-medium text-center whitespace-nowrap">
                    {m.display_name}
                    {m.user_id === currentUserId && <span className="text-cyan-400"> •</span>}
                  </th>
                ))}
                <th className="px-3 py-3 font-medium text-right">Total</th>
              </tr>
            </thead>
            <tbody>
              {rows.map(r => (
                <tr key={r.day} className={`border-b border-foreground/5 last:border-0 ${
                  r.holiday ? 'bg-amber-500/5' : r.date === todayStr ? 'bg-cyan-500/5' : ''
                }`}>
                  <td className="px-3 py-2 whitespace-nowrap sticky left-0 bg-card">
                    <span className={r.date === todayStr ? 'text-cyan-400 font-semibold' : 'text-foreground/80'}>
                      {pad(r.day)}
                    </span>
                    <span className="text-foreground/30 text-xs ml-1.5">{r.weekday}</span>
                    {r.holiday && (
                      <span className="inline-flex items-center gap-1 text-amber-400 text-xs ml-2" title={r.holiday.title}>
                        <PartyPopper size={11} />{r.holiday.title !== 'Meal Holiday' ? r.holiday.title : ''}
                      </span>
                    )}
                  </td>
                  {r.cells.map(c => (
                    <td key={c.key} className="px-3 py-2 text-center">
                      {c.has && (c.o > 0 || c.g > 0) ? (
                        <span className="text-foreground/80">
                          {c.o > 0 ? c.o : ''}
                          {c.g > 0 && <span className="text-purple-400 text-xs"> +{c.g}</span>}
                        </span>
                      ) : c.has ? (
                        <span className="text-red-400/50 text-xs">off</span>
                      ) : (
                        <span className="text-foreground/15">—</span>
                      )}
                    </td>
                  ))}
                  <td className="px-3 py-2 text-right text-foreground/60">{r.dayTotal || ''}</td>
                </tr>
              ))}
            </tbody>
            <tfoot>
              <tr className="border-t border-foreground/10 text-foreground/80 font-semibold">
                <td className="px-3 py-3 sticky left-0 bg-card">Total</td>
                {cols.map(m => (
                  <td key={m.id} className="px-3 py-3 text-center">{memberTotals[m.id] || 0}</td>
                ))}
                <td className="px-3 py-3 text-right">{grandTotal}</td>
              </tr>
            </tfoot>
          </table>
        </div>
      </div>
      <p className="text-foreground/30 text-xs">
        Numbers are raw meal counts (breakfast + lunch + dinner); <span className="text-purple-400">+n</span> is guest meals,
        <span className="text-red-400/60"> off</span> means an entry exists with everything zero, — means no entry.
        Amber rows are holidays/feasts.
      </p>
    </div>
  );
}

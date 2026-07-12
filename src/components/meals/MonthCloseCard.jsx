import { useState } from 'react';
import { Lock, LockOpen } from 'lucide-react';

// Month close / carry-forward controls, shown on the Summary page.
// Closing snapshots every member's balance; the next month shows it as
// "Carry". A closed month is read-only until the manager reopens it.
export default function MonthCloseCard({ summary, isManager, closeMonth, reopenMonth, monthLabel }) {
  const [busy, setBusy] = useState(false);
  if (!summary) return null;

  const run = async (fn, confirmMsg) => {
    if (!confirm(confirmMsg)) return;
    setBusy(true);
    try {
      await fn();
    } catch (err) {
      console.error(err);
      alert(err.message);
    } finally {
      setBusy(false);
    }
  };

  if (summary.is_closed) {
    return (
      <div className="bg-emerald-500/10 border border-emerald-500/20 rounded-2xl p-4 flex flex-wrap items-center gap-3">
        <Lock size={18} className="text-emerald-400 shrink-0" />
        <div className="flex-1 min-w-[200px]">
          <p className="text-emerald-400 text-sm font-medium">{monthLabel} is closed</p>
          <p className="text-white/40 text-xs mt-0.5">
            Balances have been carried forward to the next month. Entries, deposits and expenses are locked.
            {summary.closed_at && ` Closed on ${new Date(summary.closed_at).toLocaleDateString()}.`}
          </p>
        </div>
        {isManager && (
          <button
            disabled={busy}
            onClick={() => run(reopenMonth,
              `Reopen ${monthLabel}? Its carry-forward is removed from the next month until you close it again.`)}
            className="flex items-center gap-2 px-4 py-2 rounded-xl bg-orange-500/10 border border-orange-500/20 text-orange-400 hover:bg-orange-500/20 text-sm disabled:opacity-50"
          >
            <LockOpen size={15} /> Reopen
          </button>
        )}
      </div>
    );
  }

  if (!isManager) return null;

  return (
    <div className="bg-[#1a1a2e] border border-white/10 rounded-2xl p-4 flex flex-wrap items-center gap-3">
      <LockOpen size={18} className="text-white/40 shrink-0" />
      <div className="flex-1 min-w-[200px]">
        <p className="text-white text-sm font-medium">Close {monthLabel}</p>
        <p className="text-white/40 text-xs mt-0.5">
          Locks this month and carries every member's balance (joma/bokeya) into the next month automatically.
        </p>
      </div>
      <button
        disabled={busy}
        onClick={() => run(() => closeMonth(),
          `Close ${monthLabel}? Member balances carry forward to the next month and this month becomes read-only. You can reopen later if needed.`)}
        className="flex items-center gap-2 px-4 py-2 rounded-xl bg-emerald-500 hover:bg-emerald-600 text-white text-sm font-medium shadow-lg shadow-emerald-500/20 disabled:opacity-50"
      >
        <Lock size={15} /> {busy ? 'Closing...' : 'Close Month'}
      </button>
    </div>
  );
}

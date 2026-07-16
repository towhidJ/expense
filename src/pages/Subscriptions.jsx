import { useMemo } from 'react';
import { Link } from 'react-router';
import { useRecurring } from '../hooks/useRecurring';
import StatCard from '../components/StatCard';
import { Tv, CalendarClock, Wallet, PauseCircle, PlayCircle } from 'lucide-react';

const fmt = (n) => `৳${Math.round(Number(n || 0)).toLocaleString()}`;
const MONTHLY_FACTOR = { daily: 30.44, weekly: 4.35, monthly: 1, yearly: 1 / 12 };

export default function Subscriptions() {
  const { recurring, loading, updateRecurring } = useRecurring();

  const subs = useMemo(
    () => recurring.filter(r => r.is_subscription && r.type === 'expense'),
    [recurring]
  );

  const totals = useMemo(() => {
    const active = subs.filter(s => s.is_active);
    const monthly = active.reduce((s, r) => s + Number(r.amount) * (MONTHLY_FACTOR[r.frequency] || 1), 0);
    return { monthly, yearly: monthly * 12, active: active.length, paused: subs.length - active.length };
  }, [subs]);

  const togglePause = async (sub) => {
    try {
      await updateRecurring(sub.id, { is_active: !sub.is_active });
    } catch (err) {
      alert('Error updating subscription: ' + err.message);
    }
  };

  if (loading) return <div className="text-white/50 p-6">Loading subscriptions...</div>;

  return (
    <div className="space-y-6 animate-in">
      <div>
        <h1 className="text-2xl font-bold text-white">Subscriptions</h1>
        <p className="text-white/40 text-sm mt-1">
          Recurring services you pay for. Mark items as "Subscription" on the{' '}
          <Link to="/recurring" className="text-cyan-400 hover:underline">Recurring page</Link> to see them here.
        </p>
      </div>

      <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
        <StatCard title="Monthly Cost" value={fmt(totals.monthly)} icon={Wallet} gradient={["#f87171", "#ef4444"]} iconBg="bg-red-500/10" />
        <StatCard title="Yearly Cost" value={fmt(totals.yearly)} icon={CalendarClock} gradient={["#f59e0b", "#d97706"]} iconBg="bg-amber-500/10" />
        <StatCard title="Active / Paused" value={`${totals.active} / ${totals.paused}`} icon={Tv} gradient={["#22d3ee", "#06b6d4"]} iconBg="bg-cyan-500/10" />
      </div>

      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
        {subs.map(sub => {
          const monthly = Number(sub.amount) * (MONTHLY_FACTOR[sub.frequency] || 1);
          return (
            <div key={sub.id} className={`bg-[#1a1a2e] border rounded-2xl p-5 transition-all ${sub.is_active ? 'border-white/10 hover:border-white/20' : 'border-white/5 opacity-60'}`}>
              <div className="flex justify-between items-start mb-3">
                <div>
                  <h3 className="text-white font-medium">{sub.title}</h3>
                  <p className="text-white/40 text-xs capitalize mt-0.5">
                    {sub.categories?.icon} {sub.categories?.name} · {sub.frequency}
                  </p>
                </div>
                <span className={`px-2 py-0.5 rounded text-[10px] font-bold ${sub.is_active ? 'bg-emerald-500/20 text-emerald-400' : 'bg-white/10 text-white/40'}`}>
                  {sub.is_active ? 'ACTIVE' : 'PAUSED'}
                </span>
              </div>
              <div className="flex items-end justify-between">
                <div>
                  <p className="text-xl font-bold text-white">{fmt(sub.amount)}<span className="text-xs text-white/40 font-normal"> /{sub.frequency.replace('ly', '')}</span></p>
                  {sub.frequency !== 'monthly' && <p className="text-xs text-white/40">≈ {fmt(monthly)}/month</p>}
                  <p className="text-xs text-white/35 mt-1.5">
                    Next charge: {sub.is_active ? new Date(sub.next_run_date).toLocaleDateString() : '—'}
                  </p>
                </div>
                <button
                  onClick={() => togglePause(sub)}
                  title={sub.is_active ? 'Pause — stops auto-charging' : 'Resume'}
                  className={`flex items-center gap-1.5 text-xs px-3 py-2 rounded-xl font-medium transition-all ${
                    sub.is_active
                      ? 'bg-white/5 text-white/60 hover:bg-amber-500/10 hover:text-amber-400'
                      : 'bg-emerald-500/10 text-emerald-400 hover:bg-emerald-500/20'
                  }`}
                >
                  {sub.is_active ? <><PauseCircle size={14} /> Pause</> : <><PlayCircle size={14} /> Resume</>}
                </button>
              </div>
              {!sub.is_active && (
                <p className="text-[11px] text-emerald-400/70 mt-3 pt-3 border-t border-white/5">
                  Saving {fmt(monthly)}/month while paused 🎉
                </p>
              )}
            </div>
          );
        })}
      </div>

      {subs.length === 0 && (
        <div className="text-center py-12 border border-white/5 rounded-2xl bg-white/[0.02]">
          <Tv className="mx-auto text-white/20 mb-4" size={48} />
          <h3 className="text-white/60 font-medium">No subscriptions yet</h3>
          <p className="text-white/40 text-sm mt-1">
            On the <Link to="/recurring" className="text-cyan-400 hover:underline">Recurring page</Link>, tick "Subscription" on items like Netflix, hosting, or internet bills.
          </p>
        </div>
      )}
    </div>
  );
}

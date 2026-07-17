import { useEffect } from 'react';
import { useNavigate } from 'react-router';
import { useFinanceNotifications } from '../hooks/useFinanceNotifications';
import { AlertTriangle, CalendarClock, Trash2, Bell, Repeat, PieChart, Target, TrendingUp, Home } from 'lucide-react';

const TYPE_ICONS = {
  budget_overspend: AlertTriangle,
  bill_due: CalendarClock,
  recurring_posted: Repeat,
  weekly_digest: PieChart,
  goal_milestone: Target,
  large_expense: TrendingUp,
  rent_due: Home,
};

const TYPE_COLORS = {
  budget_overspend: 'bg-red-500/15 text-red-400',
  bill_due: 'bg-orange-500/15 text-orange-400',
  recurring_posted: 'bg-cyan-500/15 text-cyan-400',
  weekly_digest: 'bg-purple-500/15 text-purple-400',
  goal_milestone: 'bg-emerald-500/15 text-emerald-400',
  large_expense: 'bg-red-500/15 text-red-400',
  rent_due: 'bg-teal-500/15 text-teal-400',
};

function timeAgo(ts) {
  const mins = Math.floor((Date.now() - new Date(ts).getTime()) / 60000);
  if (mins < 1) return 'just now';
  if (mins < 60) return `${mins}m ago`;
  const hours = Math.floor(mins / 60);
  if (hours < 24) return `${hours}h ago`;
  const days = Math.floor(hours / 24);
  if (days < 7) return `${days}d ago`;
  return new Date(ts).toLocaleDateString(undefined, { day: 'numeric', month: 'short' });
}

// Budget overspend / bill-due alerts (v28) — server-generated daily, same
// fan-out that drives the mobile push notification.
export default function Alerts() {
  const { notifications, loading, markAllRead, deleteNotification } = useFinanceNotifications();
  const navigate = useNavigate();
  const unread = notifications.filter(n => !n.is_read).length;

  useEffect(() => {
    if (unread > 0) markAllRead().catch(err => console.error(err));
    // run once when the page opens with unread items
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const handleDelete = async (e, id) => {
    e.stopPropagation();
    try {
      await deleteNotification(id);
    } catch (err) {
      console.error(err);
      alert(err.message);
    }
  };

  if (loading && notifications.length === 0) return <div className="text-white/50 p-6">Loading...</div>;

  return (
    <div className="space-y-6 animate-in">
      <div>
        <h1 className="text-2xl font-bold text-white">Alerts</h1>
        <p className="text-white/40 text-sm mt-1">Budget overspend and upcoming bill reminders.</p>
      </div>

      <div className="bg-[#1a1a2e] border border-white/10 rounded-2xl overflow-hidden">
        <div className="divide-y divide-white/5">
          {notifications.map(n => {
            const Icon = TYPE_ICONS[n.type] || Bell;
            return (
              <div key={n.id}
                onClick={() => n.link && navigate(n.link)}
                className={`px-5 py-4 flex items-start gap-3 ${n.link ? 'cursor-pointer hover:bg-white/[0.03]' : ''} ${!n.is_read ? 'bg-cyan-500/[0.04]' : ''}`}>
                <div className={`w-9 h-9 rounded-xl flex items-center justify-center shrink-0 ${
                  TYPE_COLORS[n.type] || 'bg-orange-500/15 text-orange-400'
                }`}>
                  <Icon size={16} />
                </div>
                <div className="flex-1 min-w-0">
                  <p className={`text-sm ${!n.is_read ? 'text-white font-medium' : 'text-white/70'}`}>{n.title}</p>
                  {n.body && <p className="text-white/40 text-xs mt-0.5">{n.body}</p>}
                  <p className="text-white/25 text-xs mt-1">{timeAgo(n.created_at)}</p>
                </div>
                <button onClick={(e) => handleDelete(e, n.id)}
                  className="p-1.5 rounded-lg text-white/20 hover:text-red-400 hover:bg-white/5 shrink-0">
                  <Trash2 size={14} />
                </button>
              </div>
            );
          })}
          {notifications.length === 0 && (
            <p className="px-5 py-10 text-center text-white/40 text-sm">
              Nothing yet — budget overspend and bill-due reminders show up here (checked daily).
            </p>
          )}
        </div>
      </div>
    </div>
  );
}

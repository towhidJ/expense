import { useEffect } from 'react';
import { useNavigate } from 'react-router';
import { Bell, CalendarClock, Megaphone, UserPlus, Check, Trash2 } from 'lucide-react';

const TYPE_ICONS = {
  request_new: CalendarClock,
  request_response: Check,
  notice: Megaphone,
  join_request: UserPlus
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

// In-app notification feed, filled by DB triggers (new request, response,
// notice, join request). Opening the page marks everything read. When FCM
// push lands later it will fan out from the same table.
export default function NotificationsList({ notifications, markNotificationsRead, deleteNotification }) {
  const navigate = useNavigate();
  const unread = notifications.filter(n => !n.is_read).length;

  useEffect(() => {
    if (unread > 0) {
      markNotificationsRead().catch(err => console.error(err));
    }
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

  return (
    <div className="space-y-4">
      <div className="bg-card border border-foreground/10 rounded-2xl overflow-hidden">
        <div className="divide-y divide-foreground/5">
          {notifications.map(n => {
            const Icon = TYPE_ICONS[n.type] || Bell;
            return (
              <div key={n.id}
                onClick={() => n.link && navigate(n.link)}
                className={`px-5 py-4 flex items-start gap-3 ${n.link ? 'cursor-pointer hover:bg-white/[0.03]' : ''} ${
                  !n.is_read ? 'bg-cyan-500/[0.04]' : ''
                }`}>
                <div className={`w-9 h-9 rounded-xl flex items-center justify-center shrink-0 ${
                  !n.is_read ? 'bg-cyan-500/15 text-cyan-400' : 'bg-foreground/5 text-white/40'
                }`}>
                  <Icon size={16} />
                </div>
                <div className="flex-1 min-w-0">
                  <p className={`text-sm ${!n.is_read ? 'text-foreground font-medium' : 'text-foreground/70'}`}>{n.title}</p>
                  {n.body && <p className="text-foreground/40 text-xs mt-0.5">{n.body}</p>}
                  <p className="text-foreground/25 text-xs mt-1">{timeAgo(n.created_at)}</p>
                </div>
                <button onClick={(e) => handleDelete(e, n.id)}
                  className="p-1.5 rounded-lg text-foreground/20 hover:text-red-400 hover:bg-foreground/5 shrink-0">
                  <Trash2 size={14} />
                </button>
              </div>
            );
          })}
          {notifications.length === 0 && (
            <p className="px-5 py-10 text-center text-foreground/40 text-sm">Nothing yet — you'll see requests, notices and join alerts here.</p>
          )}
        </div>
      </div>
    </div>
  );
}

import { Check, X, UserMinus, LogOut, Crown, User } from 'lucide-react';

export default function MembersTab({
  members, isManager, currentUserId,
  respondJoinRequest, removeMember, setMemberRole, onLeave
}) {
  const pending = members.filter(m => m.status === 'pending');
  const approved = members.filter(m => m.status === 'approved');

  return (
    <div className="space-y-6">
      {pending.length > 0 && isManager && (
        <div className="bg-card border border-orange-500/20 rounded-2xl p-6">
          <h3 className="text-foreground font-semibold mb-4">Pending Requests ({pending.length})</h3>
          <div className="space-y-2">
            {pending.map(m => (
              <div key={m.id} className="flex items-center gap-3 bg-muted border border-foreground/10 rounded-xl px-4 py-3">
                <div className="w-9 h-9 rounded-full bg-orange-500/10 text-orange-400 flex items-center justify-center shrink-0">
                  <User size={16} />
                </div>
                <span className="flex-1 text-foreground text-sm font-medium">{m.display_name}</span>
                <button
                  onClick={() => respondJoinRequest(m.id, true).catch(err => alert(err.message))}
                  className="flex items-center gap-1.5 bg-emerald-500 hover:bg-emerald-600 text-white text-sm px-3 py-1.5 rounded-lg"
                >
                  <Check size={14} /> Approve
                </button>
                <button
                  onClick={() => respondJoinRequest(m.id, false).catch(err => alert(err.message))}
                  className="flex items-center gap-1.5 bg-red-500/20 hover:bg-red-500/30 text-red-400 text-sm px-3 py-1.5 rounded-lg"
                >
                  <X size={14} /> Reject
                </button>
              </div>
            ))}
          </div>
        </div>
      )}

      <div className="bg-card border border-foreground/10 rounded-2xl p-6">
        <h3 className="text-foreground font-semibold mb-4">Members ({approved.length})</h3>
        <div className="space-y-2">
          {approved.map(m => (
            <div key={m.id} className="flex flex-wrap items-center gap-3 bg-muted border border-foreground/10 rounded-xl px-4 py-3">
              <div className={`w-9 h-9 rounded-full flex items-center justify-center shrink-0 ${m.role === 'manager' ? 'bg-gradient-to-br from-cyan-500 to-purple-600 text-white' : 'bg-foreground/5 text-white/60'}`}>
                {m.role === 'manager' ? <Crown size={16} /> : <User size={16} />}
              </div>
              <div className="flex-1 min-w-0">
                <p className="text-foreground text-sm font-medium truncate">
                  {m.display_name}
                  {m.user_id === currentUserId && <span className="text-cyan-400 text-xs ml-1">(you)</span>}
                </p>
                <p className="text-foreground/40 text-xs capitalize">{m.role}</p>
              </div>
              {isManager && m.user_id !== currentUserId && (
                <div className="flex gap-2">
                  <button
                    onClick={() => setMemberRole(m.id, m.role === 'manager' ? 'member' : 'manager').catch(err => alert(err.message))}
                    className="text-xs px-3 py-1.5 rounded-lg bg-foreground/5 border border-foreground/10 text-foreground/60 hover:text-foreground"
                  >
                    {m.role === 'manager' ? 'Demote' : 'Make Manager'}
                  </button>
                  {m.role !== 'manager' && (
                    <button
                      onClick={() => { if (confirm(`Remove "${m.display_name}" from the group? Their past records stay in old months.`)) removeMember(m.id).catch(err => alert(err.message)); }}
                      className="flex items-center gap-1.5 text-xs px-3 py-1.5 rounded-lg bg-red-500/10 border border-red-500/20 text-red-400 hover:bg-red-500/20"
                    >
                      <UserMinus size={13} /> Remove
                    </button>
                  )}
                </div>
              )}
            </div>
          ))}
        </div>
      </div>

      <div className="flex justify-end">
        <button
          onClick={() => { if (confirm('Leave this meal group?')) onLeave(); }}
          className="flex items-center gap-2 text-red-400 hover:text-red-300 text-sm px-4 py-2 rounded-xl border border-red-500/20 hover:bg-red-500/10 transition-colors"
        >
          <LogOut size={16} /> Leave Group
        </button>
      </div>
    </div>
  );
}

import { useState, useEffect, useCallback } from 'react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../context/AuthContext';
import { useEntity } from '../context/EntityContext';
import { History, PlusCircle, PencilLine, MinusCircle } from 'lucide-react';

const PAGE = 50;
const ACTION_META = {
  created: { icon: PlusCircle, color: 'text-emerald-400', bg: 'bg-emerald-500/10' },
  updated: { icon: PencilLine, color: 'text-cyan-400', bg: 'bg-cyan-500/10' },
  deleted: { icon: MinusCircle, color: 'text-red-400', bg: 'bg-red-500/10' }
};
const TABLE_LABEL = {
  transactions: 'Transaction', transfers: 'Transfer', liabilities: 'Liability', accounts: 'Account'
};

export default function Activity() {
  const { user } = useAuth();
  const { currentEntity } = useEntity();
  const [logs, setLogs] = useState([]);
  const [loading, setLoading] = useState(true);
  const [hasMore, setHasMore] = useState(false);
  const [filter, setFilter] = useState('all');

  const fetchLogs = useCallback(async (offset = 0) => {
    if (!user || !currentEntity) return;
    if (offset === 0) setLoading(true);
    let query = supabase
      .from('activity_log')
      .select('*')
      .eq('user_id', user.id)
      .eq('entity_id', currentEntity.id)
      .order('created_at', { ascending: false })
      .range(offset, offset + PAGE - 1);
    if (filter !== 'all') query = query.eq('table_name', filter);
    const { data, error } = await query;
    if (error) console.error('Error fetching activity:', error);
    else {
      setLogs(prev => offset === 0 ? (data || []) : [...prev, ...(data || [])]);
      setHasMore((data || []).length === PAGE);
    }
    setLoading(false);
  }, [user, currentEntity, filter]);

  useEffect(() => {
    fetchLogs(0);
  }, [fetchLogs]);

  // group by day for the timeline
  const byDay = logs.reduce((acc, log) => {
    const day = new Date(log.created_at).toLocaleDateString('en-US', { weekday: 'short', day: 'numeric', month: 'long', year: 'numeric' });
    (acc[day] = acc[day] || []).push(log);
    return acc;
  }, {});

  if (loading) return <div className="text-foreground/50 p-6">Loading activity...</div>;

  return (
    <div className="space-y-6 animate-in max-w-3xl">
      <div>
        <h1 className="text-2xl font-bold text-foreground">Activity Log</h1>
        <p className="text-foreground/40 text-sm mt-1">Everything that happened in this workspace — recorded automatically by the database.</p>
      </div>

      <div className="flex gap-2 flex-wrap">
        {['all', 'transactions', 'transfers', 'liabilities', 'accounts'].map(f => (
          <button
            key={f}
            onClick={() => setFilter(f)}
            className={`px-3.5 py-2 rounded-xl text-sm font-medium capitalize transition-all border ${
              filter === f ? 'bg-cyan-500/20 text-cyan-400 border-cyan-500/40' : 'bg-foreground/5 text-white/40 border-foreground/10 hover:bg-foreground/10'
            }`}
          >
            {f}
          </button>
        ))}
      </div>

      {Object.entries(byDay).map(([day, dayLogs]) => (
        <div key={day}>
          <p className="text-xs uppercase tracking-wider text-foreground/30 mb-2 px-1">{day}</p>
          <div className="bg-card border border-foreground/10 rounded-2xl divide-y divide-foreground/5 overflow-hidden">
            {dayLogs.map(log => {
              const meta = ACTION_META[log.action] || ACTION_META.updated;
              const Icon = meta.icon;
              return (
                <div key={log.id} className="flex items-center gap-3 px-4 py-3">
                  <div className={`w-8 h-8 rounded-full ${meta.bg} flex items-center justify-center shrink-0`}>
                    <Icon size={15} className={meta.color} />
                  </div>
                  <div className="flex-1 min-w-0">
                    <p className="text-sm text-foreground/80 truncate">{log.summary || log.table_name}</p>
                    <p className="text-xs text-foreground/35">
                      {TABLE_LABEL[log.table_name] || log.table_name} {log.action} · {new Date(log.created_at).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                    </p>
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      ))}

      {hasMore && (
        <button onClick={() => fetchLogs(logs.length)} className="w-full py-3 rounded-xl bg-foreground/5 hover:bg-foreground/10 text-foreground/60 text-sm font-medium transition-all">
          Load more
        </button>
      )}

      {logs.length === 0 && (
        <div className="text-center py-12 border border-foreground/5 rounded-2xl bg-white/[0.02]">
          <History className="mx-auto text-foreground/20 mb-4" size={48} />
          <h3 className="text-foreground/60 font-medium">No activity recorded yet</h3>
          <p className="text-foreground/40 text-sm mt-1">New transactions, transfers, loans and account changes will show up here (requires migration v35).</p>
        </div>
      )}
    </div>
  );
}

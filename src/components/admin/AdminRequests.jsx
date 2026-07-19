import { useEffect, useState } from 'react';
import { supabase } from '../../lib/supabase';
import { Loader2, Check, X, Copy, Clock, CheckCircle2, XCircle } from 'lucide-react';

const STATUS_META = {
  pending: { icon: Clock, cls: 'bg-amber-500/15 text-amber-400', label: 'Pending' },
  approved: { icon: CheckCircle2, cls: 'bg-emerald-500/15 text-emerald-400', label: 'Approved' },
  rejected: { icon: XCircle, cls: 'bg-red-500/15 text-red-400', label: 'Rejected' }
};

const fmtDate = (d) =>
  new Date(d).toLocaleString('en-GB', { day: '2-digit', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' });

// Manual bKash/Nagad payment verification queue. Approve/reject goes through
// the review_subscription_request RPC (locks the row, activates/extends the
// subscription, notifies the user).
export default function AdminRequests({ onCountChange }) {
  const [requests, setRequests] = useState(null);
  const [filter, setFilter] = useState('pending');
  const [busyId, setBusyId] = useState(null);
  const [rejecting, setRejecting] = useState(null); // request being rejected
  const [reason, setReason] = useState('');

  const fetchRequests = async () => {
    const { data, error } = await supabase
      .from('subscription_requests')
      .select('*, profiles!subscription_requests_user_id_fkey(full_name)')
      .order('created_at', { ascending: false });
    if (error) { alert('Load failed: ' + error.message); return; }
    setRequests(data || []);
    onCountChange?.((data || []).filter(r => r.status === 'pending').length);
  };

  useEffect(() => { fetchRequests(); }, []); // eslint-disable-line react-hooks/exhaustive-deps

  const review = async (req, approve, rejectReason = null) => {
    setBusyId(req.id);
    const { error } = await supabase.rpc('review_subscription_request', {
      p_request_id: req.id,
      p_approve: approve,
      p_reason: rejectReason
    });
    if (error) alert('Review failed: ' + error.message);
    setRejecting(null);
    setReason('');
    await fetchRequests();
    setBusyId(null);
  };

  const copy = (text) => navigator.clipboard?.writeText(text);

  if (!requests) {
    return <div className="p-8 text-center text-foreground/40"><Loader2 className="w-5 h-5 animate-spin mx-auto" /></div>;
  }

  const shown = filter === 'all' ? requests : requests.filter(r => r.status === filter);

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap gap-2">
        {['pending', 'approved', 'rejected', 'all'].map(f => (
          <button
            key={f}
            onClick={() => setFilter(f)}
            className={`px-4 py-2 rounded-xl text-sm capitalize transition-all ${
              filter === f
                ? 'bg-gradient-to-r from-cyan-500/20 to-purple-600/20 text-cyan-400 border border-cyan-500/20'
                : 'bg-foreground/5 text-foreground/50 border border-foreground/10 hover:text-foreground'
            }`}
          >
            {f}
            {f === 'pending' && requests.some(r => r.status === 'pending') && (
              <span className="ml-2 text-[11px] bg-amber-500/20 text-amber-400 px-1.5 py-0.5 rounded-full">
                {requests.filter(r => r.status === 'pending').length}
              </span>
            )}
          </button>
        ))}
      </div>

      {shown.length === 0 ? (
        <p className="p-10 text-center text-sm text-foreground/40 bg-foreground/5 border border-foreground/10 rounded-2xl">
          No {filter === 'all' ? '' : filter} requests.
        </p>
      ) : (
        <div className="space-y-3">
          {shown.map(r => {
            const meta = STATUS_META[r.status];
            const StatusIcon = meta.icon;
            const amountMismatch = r.amount != null && r.expected_amount != null &&
              Number(r.amount) !== Number(r.expected_amount);
            return (
              <div key={r.id} className="bg-foreground/5 border border-foreground/10 rounded-2xl p-5 space-y-3">
                <div className="flex flex-wrap items-center gap-2">
                  <span className="text-sm text-foreground font-medium">{r.profiles?.full_name || 'Unknown user'}</span>
                  <span className={`flex items-center gap-1 text-[11px] px-2 py-0.5 rounded-full ${meta.cls}`}>
                    <StatusIcon className="w-3 h-3" /> {meta.label}
                  </span>
                  <span className="text-[11px] uppercase tracking-wide bg-purple-500/15 text-purple-300 px-2 py-0.5 rounded-full">{r.duration}</span>
                  <span className={`text-[11px] uppercase tracking-wide px-2 py-0.5 rounded-full ${
                    r.method === 'bkash' ? 'bg-pink-500/15 text-pink-400' : 'bg-orange-500/15 text-orange-400'
                  }`}>{r.method}</span>
                  <span className="text-xs text-foreground/30 ml-auto">{fmtDate(r.created_at)}</span>
                </div>

                <div className="grid grid-cols-1 sm:grid-cols-3 gap-3 text-sm">
                  <div className="bg-foreground/5 rounded-xl px-3 py-2">
                    <p className="text-[11px] text-foreground/40 mb-0.5">Transaction ID</p>
                    <p className="text-foreground font-mono flex items-center gap-2">
                      <span className="truncate">{r.trx_id}</span>
                      <button onClick={() => copy(r.trx_id)} className="text-foreground/40 hover:text-cyan-400 shrink-0" title="Copy">
                        <Copy className="w-3.5 h-3.5" />
                      </button>
                    </p>
                  </div>
                  <div className="bg-foreground/5 rounded-xl px-3 py-2">
                    <p className="text-[11px] text-foreground/40 mb-0.5">Sender number</p>
                    <p className="text-foreground font-mono">{r.sender_number}</p>
                  </div>
                  <div className={`rounded-xl px-3 py-2 ${amountMismatch ? 'bg-amber-500/10 border border-amber-500/25' : 'bg-foreground/5'}`}>
                    <p className="text-[11px] text-foreground/40 mb-0.5">Amount (claimed / expected)</p>
                    <p className={amountMismatch ? 'text-amber-400 font-medium' : 'text-foreground'}>
                      ৳{r.amount ?? '—'} / ৳{r.expected_amount ?? '—'}
                      {amountMismatch && <span className="text-[11px] ml-2">mismatch!</span>}
                    </p>
                  </div>
                </div>

                {r.status === 'rejected' && r.reject_reason && (
                  <p className="text-xs text-red-400/80">Reason: {r.reject_reason}</p>
                )}

                {r.status === 'pending' && (
                  rejecting?.id === r.id ? (
                    <div className="flex flex-col sm:flex-row gap-2">
                      <input
                        type="text"
                        autoFocus
                        placeholder="Reject reason (shown to the user)…"
                        value={reason}
                        onChange={e => setReason(e.target.value)}
                        className="flex-1 bg-foreground/5 border border-foreground/10 rounded-xl px-4 py-2.5 text-foreground text-sm focus:outline-none focus:border-red-500/50"
                      />
                      <div className="flex gap-2">
                        <button
                          onClick={() => review(r, false, reason.trim() || null)}
                          disabled={busyId === r.id}
                          className="flex-1 sm:flex-none px-5 py-2.5 rounded-xl bg-red-500 hover:bg-red-600 text-white text-sm font-semibold transition-all disabled:opacity-50"
                        >
                          {busyId === r.id ? <Loader2 className="w-4 h-4 animate-spin mx-auto" /> : 'Confirm reject'}
                        </button>
                        <button
                          onClick={() => { setRejecting(null); setReason(''); }}
                          className="px-4 py-2.5 rounded-xl bg-foreground/5 border border-foreground/10 text-foreground/50 text-sm hover:text-foreground transition-all"
                        >
                          Cancel
                        </button>
                      </div>
                    </div>
                  ) : (
                    <div className="flex gap-2">
                      <button
                        onClick={() => review(r, true)}
                        disabled={busyId === r.id}
                        className="flex items-center gap-2 px-5 py-2.5 rounded-xl bg-emerald-500 hover:bg-emerald-600 text-white text-sm font-semibold transition-all disabled:opacity-50"
                      >
                        {busyId === r.id ? <Loader2 className="w-4 h-4 animate-spin" /> : <Check className="w-4 h-4" />}
                        Approve
                      </button>
                      <button
                        onClick={() => { setRejecting(r); setReason(''); }}
                        disabled={busyId === r.id}
                        className="flex items-center gap-2 px-5 py-2.5 rounded-xl bg-foreground/5 border border-red-500/25 text-red-400 text-sm font-semibold hover:bg-red-500/10 transition-all disabled:opacity-50"
                      >
                        <X className="w-4 h-4" /> Reject
                      </button>
                    </div>
                  )
                )}
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}

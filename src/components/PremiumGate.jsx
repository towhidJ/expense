import { useEffect, useState } from 'react';
import { supabase } from '../lib/supabase';
import { useSubscription } from '../context/SubscriptionContext';
import { MODULES } from '../lib/modules';
import {
  Crown, Copy, Check, Loader2, Clock, CheckCircle2, XCircle, ChevronDown, Send
} from 'lucide-react';

const DURATION_META = {
  monthly: { label: 'Monthly', per: '/month' },
  yearly: { label: 'Yearly', per: '/year' },
  lifetime: { label: 'Lifetime', per: 'one-time' }
};

const fmtDate = (d) =>
  new Date(d).toLocaleString('en-GB', { day: '2-digit', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' });

// Route wrapper: renders children when the module is free / user is premium /
// admin; otherwise shows the paywall with payment instructions + the manual
// bKash/Nagad request form. Gating is UX-only (see SubscriptionContext).
export default function PremiumGate({ module, children }) {
  const { isModuleLocked } = useSubscription();
  if (!isModuleLocked(module)) return children;
  return <Paywall module={module} />;
}

// Also used standalone for sub-module gating (e.g. individual report
// statements inside /reports) — pass labelOverride for keys not in MODULES.
export function Paywall({ module, labelOverride }) {
  const { billing, refresh } = useSubscription();
  const label = labelOverride || MODULES.find(m => m.key === module)?.label || module;

  const [requests, setRequests] = useState(null);
  const [historyOpen, setHistoryOpen] = useState(false);
  const [copied, setCopied] = useState('');

  // form state
  const [duration, setDuration] = useState(null);
  const [method, setMethod] = useState('bkash');
  const [trxId, setTrxId] = useState('');
  const [sender, setSender] = useState('');
  const [amount, setAmount] = useState('');
  const [submitting, setSubmitting] = useState(false);

  const durations = ['monthly', 'yearly', 'lifetime']
    .filter(d => billing?.[`${d}_enabled`])
    .map(d => ({ key: d, price: billing[`${d}_price`], ...DURATION_META[d] }));

  const fetchRequests = async () => {
    const { data } = await supabase
      .from('subscription_requests')
      .select('*')
      .order('created_at', { ascending: false });
    setRequests(data || []);
  };

  useEffect(() => { fetchRequests(); }, []);

  // Preselect the first enabled duration once billing is loaded.
  useEffect(() => {
    if (!duration && durations.length > 0) {
      setDuration(durations[0].key);
      setAmount(String(durations[0].price ?? ''));
    }
  }, [durations.length]); // eslint-disable-line react-hooks/exhaustive-deps

  const pending = requests?.find(r => r.status === 'pending');

  const pickDuration = (d) => {
    setDuration(d.key);
    setAmount(String(d.price ?? ''));
  };

  const copy = (text, tag) => {
    navigator.clipboard?.writeText(text);
    setCopied(tag);
    setTimeout(() => setCopied(''), 1500);
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setSubmitting(true);
    try {
      const { error } = await supabase.rpc('submit_subscription_request', {
        p_duration: duration,
        p_method: method,
        p_trx_id: trxId.trim(),
        p_sender_number: sender.trim(),
        p_amount: amount === '' ? null : Number(amount)
      });
      if (error) throw error;
      setTrxId('');
      setSender('');
      await fetchRequests();
      await refresh(); // in case an admin already approved something
      alert('Request submitted! You will be notified once the payment is verified.');
    } catch (err) {
      alert(err.message);
    }
    setSubmitting(false);
  };

  const payNumbers = [
    billing?.bkash_number && { id: 'bkash', label: 'bKash', number: billing.bkash_number, type: billing.bkash_account_type, cls: 'text-pink-400 bg-pink-500/10 border-pink-500/20' },
    billing?.nagad_number && { id: 'nagad', label: 'Nagad', number: billing.nagad_number, type: billing.nagad_account_type, cls: 'text-orange-400 bg-orange-500/10 border-orange-500/20' }
  ].filter(Boolean);

  return (
    <div className="max-w-2xl mx-auto space-y-6">
      {/* Header */}
      <div className="text-center bg-gradient-to-b from-amber-500/10 to-transparent border border-amber-500/20 rounded-2xl p-8">
        <div className="w-14 h-14 rounded-2xl bg-amber-500/15 flex items-center justify-center mx-auto mb-4">
          <Crown className="w-7 h-7 text-amber-400" />
        </div>
        <h1 className="text-xl font-bold text-white">{label} is a Premium module</h1>
        <p className="text-sm text-white/50 mt-2">
          Subscribe once and unlock every Premium module in TakaKhata.
        </p>
      </div>

      {pending ? (
        /* Waiting card replaces the whole flow */
        <div className="bg-white/5 border border-amber-500/25 rounded-2xl p-6 text-center space-y-2">
          <Clock className="w-8 h-8 text-amber-400 mx-auto" />
          <h2 className="text-white font-semibold">Waiting for verification</h2>
          <p className="text-sm text-white/50">
            Your {DURATION_META[pending.duration]?.label.toLowerCase()} request ({pending.method}, trx{' '}
            <span className="font-mono text-white/70">{pending.trx_id}</span>) was submitted{' '}
            {fmtDate(pending.created_at)}. The admin will verify the payment shortly — you'll get a
            notification when it's approved.
          </p>
        </div>
      ) : (
        <>
          {/* Pricing */}
          {durations.length > 0 && (
            <div className={`grid gap-3 ${durations.length === 1 ? 'grid-cols-1' : durations.length === 2 ? 'grid-cols-2' : 'grid-cols-1 sm:grid-cols-3'}`}>
              {durations.map(d => (
                <button
                  key={d.key}
                  onClick={() => pickDuration(d)}
                  className={`rounded-2xl p-5 text-center border transition-all ${
                    duration === d.key
                      ? 'bg-gradient-to-b from-amber-500/15 to-transparent border-amber-500/40'
                      : 'bg-white/5 border-white/10 hover:border-white/25'
                  }`}
                >
                  <p className="text-sm text-white/50">{d.label}</p>
                  <p className="text-2xl font-bold text-white mt-1">৳{Number(d.price).toLocaleString()}</p>
                  <p className="text-xs text-white/30 mt-0.5">{d.per}</p>
                </button>
              ))}
            </div>
          )}

          {/* Payment instructions */}
          <div className="bg-white/5 border border-white/10 rounded-2xl p-6 space-y-4">
            <h2 className="text-white font-semibold">1. Send the money</h2>
            {payNumbers.length === 0 ? (
              <p className="text-sm text-amber-400">
                Payment numbers are not configured yet — please contact the admin.
              </p>
            ) : (
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                {payNumbers.map(p => (
                  <div key={p.id} className={`rounded-xl border px-4 py-3 ${p.cls}`}>
                    <p className="text-xs opacity-80">{p.label} ({p.type})</p>
                    <p className="font-mono text-lg text-white flex items-center gap-2 mt-0.5">
                      {p.number}
                      <button onClick={() => copy(p.number, p.id)} className="opacity-60 hover:opacity-100" title="Copy">
                        {copied === p.id ? <Check className="w-4 h-4" /> : <Copy className="w-4 h-4" />}
                      </button>
                    </p>
                  </div>
                ))}
              </div>
            )}
            {billing?.instructions && (
              <p className="text-sm text-white/50 whitespace-pre-line bg-white/5 rounded-xl px-4 py-3">{billing.instructions}</p>
            )}
          </div>

          {/* Request form */}
          <form onSubmit={handleSubmit} className="bg-white/5 border border-white/10 rounded-2xl p-6 space-y-4">
            <h2 className="text-white font-semibold">2. Submit the transaction ID</h2>
            <div className="flex gap-2">
              {['bkash', 'nagad'].map(m => (
                <button
                  key={m}
                  type="button"
                  onClick={() => setMethod(m)}
                  className={`px-5 py-2.5 rounded-xl text-sm capitalize border transition-all ${
                    method === m
                      ? m === 'bkash'
                        ? 'bg-pink-500/15 border-pink-500/40 text-pink-400'
                        : 'bg-orange-500/15 border-orange-500/40 text-orange-400'
                      : 'bg-white/5 border-white/10 text-white/50 hover:text-white'
                  }`}
                >
                  {m === 'bkash' ? 'bKash' : 'Nagad'}
                </button>
              ))}
            </div>
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <div>
                <label className="block text-sm text-white/50 mb-1.5">Transaction ID</label>
                <input
                  type="text"
                  required
                  placeholder="e.g. 9HK7A2B3C4"
                  value={trxId}
                  onChange={e => setTrxId(e.target.value)}
                  className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-2.5 text-white text-sm font-mono focus:outline-none focus:border-amber-500/50"
                />
              </div>
              <div>
                <label className="block text-sm text-white/50 mb-1.5">Number you paid from</label>
                <input
                  type="tel"
                  required
                  placeholder="01XXXXXXXXX"
                  value={sender}
                  onChange={e => setSender(e.target.value)}
                  className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-2.5 text-white text-sm font-mono focus:outline-none focus:border-amber-500/50"
                />
              </div>
            </div>
            <div>
              <label className="block text-sm text-white/50 mb-1.5">Amount sent (৳)</label>
              <input
                type="number"
                min="0"
                value={amount}
                onChange={e => setAmount(e.target.value)}
                className="w-full sm:w-48 bg-white/5 border border-white/10 rounded-xl px-4 py-2.5 text-white text-sm focus:outline-none focus:border-amber-500/50"
              />
            </div>
            <button
              type="submit"
              disabled={submitting || !duration || durations.length === 0}
              className="w-full sm:w-auto flex items-center justify-center gap-2 bg-gradient-to-r from-amber-500 to-orange-600 text-white font-semibold text-sm px-8 py-3 rounded-xl hover:shadow-lg hover:shadow-amber-500/25 transition-all disabled:opacity-50"
            >
              {submitting ? <Loader2 className="w-4 h-4 animate-spin" /> : <Send className="w-4 h-4" />}
              Submit for verification
            </button>
          </form>
        </>
      )}

      {/* Request history */}
      {requests?.length > 0 && (
        <div className="bg-white/5 border border-white/10 rounded-2xl overflow-hidden">
          <button
            onClick={() => setHistoryOpen(o => !o)}
            className="w-full flex items-center justify-between px-6 py-4 text-sm text-white/60 hover:text-white transition-colors"
          >
            <span>My requests ({requests.length})</span>
            <ChevronDown className={`w-4 h-4 transition-transform ${historyOpen ? 'rotate-180' : ''}`} />
          </button>
          {historyOpen && (
            <div className="divide-y divide-white/5 border-t border-white/10">
              {requests.map(r => (
                <div key={r.id} className="px-6 py-3 flex items-center gap-3 text-sm">
                  {r.status === 'pending' && <Clock className="w-4 h-4 text-amber-400 shrink-0" />}
                  {r.status === 'approved' && <CheckCircle2 className="w-4 h-4 text-emerald-400 shrink-0" />}
                  {r.status === 'rejected' && <XCircle className="w-4 h-4 text-red-400 shrink-0" />}
                  <div className="flex-1 min-w-0">
                    <p className="text-white/80 capitalize">
                      {r.duration} • {r.method} • <span className="font-mono">{r.trx_id}</span>
                    </p>
                    <p className="text-xs text-white/30">
                      {fmtDate(r.created_at)}
                      {r.status === 'rejected' && r.reject_reason && (
                        <span className="text-red-400/80"> — {r.reject_reason}</span>
                      )}
                    </p>
                  </div>
                  <span className="text-xs text-white/40 capitalize shrink-0">{r.status}</span>
                </div>
              ))}
            </div>
          )}
        </div>
      )}
    </div>
  );
}

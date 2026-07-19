import { useEffect, useState } from 'react';
import { supabase } from '../../lib/supabase';
import { Loader2, Search, KeyRound, ShieldCheck, ShieldOff, Crown, X, Check, Ban, Trash2 } from 'lucide-react';

const fmtDate = (d) =>
  d ? new Date(d).toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' }) : '—';

// All accounts (emails come from auth.users via the admin-users edge
// function). Actions: set a temp password, toggle admin, grant/revoke Premium.
export default function AdminUsers() {
  const [users, setUsers] = useState(null);
  const [query, setQuery] = useState('');
  const [busyId, setBusyId] = useState(null);
  const [pwTarget, setPwTarget] = useState(null); // user for the temp-password modal
  const [pwValue, setPwValue] = useState('');
  const [pwSaving, setPwSaving] = useState(false);
  const [subTarget, setSubTarget] = useState(null); // user for the subscription modal

  const fetchUsers = async () => {
    const { data, error } = await supabase.functions.invoke('admin-users', {
      body: { action: 'list_users' }
    });
    if (error || data?.error) { alert('Load failed: ' + (data?.error || error.message)); return; }
    setUsers(data.users || []);
  };

  useEffect(() => { fetchUsers(); }, []);

  const call = async (body, okMsg) => {
    const { data, error } = await supabase.functions.invoke('admin-users', { body });
    if (error || data?.error) throw new Error(data?.error || error.message);
    if (okMsg) alert(okMsg);
  };

  const handleToggleAdmin = async (u) => {
    const verb = u.is_admin ? 'REMOVE admin access from' : 'MAKE';
    if (!window.confirm(`${verb} ${u.email}${u.is_admin ? '' : ' an admin'}? Admins see every user and all payment requests.`)) return;
    setBusyId(u.id);
    try {
      await call({ action: 'toggle_admin', user_id: u.id, make_admin: !u.is_admin });
      await fetchUsers();
    } catch (err) { alert(err.message); }
    setBusyId(null);
  };

  const handleToggleBan = async (u) => {
    const msg = u.banned
      ? `Unblock ${u.email}? They will be able to sign in again.`
      : `Block ${u.email}? They cannot sign in until unblocked, but their data stays intact.`;
    if (!window.confirm(msg)) return;
    setBusyId(u.id);
    try {
      await call({ action: 'toggle_ban', user_id: u.id, ban: !u.banned });
      await fetchUsers();
    } catch (err) { alert(err.message); }
    setBusyId(null);
  };

  const handleDelete = async (u) => {
    if (!window.confirm(`PERMANENTLY delete ${u.email}? All their workspaces, transactions and documents are erased. This cannot be undone.`)) return;
    const typed = window.prompt(`Type the user's email to confirm deletion:`);
    if (typed !== u.email) { if (typed !== null) alert('Email did not match — nothing deleted.'); return; }
    setBusyId(u.id);
    try {
      await call({ action: 'delete_user', user_id: u.id }, `${u.email} deleted.`);
      await fetchUsers();
    } catch (err) { alert(err.message); }
    setBusyId(null);
  };

  const handleSetPassword = async () => {
    if (pwValue.length < 6) { alert('Password must be at least 6 characters.'); return; }
    setPwSaving(true);
    try {
      await call({ action: 'set_password', user_id: pwTarget.id, new_password: pwValue },
        `Password set. Tell ${pwTarget.email} to sign in with the new password and change it afterwards.`);
      setPwTarget(null);
      setPwValue('');
    } catch (err) { alert(err.message); }
    setPwSaving(false);
  };

  const handleSetSub = async (duration) => {
    setBusyId(subTarget.id);
    try {
      const { error } = await supabase.rpc('admin_set_subscription', {
        p_user: subTarget.id,
        p_duration: duration
      });
      if (error) throw error;
      setSubTarget(null);
      await fetchUsers();
    } catch (err) { alert(err.message); }
    setBusyId(null);
  };

  if (!users) {
    return <div className="p-8 text-center text-foreground/40"><Loader2 className="w-5 h-5 animate-spin mx-auto" /></div>;
  }

  const q = query.trim().toLowerCase();
  const shown = q
    ? users.filter(u => (u.email || '').toLowerCase().includes(q) || (u.full_name || '').toLowerCase().includes(q))
    : users;

  return (
    <div className="space-y-4">
      <div className="flex flex-col sm:flex-row sm:items-center gap-3">
        <div className="relative flex-1">
          <Search className="w-4 h-4 text-foreground/30 absolute left-4 top-1/2 -translate-y-1/2" />
          <input
            type="text"
            placeholder="Search by email or name…"
            value={query}
            onChange={e => setQuery(e.target.value)}
            className="w-full bg-foreground/5 border border-foreground/10 rounded-xl pl-11 pr-4 py-2.5 text-foreground text-sm focus:outline-none focus:border-cyan-500/50"
          />
        </div>
        <p className="text-xs text-foreground/40 shrink-0">
          {users.length} accounts • {users.filter(u => u.sub?.active).length} premium
        </p>
      </div>

      <div className="bg-foreground/5 border border-foreground/10 rounded-2xl overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="text-left text-[11px] uppercase tracking-wider text-foreground/30 border-b border-foreground/10">
                <th className="px-5 py-3 font-medium">User</th>
                <th className="px-5 py-3 font-medium">Joined</th>
                <th className="px-5 py-3 font-medium">Last sign-in</th>
                <th className="px-5 py-3 font-medium">Subscription</th>
                <th className="px-5 py-3 font-medium text-right">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-foreground/5">
              {shown.map(u => (
                <tr key={u.id} className="hover:bg-white/[0.03]">
                  <td className="px-5 py-3">
                    <p className="text-foreground font-medium flex items-center gap-2">
                      {u.full_name || '—'}
                      {u.is_admin && (
                        <span className="text-[10px] uppercase tracking-wide bg-cyan-500/15 text-cyan-400 px-2 py-0.5 rounded-full">admin</span>
                      )}
                      {u.banned && (
                        <span className="text-[10px] uppercase tracking-wide bg-red-500/15 text-red-400 px-2 py-0.5 rounded-full">blocked</span>
                      )}
                    </p>
                    <p className="text-xs text-foreground/40">{u.email}</p>
                  </td>
                  <td className="px-5 py-3 text-foreground/50 whitespace-nowrap">{fmtDate(u.created_at)}</td>
                  <td className="px-5 py-3 text-foreground/50 whitespace-nowrap">{fmtDate(u.last_sign_in_at)}</td>
                  <td className="px-5 py-3 whitespace-nowrap">
                    {u.sub?.active ? (
                      <span className="flex items-center gap-1.5 text-amber-400">
                        <Crown className="w-3.5 h-3.5" />
                        {u.sub.lifetime ? 'Lifetime' : `${u.sub.is_trial ? 'Trial until ' : 'Until '}${fmtDate(u.sub.expires_at)}`}
                      </span>
                    ) : u.sub ? (
                      <span className="text-red-400/70">Expired {fmtDate(u.sub.expires_at)}</span>
                    ) : (
                      <span className="text-foreground/30">Free</span>
                    )}
                  </td>
                  <td className="px-5 py-3">
                    <div className="flex items-center justify-end gap-1">
                      <button
                        onClick={() => setSubTarget(u)}
                        disabled={busyId === u.id}
                        className="p-2 text-foreground/40 hover:text-amber-400 transition-colors disabled:opacity-40"
                        title="Manage subscription"
                      >
                        <Crown className="w-4 h-4" />
                      </button>
                      <button
                        onClick={() => { setPwTarget(u); setPwValue(''); }}
                        disabled={busyId === u.id}
                        className="p-2 text-foreground/40 hover:text-cyan-400 transition-colors disabled:opacity-40"
                        title="Set temporary password"
                      >
                        <KeyRound className="w-4 h-4" />
                      </button>
                      <button
                        onClick={() => handleToggleAdmin(u)}
                        disabled={busyId === u.id}
                        className="p-2 text-foreground/40 hover:text-purple-400 transition-colors disabled:opacity-40"
                        title={u.is_admin ? 'Remove admin' : 'Make admin'}
                      >
                        {busyId === u.id
                          ? <Loader2 className="w-4 h-4 animate-spin" />
                          : u.is_admin ? <ShieldOff className="w-4 h-4" /> : <ShieldCheck className="w-4 h-4" />}
                      </button>
                      <button
                        onClick={() => handleToggleBan(u)}
                        disabled={busyId === u.id}
                        className={`p-2 transition-colors disabled:opacity-40 ${u.banned ? 'text-red-400 hover:text-emerald-400' : 'text-foreground/40 hover:text-orange-400'}`}
                        title={u.banned ? 'Unblock user' : 'Block user (cannot sign in)'}
                      >
                        <Ban className="w-4 h-4" />
                      </button>
                      <button
                        onClick={() => handleDelete(u)}
                        disabled={busyId === u.id}
                        className="p-2 text-foreground/40 hover:text-red-400 transition-colors disabled:opacity-40"
                        title="Delete user permanently"
                      >
                        <Trash2 className="w-4 h-4" />
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        {shown.length === 0 && (
          <p className="p-8 text-center text-sm text-foreground/40">No matching users.</p>
        )}
      </div>

      {/* Temp password modal */}
      {pwTarget && (
        <div className="fixed inset-0 bg-black/60 backdrop-blur-sm z-[60] flex items-center justify-center p-4" onClick={() => setPwTarget(null)}>
          <div className="bg-muted border border-foreground/10 rounded-2xl w-full max-w-sm shadow-2xl" onClick={e => e.stopPropagation()}>
            <div className="flex items-center justify-between p-6 border-b border-foreground/10">
              <h2 className="text-lg font-semibold text-foreground">Set temporary password</h2>
              <button onClick={() => setPwTarget(null)} className="text-foreground/40 hover:text-foreground transition-colors">
                <X className="w-5 h-5" />
              </button>
            </div>
            <div className="p-6 space-y-4">
              <p className="text-sm text-foreground/50">
                For <span className="text-foreground">{pwTarget.email}</span>. Share it with the user and
                ask them to change it after signing in.
              </p>
              <input
                type="text"
                autoFocus
                minLength={6}
                placeholder="New temporary password (min 6 chars)"
                value={pwValue}
                onChange={e => setPwValue(e.target.value)}
                className="w-full bg-foreground/5 border border-foreground/10 rounded-xl px-4 py-2.5 text-foreground text-sm focus:outline-none focus:border-cyan-500/50 font-mono"
              />
              <button
                onClick={handleSetPassword}
                disabled={pwSaving || pwValue.length < 6}
                className="w-full py-3 rounded-xl bg-gradient-to-r from-cyan-500 to-purple-600 text-white font-semibold text-sm hover:shadow-lg hover:shadow-cyan-500/25 transition-all disabled:opacity-50"
              >
                {pwSaving ? <Loader2 className="w-4 h-4 animate-spin mx-auto" /> : 'Set password'}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Subscription modal */}
      {subTarget && (
        <div className="fixed inset-0 bg-black/60 backdrop-blur-sm z-[60] flex items-center justify-center p-4" onClick={() => setSubTarget(null)}>
          <div className="bg-muted border border-foreground/10 rounded-2xl w-full max-w-sm shadow-2xl" onClick={e => e.stopPropagation()}>
            <div className="flex items-center justify-between p-6 border-b border-foreground/10">
              <h2 className="text-lg font-semibold text-foreground flex items-center gap-2">
                <Crown className="w-5 h-5 text-amber-400" /> Manage subscription
              </h2>
              <button onClick={() => setSubTarget(null)} className="text-foreground/40 hover:text-foreground transition-colors">
                <X className="w-5 h-5" />
              </button>
            </div>
            <div className="p-6 space-y-3">
              <p className="text-sm text-foreground/50">
                <span className="text-foreground">{subTarget.email}</span> —{' '}
                {subTarget.sub?.active
                  ? subTarget.sub.lifetime
                    ? 'Lifetime premium'
                    : `${subTarget.sub.is_trial ? 'trial' : 'premium'} until ${fmtDate(subTarget.sub.expires_at)}`
                  : 'no active subscription'}.
                Extending adds to the current expiry (a trial grant resets to a fresh 3 days).
              </p>
              <button
                onClick={() => handleSetSub('trial')}
                disabled={busyId === subTarget.id}
                className="w-full flex items-center gap-2 px-4 py-3 rounded-xl bg-foreground/5 border border-foreground/10 text-white text-sm hover:bg-amber-500/10 hover:border-amber-500/25 transition-all disabled:opacity-50"
              >
                <Check className="w-4 h-4 text-amber-400" /> Grant 3-day trial
              </button>
              {['monthly', 'yearly', 'lifetime'].map(d => (
                <button
                  key={d}
                  onClick={() => handleSetSub(d)}
                  disabled={busyId === subTarget.id}
                  className="w-full flex items-center gap-2 px-4 py-3 rounded-xl bg-foreground/5 border border-foreground/10 text-white text-sm capitalize hover:bg-amber-500/10 hover:border-amber-500/25 transition-all disabled:opacity-50"
                >
                  <Check className="w-4 h-4 text-amber-400" /> Grant / extend {d}
                </button>
              ))}
              {subTarget.sub && (
                <button
                  onClick={() => window.confirm(`Revoke ${subTarget.email}'s subscription?`) && handleSetSub(null)}
                  disabled={busyId === subTarget.id}
                  className="w-full flex items-center gap-2 px-4 py-3 rounded-xl bg-foreground/5 border border-red-500/25 text-red-400 text-sm hover:bg-red-500/10 transition-all disabled:opacity-50"
                >
                  <X className="w-4 h-4" /> Revoke subscription
                </button>
              )}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

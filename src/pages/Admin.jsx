import { useEffect, useState } from 'react';
import { useSearchParams } from 'react-router';
import { supabase } from '../lib/supabase';
import { useIsAdmin } from '../hooks/useIsAdmin';
import { ShieldCheck, Loader2, Users, Inbox, Wallet, LayoutGrid, Smartphone, Sparkles, BookOpen } from 'lucide-react';
import AdminUsers from '../components/admin/AdminUsers';
import AdminRequests from '../components/admin/AdminRequests';
import AdminBilling from '../components/admin/AdminBilling';
import AdminModules from '../components/admin/AdminModules';
import AdminReleases from '../components/admin/AdminReleases';
import AdminManuals from '../components/admin/AdminManuals';
import AdminAIKey from '../components/admin/AdminAIKey';

const TABS = [
  { id: 'users', label: 'Users', icon: Users },
  { id: 'requests', label: 'Requests', icon: Inbox },
  { id: 'billing', label: 'Billing', icon: Wallet },
  { id: 'modules', label: 'Modules', icon: LayoutGrid },
  { id: 'releases', label: 'Releases', icon: Smartphone },
  { id: 'manuals', label: 'Manuals', icon: BookOpen },
  { id: 'ai', label: 'AI Key', icon: Sparkles }
];

// Admin panel: everything the app owner manages lives here — users,
// subscription requests (manual bKash/Nagad verification), billing config,
// module free/premium gating, OTA APK releases and the Gemini key.
export default function Admin() {
  const { isAdmin, checking } = useIsAdmin();
  const [searchParams, setSearchParams] = useSearchParams();
  const tab = TABS.some(t => t.id === searchParams.get('tab')) ? searchParams.get('tab') : 'users';
  const [pendingCount, setPendingCount] = useState(0);

  // Badge on the Requests tab even before it's opened.
  useEffect(() => {
    if (!isAdmin) return;
    supabase
      .from('subscription_requests')
      .select('id', { count: 'exact', head: true })
      .eq('status', 'pending')
      .then(({ count }) => setPendingCount(count || 0));
  }, [isAdmin]);

  if (checking) {
    return <div className="flex items-center justify-center py-20 text-foreground/40"><Loader2 className="w-6 h-6 animate-spin" /></div>;
  }

  if (!isAdmin) {
    return (
      <div className="max-w-lg mx-auto mt-16 text-center bg-foreground/5 border border-foreground/10 rounded-2xl p-10">
        <ShieldCheck className="w-10 h-10 text-red-400 mx-auto mb-4" />
        <h2 className="text-lg font-semibold text-foreground mb-2">Admin only</h2>
        <p className="text-sm text-foreground/50">
          This page is restricted. Ask the administrator to enable admin access for your account
          (run migration v15 and set <code className="text-cyan-400">profiles.is_admin</code>).
        </p>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-foreground flex items-center gap-2">
          <ShieldCheck className="w-6 h-6 text-cyan-400" /> Admin Panel
        </h1>
        <p className="text-sm text-foreground/40 mt-1">
          Users, subscriptions, payment verification, module access, app releases.
        </p>
      </div>

      <div className="flex gap-2 overflow-x-auto pb-1">
        {TABS.map(t => {
          const Icon = t.icon;
          const active = tab === t.id;
          return (
            <button
              key={t.id}
              onClick={() => setSearchParams({ tab: t.id })}
              className={`flex items-center gap-2 px-4 py-2.5 rounded-xl text-sm whitespace-nowrap transition-all border ${
                active
                  ? 'bg-gradient-to-r from-cyan-500/20 to-purple-600/20 text-cyan-400 border-cyan-500/20'
                  : 'bg-foreground/5 text-foreground/50 border-foreground/10 hover:text-foreground'
              }`}
            >
              <Icon className="w-4 h-4" /> {t.label}
              {t.id === 'requests' && pendingCount > 0 && (
                <span className="text-[11px] bg-amber-500/20 text-amber-400 px-1.5 py-0.5 rounded-full">{pendingCount}</span>
              )}
            </button>
          );
        })}
      </div>

      {tab === 'users' && <AdminUsers />}
      {tab === 'requests' && <AdminRequests onCountChange={setPendingCount} />}
      {tab === 'billing' && <AdminBilling />}
      {tab === 'modules' && <AdminModules />}
      {tab === 'releases' && <AdminReleases />}
      {tab === 'manuals' && <AdminManuals />}
      {tab === 'ai' && <AdminAIKey />}
    </div>
  );
}

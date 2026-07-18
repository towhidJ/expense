import { createContext, useCallback, useContext, useEffect, useMemo, useState } from 'react';
import { supabase } from '../lib/supabase';
import { useAuth } from './AuthContext';

// Premium gating state, fetched once per login: billing config, the
// module free/premium map and the caller's subscription status.
//
// This gating is UX-only — the data behind premium modules is still the
// user's own data protected by RLS; the server-enforced parts are the
// submit/review RPCs and admin config writes (migration v39).
const SubscriptionContext = createContext({});

export const useSubscription = () => useContext(SubscriptionContext);

export function SubscriptionProvider({ children }) {
  const { user } = useAuth();
  const [loading, setLoading] = useState(true);
  const [billing, setBilling] = useState(null);
  const [premiumMap, setPremiumMap] = useState({}); // module_key -> is_premium
  const [sub, setSub] = useState(null); // { is_active, is_lifetime, expires_at }
  const [isAdmin, setIsAdmin] = useState(false);

  const refresh = useCallback(async () => {
    if (!user) {
      setBilling(null);
      setPremiumMap({});
      setSub(null);
      setIsAdmin(false);
      setLoading(false);
      return;
    }
    setLoading(true);
    const [billingRes, accessRes, subRes, profileRes] = await Promise.all([
      supabase.from('billing_settings').select('*').eq('id', 1).maybeSingle(),
      supabase.from('module_access').select('module_key, is_premium'),
      supabase.rpc('get_my_subscription'),
      supabase.from('profiles').select('is_admin').eq('id', user.id).maybeSingle()
    ]);
    setBilling(billingRes.data || null);
    setPremiumMap(Object.fromEntries((accessRes.data || []).map(r => [r.module_key, r.is_premium])));
    const s = Array.isArray(subRes.data) ? subRes.data[0] : subRes.data;
    setSub(s || null);
    setIsAdmin(!!profileRes.data?.is_admin);
    setLoading(false);
  }, [user]);

  useEffect(() => { refresh(); }, [refresh]);

  const isPremiumActive = !!sub?.is_active;

  // Fail-open while loading: a premium page may flash for a moment for a
  // non-subscriber, which beats showing every user a paywall flash on each
  // reload. Unknown keys are free by contract (module_access is seed-only).
  const isModuleLocked = useCallback(
    (key) => !loading && !isAdmin && !isPremiumActive && !!premiumMap[key],
    [loading, isAdmin, isPremiumActive, premiumMap]
  );

  const value = useMemo(() => ({
    loading,
    billing,
    isAdmin,
    isPremiumActive,
    isLifetime: !!sub?.is_lifetime,
    isTrial: !!sub?.is_trial,
    expiresAt: sub?.expires_at || null,
    isModuleLocked,
    refresh
  }), [loading, billing, isAdmin, isPremiumActive, sub, isModuleLocked, refresh]);

  return (
    <SubscriptionContext.Provider value={value}>
      {children}
    </SubscriptionContext.Provider>
  );
}

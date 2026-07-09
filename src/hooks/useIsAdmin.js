import { useEffect, useState } from 'react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../context/AuthContext';

// Reads profiles.is_admin (added in migration v15) for the signed-in user.
export function useIsAdmin() {
  const { user } = useAuth();
  const [isAdmin, setIsAdmin] = useState(false);
  const [checking, setChecking] = useState(true);

  useEffect(() => {
    if (!user) { setIsAdmin(false); setChecking(false); return; }
    let cancelled = false;
    supabase
      .from('profiles')
      .select('is_admin')
      .eq('id', user.id)
      .maybeSingle()
      .then(({ data }) => {
        if (!cancelled) {
          setIsAdmin(!!data?.is_admin);
          setChecking(false);
        }
      });
    return () => { cancelled = true; };
  }, [user]);

  return { isAdmin, checking };
}

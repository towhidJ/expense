import { useEffect, useState } from 'react';
import { supabase } from '../../lib/supabase';
import { MODULES, ALWAYS_FREE } from '../../lib/modules';
import { Loader2, Lock, Unlock } from 'lucide-react';

// Which modules are free vs Premium. Missing row = free; the core trio
// (dashboard/transactions/accounts) is never in module_access at all.
export default function AdminModules() {
  const [access, setAccess] = useState(null); // { key: is_premium }
  const [busyKey, setBusyKey] = useState(null);

  useEffect(() => {
    supabase.from('module_access').select('*').then(({ data }) => {
      setAccess(Object.fromEntries((data || []).map(r => [r.module_key, r.is_premium])));
    });
  }, []);

  const toggle = async (key) => {
    const next = !access[key];
    setBusyKey(key);
    const { error } = await supabase
      .from('module_access')
      .upsert({ module_key: key, is_premium: next, updated_at: new Date().toISOString() });
    if (error) alert('Update failed: ' + error.message);
    else setAccess(a => ({ ...a, [key]: next }));
    setBusyKey(null);
  };

  if (!access) {
    return <div className="p-8 text-center text-white/40"><Loader2 className="w-5 h-5 animate-spin mx-auto" /></div>;
  }

  const premiumCount = MODULES.filter(m => access[m.key]).length;

  return (
    <div className="space-y-4">
      <div className="bg-white/5 border border-white/10 rounded-2xl p-6">
        <h2 className="text-lg font-semibold text-white">Module access</h2>
        <p className="text-sm text-white/40 mt-1">
          Premium modules need an active subscription. Free modules are open to everyone.
          Currently <span className="text-cyan-400 font-medium">{premiumCount}</span> of {MODULES.length} modules are Premium.
        </p>
      </div>

      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3">
        {ALWAYS_FREE.map(key => (
          <div key={key} className="flex items-center gap-3 bg-white/5 border border-white/10 rounded-xl px-4 py-3 opacity-60">
            <Unlock className="w-4 h-4 text-emerald-400 shrink-0" />
            <span className="flex-1 text-sm text-white capitalize">{key}</span>
            <span className="text-[10px] uppercase tracking-wide bg-emerald-500/15 text-emerald-400 px-2 py-0.5 rounded-full">Always free</span>
          </div>
        ))}
        {MODULES.map(m => {
          const premium = !!access[m.key];
          return (
            <button
              key={m.key}
              onClick={() => toggle(m.key)}
              disabled={busyKey === m.key}
              className={`flex items-center gap-3 rounded-xl px-4 py-3 text-left transition-all border ${
                premium
                  ? 'bg-amber-500/10 border-amber-500/25 hover:bg-amber-500/15'
                  : 'bg-white/5 border-white/10 hover:bg-white/10'
              } disabled:opacity-50`}
            >
              {busyKey === m.key ? (
                <Loader2 className="w-4 h-4 text-white/40 animate-spin shrink-0" />
              ) : premium ? (
                <Lock className="w-4 h-4 text-amber-400 shrink-0" />
              ) : (
                <Unlock className="w-4 h-4 text-white/30 shrink-0" />
              )}
              <span className="flex-1 text-sm text-white">{m.label}</span>
              <span className={`text-[10px] uppercase tracking-wide px-2 py-0.5 rounded-full ${
                premium ? 'bg-amber-500/15 text-amber-400' : 'bg-white/10 text-white/40'
              }`}>
                {premium ? 'Premium' : 'Free'}
              </span>
            </button>
          );
        })}
      </div>
    </div>
  );
}

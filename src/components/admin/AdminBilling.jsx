import { useEffect, useState } from 'react';
import { supabase } from '../../lib/supabase';
import { Loader2, Check, Wallet } from 'lucide-react';

const DURATIONS = [
  { key: 'monthly', label: 'Monthly', hint: 'renews every month' },
  { key: 'yearly', label: 'Yearly', hint: 'renews every year' },
  { key: 'lifetime', label: 'Lifetime', hint: 'one-time payment, never expires' }
];

// Billing config: which durations are sold + prices + the bKash/Nagad numbers
// users pay to. Single row (id=1) in billing_settings; admin-writable via RLS.
export default function AdminBilling() {
  const [form, setForm] = useState(null);
  const [saving, setSaving] = useState(false);
  const [saved, setSaved] = useState(false);

  useEffect(() => {
    supabase.from('billing_settings').select('*').eq('id', 1).maybeSingle()
      .then(({ data }) => setForm(data || {}));
  }, []);

  const handleSave = async () => {
    setSaving(true);
    try {
      const { error } = await supabase.from('billing_settings').upsert({
        id: 1,
        monthly_enabled: !!form.monthly_enabled,
        monthly_price: Number(form.monthly_price) || 0,
        yearly_enabled: !!form.yearly_enabled,
        yearly_price: Number(form.yearly_price) || 0,
        lifetime_enabled: !!form.lifetime_enabled,
        lifetime_price: Number(form.lifetime_price) || 0,
        bkash_number: form.bkash_number?.trim() || null,
        bkash_account_type: form.bkash_account_type || 'personal',
        nagad_number: form.nagad_number?.trim() || null,
        nagad_account_type: form.nagad_account_type || 'personal',
        instructions: form.instructions?.trim() || null,
        updated_at: new Date().toISOString()
      });
      if (error) throw error;
      setSaved(true);
      setTimeout(() => setSaved(false), 2500);
    } catch (err) {
      alert('Save failed: ' + err.message);
    }
    setSaving(false);
  };

  if (!form) {
    return <div className="p-8 text-center text-foreground/40"><Loader2 className="w-5 h-5 animate-spin mx-auto" /></div>;
  }

  return (
    <div className="space-y-6">
      {/* Durations & prices */}
      <div className="bg-foreground/5 border border-foreground/10 rounded-2xl p-6 space-y-4">
        <h2 className="text-lg font-semibold text-foreground">Premium plan pricing</h2>
        <p className="text-sm text-foreground/40">
          Enable the durations you want to sell and set their prices. Disabled durations disappear
          from the paywall and new requests for them are refused server-side.
        </p>
        <div className="space-y-3">
          {DURATIONS.map(d => (
            <div key={d.key} className="flex flex-col sm:flex-row sm:items-center gap-3 bg-foreground/5 border border-foreground/10 rounded-xl px-4 py-3">
              <label className="flex items-center gap-3 flex-1 cursor-pointer">
                <input
                  type="checkbox"
                  checked={!!form[`${d.key}_enabled`]}
                  onChange={e => setForm(f => ({ ...f, [`${d.key}_enabled`]: e.target.checked }))}
                  className="w-4 h-4 accent-cyan-500"
                />
                <span className="text-sm text-foreground font-medium">{d.label}</span>
                <span className="text-xs text-foreground/30">{d.hint}</span>
              </label>
              <div className="flex items-center gap-2">
                <span className="text-foreground/40 text-sm">৳</span>
                <input
                  type="number"
                  min="0"
                  value={form[`${d.key}_price`] ?? ''}
                  onChange={e => setForm(f => ({ ...f, [`${d.key}_price`]: e.target.value }))}
                  disabled={!form[`${d.key}_enabled`]}
                  className="w-28 bg-foreground/5 border border-foreground/10 rounded-xl px-3 py-2 text-foreground text-sm focus:outline-none focus:border-cyan-500/50 disabled:opacity-40"
                />
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* Payment numbers */}
      <div className="bg-foreground/5 border border-foreground/10 rounded-2xl p-6 space-y-4">
        <h2 className="text-lg font-semibold text-foreground flex items-center gap-2">
          <Wallet className="w-5 h-5 text-cyan-400" /> Payment receiving numbers
        </h2>
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
          {[
            { id: 'bkash', label: 'bKash number', color: 'text-pink-400' },
            { id: 'nagad', label: 'Nagad number', color: 'text-orange-400' }
          ].map(m => (
            <div key={m.id} className="space-y-2">
              <label className={`block text-sm ${m.color}`}>{m.label}</label>
              <input
                type="text"
                placeholder="01XXXXXXXXX"
                value={form[`${m.id}_number`] || ''}
                onChange={e => setForm(f => ({ ...f, [`${m.id}_number`]: e.target.value }))}
                className="w-full bg-foreground/5 border border-foreground/10 rounded-xl px-4 py-2.5 text-foreground text-sm focus:outline-none focus:border-cyan-500/50"
              />
              <select
                value={form[`${m.id}_account_type`] || 'personal'}
                onChange={e => setForm(f => ({ ...f, [`${m.id}_account_type`]: e.target.value }))}
                className="w-full bg-foreground/5 border border-foreground/10 rounded-xl px-3 py-2 text-foreground/70 text-sm focus:outline-none focus:border-cyan-500/50 appearance-none cursor-pointer capitalize"
              >
                {['personal', 'agent', 'merchant'].map(t => (
                  <option key={t} value={t} className="bg-muted capitalize">{t} account</option>
                ))}
              </select>
            </div>
          ))}
        </div>
        <div>
          <label className="block text-sm text-foreground/50 mb-1.5">Payment instructions (shown on the paywall)</label>
          <textarea
            rows={3}
            placeholder={'e.g. Send Money korে trx ID টা submit করুন। Reference-এ আপনার email দিন।'}
            value={form.instructions || ''}
            onChange={e => setForm(f => ({ ...f, instructions: e.target.value }))}
            className="w-full bg-foreground/5 border border-foreground/10 rounded-xl px-4 py-2.5 text-foreground text-sm focus:outline-none focus:border-cyan-500/50 resize-none"
          />
        </div>
      </div>

      <button
        onClick={handleSave}
        disabled={saving}
        className="flex items-center justify-center gap-2 bg-gradient-to-r from-cyan-500 to-purple-600 text-white font-semibold text-sm px-8 py-3 rounded-xl hover:shadow-lg hover:shadow-cyan-500/25 transition-all disabled:opacity-50"
      >
        {saving ? <Loader2 className="w-4 h-4 animate-spin" /> : saved ? <Check className="w-4 h-4" /> : null}
        {saved ? 'Saved' : 'Save billing settings'}
      </button>
    </div>
  );
}

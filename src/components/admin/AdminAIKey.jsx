import { useEffect, useState } from 'react';
import { supabase } from '../../lib/supabase';
import { Sparkles, Loader2, Check } from 'lucide-react';

// Manage the Gemini API key used by the `gemini` edge function. The key is
// stored in app_settings (migration v32) and is never read back to the browser
// — we only show a masked status via the get_app_setting_status RPC.
export default function AdminAIKey() {
  const [status, setStatus] = useState(null); // { is_set, preview, updated_at }
  const [loading, setLoading] = useState(true);
  const [keyInput, setKeyInput] = useState('');
  const [saving, setSaving] = useState(false);
  const [saved, setSaved] = useState(false);

  const fetchStatus = async () => {
    const { data } = await supabase.rpc('get_app_setting_status', { p_key: 'gemini_api_key' });
    setStatus(Array.isArray(data) ? data[0] || null : data || null);
    setLoading(false);
  };

  useEffect(() => { fetchStatus(); }, []);

  const handleSave = async () => {
    const value = keyInput.trim();
    if (!value) { alert('Paste the Gemini API key first.'); return; }
    setSaving(true);
    try {
      const { error } = await supabase
        .rpc('set_app_setting', { p_key: 'gemini_api_key', p_value: value });
      if (error) throw error;
      setKeyInput('');
      setSaved(true);
      setTimeout(() => setSaved(false), 2500);
      await fetchStatus();
    } catch (err) {
      alert('Save failed: ' + err.message);
    }
    setSaving(false);
  };

  return (
    <div className="bg-white/5 border border-white/10 rounded-2xl p-6 space-y-4">
      <div className="flex items-center gap-2">
        <Sparkles className="w-5 h-5 text-cyan-400" />
        <h2 className="text-lg font-semibold text-white">Gemini AI key</h2>
      </div>
      <p className="text-sm text-white/40">
        Powers AI transaction entry, receipt scanning and insights. The key is stored server-side
        and used only by the edge function — it is never sent back to any browser or app.
      </p>

      <div className="rounded-xl bg-white/5 border border-white/10 px-4 py-3 flex items-center gap-2 text-sm">
        {loading ? (
          <span className="text-white/40 flex items-center gap-2"><Loader2 className="w-4 h-4 animate-spin" /> Checking…</span>
        ) : status?.is_set ? (
          <span className="text-emerald-400 flex items-center gap-2">
            <Check className="w-4 h-4" /> Configured
            <span className="text-white/40 font-mono">{status.preview}</span>
            {status.updated_at && (
              <span className="text-white/30 text-xs">
                • updated {new Date(status.updated_at).toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' })}
              </span>
            )}
          </span>
        ) : (
          <span className="text-amber-400">Not configured yet — AI features will be unavailable.</span>
        )}
      </div>

      <div className="flex flex-col sm:flex-row gap-2">
        <input
          type="password"
          value={keyInput}
          onChange={e => setKeyInput(e.target.value)}
          placeholder={status?.is_set ? 'Paste a new key to replace it…' : 'Paste your Gemini API key (AIza…)'}
          className="flex-1 bg-white/5 border border-white/10 rounded-xl px-4 py-2.5 text-white text-sm focus:outline-none focus:border-cyan-500/50 font-mono"
        />
        <button
          onClick={handleSave}
          disabled={saving || !keyInput.trim()}
          className="flex items-center justify-center gap-2 bg-gradient-to-r from-cyan-500 to-purple-600 text-white font-semibold text-sm px-6 py-2.5 rounded-xl hover:shadow-lg hover:shadow-cyan-500/25 transition-all disabled:opacity-50"
        >
          {saving ? <Loader2 className="w-4 h-4 animate-spin" /> : saved ? <Check className="w-4 h-4" /> : null}
          {saved ? 'Saved' : status?.is_set ? 'Update key' : 'Save key'}
        </button>
      </div>
      <p className="text-xs text-white/30">
        Get a key at <span className="text-cyan-400/70">aistudio.google.com/apikey</span>. Changes take effect within ~5 minutes.
      </p>
    </div>
  );
}

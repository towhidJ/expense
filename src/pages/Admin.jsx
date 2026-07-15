import { useEffect, useRef, useState } from 'react';
import { supabase } from '../lib/supabase';
import { useIsAdmin } from '../hooks/useIsAdmin';
import { ShieldCheck, UploadCloud, Smartphone, Trash2, Download, FileUp, Loader2, Sparkles, Check } from 'lucide-react';

const BUCKET = 'app-releases';

function prettySize(bytes) {
  if (!bytes && bytes !== 0) return '—';
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(0)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
}

// Admin panel: publish a new APK release (the Android app picks it up as an
// OTA update) and manage previously published versions.
export default function Admin() {
  const { isAdmin, checking } = useIsAdmin();
  const [versions, setVersions] = useState([]);
  const [loading, setLoading] = useState(true);
  const [form, setForm] = useState({ version_name: '', version_code: '', notes: '' });
  const [apkFile, setApkFile] = useState(null);
  const [uploading, setUploading] = useState(false);
  const inputRef = useRef(null);

  const fetchVersions = async () => {
    const { data, error } = await supabase
      .from('app_versions')
      .select('*')
      .order('version_code', { ascending: false });
    if (!error) setVersions(data || []);
    setLoading(false);
  };

  useEffect(() => { fetchVersions(); }, []);

  // Suggest the next version code once the list is loaded
  useEffect(() => {
    if (!loading && form.version_code === '') {
      const next = versions.length > 0 ? versions[0].version_code + 1 : 2;
      setForm(f => ({ ...f, version_code: String(next) }));
    }
  }, [loading]); // eslint-disable-line react-hooks/exhaustive-deps

  const handlePick = (e) => {
    const file = e.target.files?.[0];
    if (!file) return;
    if (!file.name.toLowerCase().endsWith('.apk')) {
      alert('Please select an .apk file.');
      e.target.value = '';
      return;
    }
    setApkFile(file);
    e.target.value = '';
  };

  const handlePublish = async (e) => {
    e.preventDefault();
    const code = parseInt(form.version_code, 10);
    if (!apkFile) { alert('Select the APK file to publish.'); return; }
    if (!form.version_name.trim()) { alert('Enter a version name, e.g. 1.1.0'); return; }
    if (!Number.isInteger(code) || code <= 0) { alert('Version code must be a positive number.'); return; }
    if (versions.some(v => v.version_code === code)) {
      alert(`Version code ${code} is already published. Use a higher number.`);
      return;
    }
    setUploading(true);
    try {
      const path = `v${code}/TakaKhata-${form.version_name.trim()}.apk`;
      const { error: upErr } = await supabase.storage
        .from(BUCKET)
        .upload(path, apkFile, {
          contentType: 'application/vnd.android.package-archive',
          cacheControl: '3600',
          upsert: true
        });
      if (upErr) throw upErr;

      const { data: urlData } = supabase.storage.from(BUCKET).getPublicUrl(path);

      const { error: insErr } = await supabase.from('app_versions').insert({
        version_code: code,
        version_name: form.version_name.trim(),
        notes: form.notes.trim() || null,
        apk_path: path,
        apk_url: urlData.publicUrl,
        file_size: apkFile.size
      });
      if (insErr) throw insErr;

      setForm({ version_name: '', version_code: String(code + 1), notes: '' });
      setApkFile(null);
      await fetchVersions();
      alert(`Version ${form.version_name.trim()} (code ${code}) published! The app will offer this update on next launch.`);
    } catch (err) {
      alert('Publish failed: ' + err.message);
    }
    setUploading(false);
  };

  const handleDelete = async (v) => {
    if (!window.confirm(`Delete version ${v.version_name} (code ${v.version_code})? Devices will no longer be offered this update.`)) return;
    try {
      await supabase.storage.from(BUCKET).remove([v.apk_path]);
      const { error } = await supabase.from('app_versions').delete().eq('id', v.id);
      if (error) throw error;
      await fetchVersions();
    } catch (err) {
      alert('Delete failed: ' + err.message);
    }
  };

  if (checking) {
    return <div className="flex items-center justify-center py-20 text-white/40"><Loader2 className="w-6 h-6 animate-spin" /></div>;
  }

  if (!isAdmin) {
    return (
      <div className="max-w-lg mx-auto mt-16 text-center bg-white/5 border border-white/10 rounded-2xl p-10">
        <ShieldCheck className="w-10 h-10 text-red-400 mx-auto mb-4" />
        <h2 className="text-lg font-semibold text-white mb-2">Admin only</h2>
        <p className="text-sm text-white/50">
          This page is restricted. Ask the administrator to enable admin access for your account
          (run migration v15 and set <code className="text-cyan-400">profiles.is_admin</code>).
        </p>
      </div>
    );
  }

  const latest = versions[0];

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-white flex items-center gap-2">
          <ShieldCheck className="w-6 h-6 text-cyan-400" /> Admin — App Releases
        </h1>
        <p className="text-sm text-white/40 mt-1">
          Upload a new APK here; the Android app checks this list on launch and offers the update (OTA).
        </p>
      </div>

      <GeminiKeyCard />

      {/* Current release summary */}
      {latest && (
        <div className="bg-gradient-to-r from-cyan-500/10 to-purple-600/10 border border-cyan-500/20 rounded-2xl p-5 flex items-center gap-4">
          <div className="w-12 h-12 rounded-xl bg-cyan-500/20 flex items-center justify-center shrink-0">
            <Smartphone className="w-6 h-6 text-cyan-400" />
          </div>
          <div className="flex-1 min-w-0">
            <p className="text-white font-semibold">Latest release: v{latest.version_name} <span className="text-white/40 font-normal">(code {latest.version_code})</span></p>
            <p className="text-xs text-white/40 mt-0.5">
              {prettySize(latest.file_size)} • published {new Date(latest.created_at).toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' })}
            </p>
          </div>
          <a
            href={latest.apk_url}
            className="flex items-center gap-2 text-sm text-cyan-400 hover:text-cyan-300 shrink-0"
            download
          >
            <Download className="w-4 h-4" /> APK
          </a>
        </div>
      )}

      {/* Publish form */}
      <form onSubmit={handlePublish} className="bg-white/5 border border-white/10 rounded-2xl p-6 space-y-4">
        <h2 className="text-lg font-semibold text-white flex items-center gap-2">
          <UploadCloud className="w-5 h-5 text-cyan-400" /> Publish new version
        </h2>

        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <div>
            <label className="block text-sm text-white/50 mb-1.5">Version name</label>
            <input
              type="text"
              placeholder="e.g. 1.1.0"
              value={form.version_name}
              onChange={e => setForm(f => ({ ...f, version_name: e.target.value }))}
              className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-2.5 text-white text-sm focus:outline-none focus:border-cyan-500/50"
            />
          </div>
          <div>
            <label className="block text-sm text-white/50 mb-1.5">Version code (must increase every release)</label>
            <input
              type="number"
              min="1"
              placeholder="e.g. 2"
              value={form.version_code}
              onChange={e => setForm(f => ({ ...f, version_code: e.target.value }))}
              className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-2.5 text-white text-sm focus:outline-none focus:border-cyan-500/50"
            />
          </div>
        </div>

        <div>
          <label className="block text-sm text-white/50 mb-1.5">Release notes (shown in the update dialog)</label>
          <textarea
            rows={3}
            placeholder={'What changed?\ne.g. Voucher print, bug fixes'}
            value={form.notes}
            onChange={e => setForm(f => ({ ...f, notes: e.target.value }))}
            className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-2.5 text-white text-sm focus:outline-none focus:border-cyan-500/50 resize-none"
          />
        </div>

        <div>
          <label className="block text-sm text-white/50 mb-1.5">APK file</label>
          {apkFile ? (
            <div className="flex items-center gap-2 bg-cyan-500/10 border border-cyan-500/20 rounded-xl px-3 py-2.5">
              <FileUp className="w-4 h-4 text-cyan-400 shrink-0" />
              <span className="flex-1 min-w-0 text-sm text-white/80 truncate">{apkFile.name}</span>
              <span className="text-xs text-white/40 shrink-0">{prettySize(apkFile.size)}</span>
              <button type="button" onClick={() => setApkFile(null)} className="text-white/40 hover:text-red-400 text-xs shrink-0">Remove</button>
            </div>
          ) : (
            <button
              type="button"
              onClick={() => inputRef.current?.click()}
              className="w-full flex items-center justify-center gap-2 bg-white/5 border border-dashed border-white/15 rounded-xl px-4 py-6 text-white/50 text-sm hover:bg-white/10 hover:text-white/80 transition-all"
            >
              <UploadCloud className="w-5 h-5" /> Click to select the APK
              <span className="text-white/30 text-xs">(mobile/build/app/outputs/flutter-apk/app-release.apk)</span>
            </button>
          )}
          <input ref={inputRef} type="file" accept=".apk" onChange={handlePick} className="hidden" />
        </div>

        <button
          type="submit"
          disabled={uploading}
          className="w-full sm:w-auto flex items-center justify-center gap-2 bg-gradient-to-r from-cyan-500 to-purple-600 text-white font-semibold text-sm px-8 py-3 rounded-xl hover:shadow-lg hover:shadow-cyan-500/25 transition-all disabled:opacity-50"
        >
          {uploading ? (<><Loader2 className="w-4 h-4 animate-spin" /> Uploading… (may take a minute)</>) : (<><UploadCloud className="w-4 h-4" /> Publish release</>)}
        </button>
      </form>

      {/* Version history */}
      <div className="bg-white/5 border border-white/10 rounded-2xl overflow-hidden">
        <div className="px-6 py-4 border-b border-white/10">
          <h2 className="text-lg font-semibold text-white">Release history</h2>
        </div>
        {loading ? (
          <div className="p-8 text-center text-white/40"><Loader2 className="w-5 h-5 animate-spin mx-auto" /></div>
        ) : versions.length === 0 ? (
          <p className="p-8 text-center text-sm text-white/40">No releases published yet.</p>
        ) : (
          <div className="divide-y divide-white/5">
            {versions.map((v, i) => (
              <div key={v.id} className="px-6 py-4 flex items-start gap-4">
                <div className="w-9 h-9 rounded-lg bg-white/5 flex items-center justify-center shrink-0 mt-0.5">
                  <Smartphone className="w-4 h-4 text-white/50" />
                </div>
                <div className="flex-1 min-w-0">
                  <p className="text-sm text-white font-medium">
                    v{v.version_name} <span className="text-white/40 font-normal">(code {v.version_code})</span>
                    {i === 0 && <span className="ml-2 text-[10px] uppercase tracking-wide bg-emerald-500/15 text-emerald-400 px-2 py-0.5 rounded-full">latest</span>}
                  </p>
                  {v.notes && <p className="text-xs text-white/50 mt-1 whitespace-pre-line">{v.notes}</p>}
                  <p className="text-[11px] text-white/30 mt-1">
                    {prettySize(v.file_size)} • {new Date(v.created_at).toLocaleString('en-GB', { day: '2-digit', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' })}
                  </p>
                </div>
                <div className="flex items-center gap-1 shrink-0">
                  <a href={v.apk_url} download className="p-2 text-white/40 hover:text-cyan-400 transition-colors" title="Download APK">
                    <Download className="w-4 h-4" />
                  </a>
                  <button onClick={() => handleDelete(v)} className="p-2 text-white/40 hover:text-red-400 transition-colors" title="Delete release">
                    <Trash2 className="w-4 h-4" />
                  </button>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}

// Manage the Gemini API key used by the `gemini` edge function. The key is
// stored in app_settings (migration v32) and is never read back to the browser
// — we only show a masked status via the get_app_setting_status RPC.
function GeminiKeyCard() {
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

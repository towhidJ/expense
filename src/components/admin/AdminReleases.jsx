import { useEffect, useRef, useState } from 'react';
import { supabase } from '../../lib/supabase';
import { uploadToMinio, removeFromMinio } from '../../lib/minioStorage';
import { UploadCloud, Smartphone, Trash2, Download, FileUp, Loader2 } from 'lucide-react';

const BUCKET = 'app-releases';

function prettySize(bytes) {
  if (!bytes && bytes !== 0) return '—';
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(0)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
}

// Publish a new APK release (the Android app picks it up as an OTA update)
// and manage previously published versions.
export default function AdminReleases() {
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
      const publicUrl = await uploadToMinio(BUCKET, path, apkFile, 'application/vnd.android.package-archive');

      const { error: insErr } = await supabase.from('app_versions').insert({
        version_code: code,
        version_name: form.version_name.trim(),
        notes: form.notes.trim() || null,
        apk_path: path,
        apk_url: publicUrl,
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
      await removeFromMinio(BUCKET, [v.apk_path]);
      const { error } = await supabase.from('app_versions').delete().eq('id', v.id);
      if (error) throw error;
      await fetchVersions();
    } catch (err) {
      alert('Delete failed: ' + err.message);
    }
  };

  const latest = versions[0];

  return (
    <div className="space-y-6">
      {/* Current release summary */}
      {latest && (
        <div className="bg-gradient-to-r from-cyan-500/10 to-purple-600/10 border border-cyan-500/20 rounded-2xl p-5 flex items-center gap-4">
          <div className="w-12 h-12 rounded-xl bg-cyan-500/20 flex items-center justify-center shrink-0">
            <Smartphone className="w-6 h-6 text-cyan-400" />
          </div>
          <div className="flex-1 min-w-0">
            <p className="text-foreground font-semibold">Latest release: v{latest.version_name} <span className="text-foreground/40 font-normal">(code {latest.version_code})</span></p>
            <p className="text-xs text-foreground/40 mt-0.5">
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
      <form onSubmit={handlePublish} className="bg-foreground/5 border border-foreground/10 rounded-2xl p-6 space-y-4">
        <h2 className="text-lg font-semibold text-foreground flex items-center gap-2">
          <UploadCloud className="w-5 h-5 text-cyan-400" /> Publish new version
        </h2>

        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <div>
            <label className="block text-sm text-foreground/50 mb-1.5">Version name</label>
            <input
              type="text"
              placeholder="e.g. 1.1.0"
              value={form.version_name}
              onChange={e => setForm(f => ({ ...f, version_name: e.target.value }))}
              className="w-full bg-foreground/5 border border-foreground/10 rounded-xl px-4 py-2.5 text-foreground text-sm focus:outline-none focus:border-cyan-500/50"
            />
          </div>
          <div>
            <label className="block text-sm text-foreground/50 mb-1.5">Version code (must increase every release)</label>
            <input
              type="number"
              min="1"
              placeholder="e.g. 2"
              value={form.version_code}
              onChange={e => setForm(f => ({ ...f, version_code: e.target.value }))}
              className="w-full bg-foreground/5 border border-foreground/10 rounded-xl px-4 py-2.5 text-foreground text-sm focus:outline-none focus:border-cyan-500/50"
            />
          </div>
        </div>

        <div>
          <label className="block text-sm text-foreground/50 mb-1.5">Release notes (shown in the update dialog)</label>
          <textarea
            rows={3}
            placeholder={'What changed?\ne.g. Voucher print, bug fixes'}
            value={form.notes}
            onChange={e => setForm(f => ({ ...f, notes: e.target.value }))}
            className="w-full bg-foreground/5 border border-foreground/10 rounded-xl px-4 py-2.5 text-foreground text-sm focus:outline-none focus:border-cyan-500/50 resize-none"
          />
        </div>

        <div>
          <label className="block text-sm text-foreground/50 mb-1.5">APK file</label>
          {apkFile ? (
            <div className="flex items-center gap-2 bg-cyan-500/10 border border-cyan-500/20 rounded-xl px-3 py-2.5">
              <FileUp className="w-4 h-4 text-cyan-400 shrink-0" />
              <span className="flex-1 min-w-0 text-sm text-foreground/80 truncate">{apkFile.name}</span>
              <span className="text-xs text-foreground/40 shrink-0">{prettySize(apkFile.size)}</span>
              <button type="button" onClick={() => setApkFile(null)} className="text-foreground/40 hover:text-red-400 text-xs shrink-0">Remove</button>
            </div>
          ) : (
            <button
              type="button"
              onClick={() => inputRef.current?.click()}
              className="w-full flex items-center justify-center gap-2 bg-foreground/5 border border-dashed border-foreground/15 rounded-xl px-4 py-6 text-foreground/50 text-sm hover:bg-foreground/10 hover:text-foreground/80 transition-all"
            >
              <UploadCloud className="w-5 h-5" /> Click to select the APK
              <span className="text-foreground/30 text-xs">(mobile/build/app/outputs/flutter-apk/app-release.apk)</span>
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
      <div className="bg-foreground/5 border border-foreground/10 rounded-2xl overflow-hidden">
        <div className="px-6 py-4 border-b border-foreground/10">
          <h2 className="text-lg font-semibold text-foreground">Release history</h2>
        </div>
        {loading ? (
          <div className="p-8 text-center text-foreground/40"><Loader2 className="w-5 h-5 animate-spin mx-auto" /></div>
        ) : versions.length === 0 ? (
          <p className="p-8 text-center text-sm text-foreground/40">No releases published yet.</p>
        ) : (
          <div className="divide-y divide-foreground/5">
            {versions.map((v, i) => (
              <div key={v.id} className="px-6 py-4 flex items-start gap-4">
                <div className="w-9 h-9 rounded-lg bg-foreground/5 flex items-center justify-center shrink-0 mt-0.5">
                  <Smartphone className="w-4 h-4 text-foreground/50" />
                </div>
                <div className="flex-1 min-w-0">
                  <p className="text-sm text-foreground font-medium">
                    v{v.version_name} <span className="text-foreground/40 font-normal">(code {v.version_code})</span>
                    {i === 0 && <span className="ml-2 text-[10px] uppercase tracking-wide bg-emerald-500/15 text-emerald-400 px-2 py-0.5 rounded-full">latest</span>}
                  </p>
                  {v.notes && <p className="text-xs text-foreground/50 mt-1 whitespace-pre-line">{v.notes}</p>}
                  <p className="text-[11px] text-foreground/30 mt-1">
                    {prettySize(v.file_size)} • {new Date(v.created_at).toLocaleString('en-GB', { day: '2-digit', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' })}
                  </p>
                </div>
                <div className="flex items-center gap-1 shrink-0">
                  <a href={v.apk_url} download className="p-2 text-foreground/40 hover:text-cyan-400 transition-colors" title="Download APK">
                    <Download className="w-4 h-4" />
                  </a>
                  <button onClick={() => handleDelete(v)} className="p-2 text-foreground/40 hover:text-red-400 transition-colors" title="Delete release">
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

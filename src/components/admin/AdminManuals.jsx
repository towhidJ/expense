import { useEffect, useRef, useState } from 'react';
import { supabase } from '../../lib/supabase';
import { uploadToMinio, removeFromMinio } from '../../lib/minioStorage';
import { UploadCloud, BookOpen, Trash2, ExternalLink, FileUp, Loader2 } from 'lucide-react';

const BUCKET = 'app-manuals';

function prettySize(bytes) {
  if (!bytes && bytes !== 0) return '—';
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(0)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
}

// Upload public user-manual PDFs. These are readable by everyone — the login
// page and the app footer link to them without a session (see v45 migration).
export default function AdminManuals() {
  const [manuals, setManuals] = useState([]);
  const [loading, setLoading] = useState(true);
  const [form, setForm] = useState({ title: '', description: '' });
  const [file, setFile] = useState(null);
  const [uploading, setUploading] = useState(false);
  const inputRef = useRef(null);

  const fetchManuals = async () => {
    const { data, error } = await supabase
      .from('app_manuals')
      .select('*')
      .order('sort_order', { ascending: true })
      .order('created_at', { ascending: false });
    if (!error) setManuals(data || []);
    setLoading(false);
  };

  useEffect(() => { fetchManuals(); }, []);

  const handlePick = (e) => {
    const f = e.target.files?.[0];
    if (!f) return;
    if (!f.name.toLowerCase().endsWith('.pdf')) {
      alert('Please select a .pdf file.');
      e.target.value = '';
      return;
    }
    setFile(f);
    if (!form.title.trim()) {
      setForm(s => ({ ...s, title: f.name.replace(/\.pdf$/i, '') }));
    }
    e.target.value = '';
  };

  const handleUpload = async (e) => {
    e.preventDefault();
    if (!file) { alert('Select the PDF file to upload.'); return; }
    if (!form.title.trim()) { alert('Enter a title, e.g. Bangla User Manual'); return; }
    setUploading(true);
    try {
      const safe = form.title.trim().replace(/[^a-z0-9]+/gi, '-').toLowerCase();
      const path = `${Date.now()}-${safe || 'manual'}.pdf`;
      const publicUrl = await uploadToMinio(BUCKET, path, file, 'application/pdf');

      const { error: insErr } = await supabase.from('app_manuals').insert({
        title: form.title.trim(),
        description: form.description.trim() || null,
        file_path: path,
        file_url: publicUrl,
        file_size: file.size,
        sort_order: manuals.length
      });
      if (insErr) throw insErr;

      setForm({ title: '', description: '' });
      setFile(null);
      await fetchManuals();
      alert(`"${form.title.trim()}" uploaded! It's now visible to everyone on the login page and app footer.`);
    } catch (err) {
      alert('Upload failed: ' + err.message);
    }
    setUploading(false);
  };

  const handleDelete = async (m) => {
    if (!window.confirm(`Delete "${m.title}"? It will disappear from the login page and footer.`)) return;
    try {
      await removeFromMinio(BUCKET, [m.file_path]);
      const { error } = await supabase.from('app_manuals').delete().eq('id', m.id);
      if (error) throw error;
      await fetchManuals();
    } catch (err) {
      alert('Delete failed: ' + err.message);
    }
  };

  return (
    <div className="space-y-6">
      {/* Upload form */}
      <form onSubmit={handleUpload} className="bg-foreground/5 border border-foreground/10 rounded-2xl p-6 space-y-4">
        <h2 className="text-lg font-semibold text-foreground flex items-center gap-2">
          <UploadCloud className="w-5 h-5 text-cyan-400" /> Upload a manual
        </h2>
        <p className="text-xs text-foreground/40 -mt-2">
          PDF guides you upload here are public — shown to everyone on the login page and the app footer.
        </p>

        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <div>
            <label className="block text-sm text-foreground/50 mb-1.5">Title</label>
            <input
              type="text"
              placeholder="e.g. ব্যবহার নির্দেশিকা (Bangla)"
              value={form.title}
              onChange={e => setForm(f => ({ ...f, title: e.target.value }))}
              className="w-full bg-foreground/5 border border-foreground/10 rounded-xl px-4 py-2.5 text-foreground text-sm focus:outline-none focus:border-cyan-500/50"
            />
          </div>
          <div>
            <label className="block text-sm text-foreground/50 mb-1.5">Short description (optional)</label>
            <input
              type="text"
              placeholder="e.g. How to use TakaKhata"
              value={form.description}
              onChange={e => setForm(f => ({ ...f, description: e.target.value }))}
              className="w-full bg-foreground/5 border border-foreground/10 rounded-xl px-4 py-2.5 text-foreground text-sm focus:outline-none focus:border-cyan-500/50"
            />
          </div>
        </div>

        <div>
          <label className="block text-sm text-foreground/50 mb-1.5">PDF file</label>
          {file ? (
            <div className="flex items-center gap-2 bg-cyan-500/10 border border-cyan-500/20 rounded-xl px-3 py-2.5">
              <FileUp className="w-4 h-4 text-cyan-400 shrink-0" />
              <span className="flex-1 min-w-0 text-sm text-foreground/80 truncate">{file.name}</span>
              <span className="text-xs text-foreground/40 shrink-0">{prettySize(file.size)}</span>
              <button type="button" onClick={() => setFile(null)} className="text-foreground/40 hover:text-red-400 text-xs shrink-0">Remove</button>
            </div>
          ) : (
            <button
              type="button"
              onClick={() => inputRef.current?.click()}
              className="w-full flex items-center justify-center gap-2 bg-foreground/5 border border-dashed border-foreground/15 rounded-xl px-4 py-6 text-foreground/50 text-sm hover:bg-foreground/10 hover:text-foreground/80 transition-all"
            >
              <UploadCloud className="w-5 h-5" /> Click to select the PDF
            </button>
          )}
          <input ref={inputRef} type="file" accept=".pdf,application/pdf" onChange={handlePick} className="hidden" />
        </div>

        <button
          type="submit"
          disabled={uploading}
          className="w-full sm:w-auto flex items-center justify-center gap-2 bg-gradient-to-r from-cyan-500 to-purple-600 text-white font-semibold text-sm px-8 py-3 rounded-xl hover:shadow-lg hover:shadow-cyan-500/25 transition-all disabled:opacity-50"
        >
          {uploading ? (<><Loader2 className="w-4 h-4 animate-spin" /> Uploading…</>) : (<><UploadCloud className="w-4 h-4" /> Upload manual</>)}
        </button>
      </form>

      {/* Manual list */}
      <div className="bg-foreground/5 border border-foreground/10 rounded-2xl overflow-hidden">
        <div className="px-6 py-4 border-b border-foreground/10">
          <h2 className="text-lg font-semibold text-foreground">Published manuals</h2>
        </div>
        {loading ? (
          <div className="p-8 text-center text-foreground/40"><Loader2 className="w-5 h-5 animate-spin mx-auto" /></div>
        ) : manuals.length === 0 ? (
          <p className="p-8 text-center text-sm text-foreground/40">No manuals uploaded yet.</p>
        ) : (
          <div className="divide-y divide-foreground/5">
            {manuals.map((m) => (
              <div key={m.id} className="px-6 py-4 flex items-start gap-4">
                <div className="w-9 h-9 rounded-lg bg-foreground/5 flex items-center justify-center shrink-0 mt-0.5">
                  <BookOpen className="w-4 h-4 text-foreground/50" />
                </div>
                <div className="flex-1 min-w-0">
                  <p className="text-sm text-foreground font-medium truncate">{m.title}</p>
                  {m.description && <p className="text-xs text-foreground/50 mt-1">{m.description}</p>}
                  <p className="text-[11px] text-foreground/30 mt-1">
                    {prettySize(m.file_size)} • {new Date(m.created_at).toLocaleString('en-GB', { day: '2-digit', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' })}
                  </p>
                </div>
                <div className="flex items-center gap-1 shrink-0">
                  <a href={m.file_url} target="_blank" rel="noreferrer" className="p-2 text-foreground/40 hover:text-cyan-400 transition-colors" title="Open PDF">
                    <ExternalLink className="w-4 h-4" />
                  </a>
                  <button onClick={() => handleDelete(m)} className="p-2 text-foreground/40 hover:text-red-400 transition-colors" title="Delete manual">
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

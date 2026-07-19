import { useEffect, useState } from 'react';
import { useAttachments } from '../hooks/useAttachments';
import { FileText, Upload, Trash2, ExternalLink, AlertTriangle } from 'lucide-react';

const today = () => new Date().toISOString().split('T')[0];
const CAT_META = {
  nid: { label: 'NID', icon: '🪪' },
  tin: { label: 'TIN', icon: '🧾' },
  passport: { label: 'Passport', icon: '📘' },
  warranty: { label: 'Warranty', icon: '🛡️' },
  insurance: { label: 'Insurance', icon: '☂️' },
  other: { label: 'Other', icon: '📄' }
};

export default function Documents() {
  const { uploading, uploadAttachment, fetchAttachments, deleteAttachment } = useAttachments();
  const [docs, setDocs] = useState(null);
  const [adding, setAdding] = useState(false);
  const [form, setForm] = useState({ title: '', doc_category: 'other', expiry_date: '', file: null });

  const load = async () => setDocs(await fetchAttachments({ vaultOnly: true }));
  useEffect(() => { load(); }, []); // eslint-disable-line react-hooks/exhaustive-deps

  const handleUpload = async (e) => {
    e.preventDefault();
    if (!form.file) { alert('Choose a file first.'); return; }
    try {
      await uploadAttachment(form.file, {
        docCategory: form.doc_category,
        expiryDate: form.expiry_date || null,
        title: form.title || form.file.name
      });
      setAdding(false);
      setForm({ title: '', doc_category: 'other', expiry_date: '', file: null });
      await load();
    } catch (err) {
      alert('Error uploading document: ' + err.message);
    }
  };

  const handleDelete = async (doc) => {
    if (!confirm(`Delete "${doc.title || doc.file_name}"?`)) return;
    try {
      await deleteAttachment(doc);
      await load();
    } catch (err) {
      alert('Error deleting: ' + err.message);
    }
  };

  if (!docs) return <div className="text-foreground/50 p-6">Loading documents...</div>;

  return (
    <div className="space-y-6 animate-in">
      <div className="flex justify-between items-center">
        <div>
          <h1 className="text-2xl font-bold text-foreground">Document Vault</h1>
          <p className="text-foreground/40 text-sm mt-1">NID, TIN, passport and other important scans in one place.</p>
        </div>
        <button onClick={() => setAdding(true)} className="flex items-center gap-2 bg-cyan-500 hover:bg-cyan-600 text-white px-4 py-2 rounded-xl transition-colors shadow-lg shadow-cyan-500/20">
          <Upload size={18} /> Upload
        </button>
      </div>

      {adding && (
        <div className="bg-card border border-foreground/10 rounded-2xl p-6">
          <h2 className="text-lg font-semibold text-foreground mb-4">Upload Document</h2>
          <form onSubmit={handleUpload} className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
            <div>
              <label className="block text-sm text-foreground/60 mb-1">Title</label>
              <input type="text" value={form.title} onChange={e => setForm({ ...form, title: e.target.value })} placeholder="e.g. My NID" className="w-full bg-muted border border-foreground/10 rounded-xl px-4 py-2.5 text-foreground focus:outline-none focus:border-cyan-500/50" />
            </div>
            <div>
              <label className="block text-sm text-foreground/60 mb-1">Category</label>
              <select value={form.doc_category} onChange={e => setForm({ ...form, doc_category: e.target.value })} className="w-full bg-muted border border-foreground/10 rounded-xl px-4 py-2.5 text-foreground focus:outline-none focus:border-cyan-500/50">
                {Object.entries(CAT_META).map(([k, v]) => <option key={k} value={k}>{v.icon} {v.label}</option>)}
              </select>
            </div>
            <div>
              <label className="block text-sm text-foreground/60 mb-1">Expiry Date (optional)</label>
              <input type="date" value={form.expiry_date} onChange={e => setForm({ ...form, expiry_date: e.target.value })} className="w-full bg-muted border border-foreground/10 rounded-xl px-4 py-2.5 text-foreground focus:outline-none focus:border-cyan-500/50" />
            </div>
            <div>
              <label className="block text-sm text-foreground/60 mb-1">File</label>
              <input required type="file" onChange={e => setForm({ ...form, file: e.target.files?.[0] || null })} className="w-full bg-muted border border-foreground/10 rounded-xl px-3 py-2 text-foreground text-sm focus:outline-none focus:border-cyan-500/50" />
            </div>
            <div className="lg:col-span-4 flex justify-end gap-3">
              <button type="button" onClick={() => setAdding(false)} className="px-5 py-2.5 rounded-xl text-foreground/60 hover:text-foreground hover:bg-foreground/5 transition-colors">Cancel</button>
              <button type="submit" disabled={uploading} className="bg-cyan-500 hover:bg-cyan-600 text-white px-6 py-2.5 rounded-xl shadow-lg shadow-cyan-500/20 transition-all font-medium disabled:opacity-50">
                {uploading ? 'Uploading...' : 'Save Document'}
              </button>
            </div>
          </form>
        </div>
      )}

      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
        {docs.map(doc => {
          const meta = CAT_META[doc.doc_category] || CAT_META.other;
          const expired = doc.expiry_date && doc.expiry_date < today();
          const expiresSoon = doc.expiry_date && !expired && doc.expiry_date <= new Date(Date.now() + 30 * 86400000).toISOString().split('T')[0];
          return (
            <div key={doc.id} className="bg-card border border-foreground/10 rounded-2xl p-5 hover:border-foreground/20 transition-all">
              <div className="flex justify-between items-start mb-3">
                <div className="flex items-center gap-3">
                  <div className="w-11 h-11 rounded-full bg-muted flex items-center justify-center text-xl">{meta.icon}</div>
                  <div>
                    <h3 className="text-foreground font-medium">{doc.title || doc.file_name}</h3>
                    <p className="text-foreground/40 text-xs">{meta.label}</p>
                  </div>
                </div>
                <div className="flex gap-1.5">
                  <a href={doc.file_url} target="_blank" rel="noreferrer" className="text-white/40 hover:text-cyan-400 p-1.5 bg-foreground/5 hover:bg-cyan-500/10 rounded-lg">
                    <ExternalLink size={15} />
                  </a>
                  <button onClick={() => handleDelete(doc)} className="text-white/40 hover:text-red-400 p-1.5 bg-foreground/5 hover:bg-red-500/10 rounded-lg">
                    <Trash2 size={15} />
                  </button>
                </div>
              </div>
              {doc.expiry_date && (
                <div className="pt-3 border-t border-foreground/5 text-sm flex items-center justify-between">
                  <span className="text-foreground/40">Expires</span>
                  <span className={`flex items-center gap-1 ${expired ? 'text-red-400 font-medium' : expiresSoon ? 'text-amber-400' : 'text-foreground/70'}`}>
                    {(expired || expiresSoon) && <AlertTriangle size={12} />} {new Date(doc.expiry_date).toLocaleDateString()}
                  </span>
                </div>
              )}
            </div>
          );
        })}
      </div>

      {docs.length === 0 && !adding && (
        <div className="text-center py-12 border border-foreground/5 rounded-2xl bg-white/[0.02]">
          <FileText className="mx-auto text-foreground/20 mb-4" size={48} />
          <h3 className="text-foreground/60 font-medium">No documents yet</h3>
          <p className="text-foreground/40 text-sm mt-1">Upload NID, TIN, passport or other important scans.</p>
        </div>
      )}
    </div>
  );
}

import { useState, useEffect } from 'react';
import { useAssets } from '../hooks/useAssets';
import { useAttachments } from '../hooks/useAttachments';
import DocumentUpload from '../components/DocumentUpload';
import { BadgeCheck, FileText, ShieldAlert } from 'lucide-react';

const today = () => new Date().toISOString().split('T')[0];
const daysUntil = (date) => Math.ceil((new Date(date) - new Date()) / 86400000);

export default function Warranty() {
  const { assets, loading, updateAsset } = useAssets();
  const { uploadMany, fetchAttachments, deleteAttachment, uploading } = useAttachments();
  const [managing, setManaging] = useState(null); // asset being edited
  const [form, setForm] = useState({ warranty_expiry: '', warranty_notes: '' });
  const [files, setFiles] = useState([]);
  const [existingDocs, setExistingDocs] = useState([]);

  useEffect(() => {
    setFiles([]);
    if (managing) {
      fetchAttachments({ assetId: managing.id }).then(setExistingDocs);
    } else {
      setExistingDocs([]);
    }
  }, [managing, fetchAttachments]);

  const withWarranty = assets.filter(a => a.warranty_expiry);
  const activeWarranty = withWarranty.filter(a => a.warranty_expiry >= today());
  const expiringSoon = activeWarranty.filter(a => daysUntil(a.warranty_expiry) <= 30);

  const handleSave = async (e) => {
    e.preventDefault();
    try {
      await updateAsset(managing.id, {
        warranty_expiry: form.warranty_expiry || null,
        warranty_notes: form.warranty_notes || ''
      });
      if (files.length) await uploadMany(files, { assetId: managing.id });
      setManaging(null);
      setFiles([]);
    } catch (err) {
      alert('Error saving warranty: ' + err.message);
    }
  };

  if (loading) return <div className="text-foreground/50 p-6">Loading assets...</div>;

  return (
    <div className="space-y-6 animate-in">
      <div>
        <h1 className="text-2xl font-bold text-foreground">Warranty & Receipt Vault</h1>
        <p className="text-foreground/40 text-sm mt-1">Warranty periods and purchase documents for your assets. {activeWarranty.length} active, {expiringSoon.length} expiring within 30 days.</p>
      </div>

      {expiringSoon.length > 0 && (
        <div className="bg-amber-500/10 border border-amber-500/20 rounded-2xl p-4">
          <p className="text-amber-400 text-sm font-medium">⏰ Warranty ending soon:</p>
          <ul className="text-foreground/60 text-xs mt-1.5 space-y-0.5">
            {expiringSoon.map(a => (
              <li key={a.id}>{a.name} — {daysUntil(a.warranty_expiry)} day(s) left ({new Date(a.warranty_expiry).toLocaleDateString()})</li>
            ))}
          </ul>
        </div>
      )}

      {managing && (
        <div className="fixed inset-0 bg-black/60 backdrop-blur-sm z-50 flex items-center justify-center p-4">
          <div className="bg-card border border-foreground/10 rounded-2xl p-6 w-full max-w-md shadow-2xl max-h-[90vh] overflow-y-auto">
            <h2 className="text-xl font-semibold text-foreground mb-2">Warranty — {managing.name}</h2>
            <p className="text-sm text-foreground/50 mb-6">Set the expiry date and attach the receipt / warranty card.</p>
            <form onSubmit={handleSave} className="space-y-4">
              <div>
                <label className="block text-sm text-foreground/60 mb-1">Warranty Expires</label>
                <input type="date" value={form.warranty_expiry} onChange={e => setForm({ ...form, warranty_expiry: e.target.value })} className="w-full bg-muted border border-foreground/10 rounded-xl px-4 py-2.5 text-foreground focus:outline-none focus:border-lime-500/50" />
              </div>
              <div>
                <label className="block text-sm text-foreground/60 mb-1">Notes (shop, service center, hotline…)</label>
                <textarea value={form.warranty_notes} onChange={e => setForm({ ...form, warranty_notes: e.target.value })} rows={2} className="w-full bg-muted border border-foreground/10 rounded-xl px-4 py-2.5 text-foreground focus:outline-none focus:border-lime-500/50" />
              </div>
              <DocumentUpload
                files={files}
                onChange={setFiles}
                existing={existingDocs}
                onRemoveExisting={async (att) => {
                  try {
                    await deleteAttachment(att);
                    setExistingDocs(prev => prev.filter(a => a.id !== att.id));
                  } catch (err) { alert('Error deleting document: ' + err.message); }
                }}
                label="Receipt / Warranty Card / Invoice"
              />
              <div className="flex justify-end gap-3 mt-6">
                <button type="button" onClick={() => { setManaging(null); setFiles([]); }} className="px-5 py-2.5 rounded-xl text-foreground/60 hover:text-foreground hover:bg-foreground/5 transition-colors">Cancel</button>
                <button type="submit" disabled={uploading} className="bg-lime-600 hover:bg-lime-700 disabled:opacity-50 text-white px-6 py-2.5 rounded-xl shadow-lg shadow-lime-500/20 transition-all font-medium">
                  {uploading ? 'Uploading...' : 'Save'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
        {assets.map(asset => {
          const has = !!asset.warranty_expiry;
          const days = has ? daysUntil(asset.warranty_expiry) : null;
          const expired = has && days < 0;
          return (
            <div key={asset.id} className="bg-card border border-foreground/10 rounded-2xl p-5 hover:border-foreground/20 transition-all">
              <div className="flex justify-between items-start mb-3">
                <div>
                  <h3 className="text-foreground font-medium">{asset.name}</h3>
                  <p className="text-foreground/40 text-xs">{asset.type}{asset.purchase_date ? ` · bought ${new Date(asset.purchase_date).toLocaleDateString()}` : ''}</p>
                </div>
                {has ? (
                  expired
                    ? <span className="px-2 py-0.5 rounded text-[10px] font-bold bg-foreground/10 text-foreground/40">EXPIRED</span>
                    : <span className={`px-2 py-0.5 rounded text-[10px] font-bold ${days <= 30 ? 'bg-amber-500/20 text-amber-400' : 'bg-emerald-500/20 text-emerald-400'}`}>{days}d LEFT</span>
                ) : (
                  <span className="px-2 py-0.5 rounded text-[10px] font-bold bg-foreground/5 text-foreground/30">NO WARRANTY</span>
                )}
              </div>
              {has && (
                <p className="text-xs text-foreground/50 mb-1">
                  <BadgeCheck size={12} className={`inline -mt-0.5 mr-1 ${expired ? 'text-foreground/30' : 'text-lime-400'}`} />
                  Until {new Date(asset.warranty_expiry).toLocaleDateString()}
                </p>
              )}
              {asset.warranty_notes && <p className="text-xs text-foreground/35 mb-2 truncate">{asset.warranty_notes}</p>}
              <button
                onClick={() => {
                  setManaging(asset);
                  setForm({ warranty_expiry: asset.warranty_expiry || '', warranty_notes: asset.warranty_notes || '' });
                }}
                className="mt-2 w-full flex items-center justify-center gap-2 text-xs bg-foreground/5 hover:bg-lime-500/10 text-white/60 hover:text-lime-400 px-3 py-2.5 rounded-xl font-medium transition-all"
              >
                <FileText size={14} /> {has ? 'Manage warranty & documents' : 'Add warranty & documents'}
              </button>
            </div>
          );
        })}
      </div>

      {assets.length === 0 && (
        <div className="text-center py-12 border border-foreground/5 rounded-2xl bg-white/[0.02]">
          <ShieldAlert className="mx-auto text-foreground/20 mb-4" size={48} />
          <h3 className="text-foreground/60 font-medium">No assets yet</h3>
          <p className="text-foreground/40 text-sm mt-1">Add assets on the Assets page first — then track their warranties and receipts here.</p>
        </div>
      )}
    </div>
  );
}

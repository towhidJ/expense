import { useState } from 'react';
import { Megaphone, Pin, Pencil, Trash2, Plus, Save, X } from 'lucide-react';

const EMPTY = { title: '', body: '', pinned: false };

// Manager posts announcements (meeting, new rule, bhara baki); everyone sees
// them here, and pinned ones as a banner on the Summary page.
export default function NoticeBoard({ notices, isManager, addNotice, updateNotice, deleteNotice }) {
  const [form, setForm] = useState(EMPTY);
  const [editingId, setEditingId] = useState(null); // null = closed, 'new' = adding
  const [saving, setSaving] = useState(false);

  const openNew = () => { setForm(EMPTY); setEditingId('new'); };
  const openEdit = (n) => { setForm({ title: n.title, body: n.body || '', pinned: !!n.pinned }); setEditingId(n.id); };
  const close = () => { setEditingId(null); setForm(EMPTY); };

  const handleSave = async (e) => {
    e.preventDefault();
    setSaving(true);
    try {
      if (editingId === 'new') await addNotice(form);
      else await updateNotice(editingId, form);
      close();
    } catch (err) {
      console.error(err);
      alert(err.message);
    } finally {
      setSaving(false);
    }
  };

  const handleDelete = async (id) => {
    if (!confirm('Delete this notice?')) return;
    try {
      await deleteNotice(id);
    } catch (err) {
      console.error(err);
      alert(err.message);
    }
  };

  return (
    <div className="space-y-6">
      {isManager && editingId === null && (
        <button onClick={openNew}
          className="flex items-center gap-2 bg-cyan-500 hover:bg-cyan-600 text-white px-5 py-2.5 rounded-xl shadow-lg shadow-cyan-500/20 font-medium text-sm">
          <Plus size={16} /> New Notice
        </button>
      )}

      {isManager && editingId !== null && (
        <form onSubmit={handleSave} className="bg-card border border-foreground/10 rounded-2xl p-6 space-y-4">
          <div className="flex items-center justify-between">
            <h3 className="text-foreground font-semibold">{editingId === 'new' ? 'New Notice' : 'Edit Notice'}</h3>
            <button type="button" onClick={close} className="text-foreground/40 hover:text-foreground"><X size={18} /></button>
          </div>
          <div>
            <label className="block text-sm text-foreground/60 mb-1">Title</label>
            <input required type="text" value={form.title}
              onChange={e => setForm({ ...form, title: e.target.value })}
              placeholder="Mess meeting on Friday after dinner"
              className="w-full bg-muted border border-foreground/10 rounded-xl px-4 py-2.5 text-foreground focus:outline-none focus:border-cyan-500/50" />
          </div>
          <div>
            <label className="block text-sm text-foreground/60 mb-1">Details (optional)</label>
            <textarea rows={3} value={form.body}
              onChange={e => setForm({ ...form, body: e.target.value })}
              className="w-full bg-muted border border-foreground/10 rounded-xl px-4 py-2.5 text-foreground focus:outline-none focus:border-cyan-500/50 resize-y" />
          </div>
          <label className="flex items-center gap-3 bg-muted border border-foreground/10 rounded-xl px-4 py-3 cursor-pointer">
            <input type="checkbox" checked={form.pinned}
              onChange={e => setForm({ ...form, pinned: e.target.checked })}
              className="accent-cyan-500 w-4 h-4" />
            <span className="text-foreground text-sm">Pin this notice</span>
            <span className="text-foreground/40 text-xs ml-auto">Pinned notices show as a banner on the Summary page</span>
          </label>
          <div className="flex justify-end">
            <button type="submit" disabled={saving}
              className="flex items-center gap-2 bg-cyan-500 hover:bg-cyan-600 text-white px-6 py-2.5 rounded-xl shadow-lg shadow-cyan-500/20 font-medium disabled:opacity-50">
              <Save size={16} /> {saving ? 'Saving...' : 'Save Notice'}
            </button>
          </div>
        </form>
      )}

      <div className="space-y-3">
        {notices.map(n => (
          <div key={n.id} className={`rounded-2xl p-5 border ${
            n.pinned ? 'bg-amber-500/5 border-amber-500/20' : 'bg-card border-foreground/10'
          }`}>
            <div className="flex items-start gap-3">
              <div className={`w-9 h-9 rounded-xl flex items-center justify-center shrink-0 ${
                n.pinned ? 'bg-amber-500/15 text-amber-400' : 'bg-foreground/5 text-white/40'
              }`}>
                {n.pinned ? <Pin size={16} /> : <Megaphone size={16} />}
              </div>
              <div className="flex-1 min-w-0">
                <p className="text-foreground font-medium">{n.title}</p>
                {n.body && <p className="text-foreground/60 text-sm mt-1 whitespace-pre-wrap">{n.body}</p>}
                <p className="text-foreground/30 text-xs mt-2">
                  {new Date(n.created_at).toLocaleDateString(undefined, { day: 'numeric', month: 'short', year: 'numeric' })}
                </p>
              </div>
              {isManager && (
                <div className="flex gap-1 shrink-0">
                  <button onClick={() => openEdit(n)} className="p-2 rounded-lg text-foreground/40 hover:text-foreground hover:bg-foreground/5">
                    <Pencil size={15} />
                  </button>
                  <button onClick={() => handleDelete(n.id)} className="p-2 rounded-lg text-foreground/40 hover:text-red-400 hover:bg-foreground/5">
                    <Trash2 size={15} />
                  </button>
                </div>
              )}
            </div>
          </div>
        ))}
        {notices.length === 0 && (
          <div className="bg-card border border-foreground/10 rounded-2xl p-8 text-center text-foreground/40 text-sm">
            No notices yet.{isManager ? ' Post one for your mess mates.' : ''}
          </div>
        )}
      </div>
    </div>
  );
}

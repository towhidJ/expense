import { useState, useEffect } from 'react';
import { Copy, RefreshCw, Save } from 'lucide-react';

export default function GroupSettings({ group, isManager, updateGroup, regenerateCode }) {
  const [form, setForm] = useState({
    name: '', has_maid: false,
    breakfast_value: 0.5, lunch_value: 1, dinner_value: 1
  });
  const [saving, setSaving] = useState(false);
  const [copied, setCopied] = useState(false);

  useEffect(() => {
    if (group) {
      setForm({
        name: group.name,
        has_maid: group.has_maid,
        breakfast_value: group.breakfast_value,
        lunch_value: group.lunch_value,
        dinner_value: group.dinner_value
      });
    }
  }, [group]);

  if (!group) return null;

  const copyCode = async () => {
    try {
      await navigator.clipboard.writeText(group.invite_code);
      setCopied(true);
      setTimeout(() => setCopied(false), 1500);
    } catch {
      alert(`Invite code: ${group.invite_code}`);
    }
  };

  const handleSave = async (e) => {
    e.preventDefault();
    setSaving(true);
    try {
      await updateGroup({
        name: form.name,
        has_maid: form.has_maid,
        breakfast_value: Number(form.breakfast_value),
        lunch_value: Number(form.lunch_value),
        dinner_value: Number(form.dinner_value)
      });
    } catch (err) {
      console.error(err);
      alert('Error saving settings: ' + err.message);
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="space-y-6 max-w-2xl">
      <div className="bg-[#1a1a2e] border border-white/10 rounded-2xl p-6">
        <h3 className="text-white font-semibold mb-4">Invite Code</h3>
        <div className="flex flex-wrap items-center gap-3">
          <code className="text-2xl font-bold tracking-[0.3em] text-cyan-400 bg-[#12122a] border border-white/10 rounded-xl px-5 py-3">
            {group.invite_code}
          </code>
          <button onClick={copyCode} className="flex items-center gap-2 px-4 py-2.5 rounded-xl bg-white/5 border border-white/10 text-white/70 hover:text-white">
            <Copy size={16} /> {copied ? 'Copied!' : 'Copy'}
          </button>
          {isManager && (
            <button
              onClick={() => { if (confirm('Regenerate the code? The old code stops working.')) regenerateCode().catch(err => alert(err.message)); }}
              className="flex items-center gap-2 px-4 py-2.5 rounded-xl bg-orange-500/10 border border-orange-500/20 text-orange-400 hover:bg-orange-500/20"
            >
              <RefreshCw size={16} /> Regenerate
            </button>
          )}
        </div>
        <p className="text-white/40 text-xs mt-3">Share this code with your mess mates so they can join.</p>
      </div>

      {isManager ? (
        <form onSubmit={handleSave} className="bg-[#1a1a2e] border border-white/10 rounded-2xl p-6 space-y-4">
          <h3 className="text-white font-semibold">Group Settings</h3>
          <div>
            <label className="block text-sm text-white/60 mb-1">Group Name</label>
            <input required type="text" value={form.name} onChange={e => setForm({ ...form, name: e.target.value })} className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-cyan-500/50" />
          </div>
          <div>
            <p className="text-sm text-white/60 mb-2">Meal values (how much one meal of each slot counts)</p>
            <div className="grid grid-cols-3 gap-4">
              {[['breakfast_value', 'Breakfast'], ['lunch_value', 'Lunch'], ['dinner_value', 'Dinner']].map(([key, label]) => (
                <div key={key}>
                  <label className="block text-xs text-white/40 mb-1">{label}</label>
                  <input required type="number" min="0" step="0.25" value={form[key]} onChange={e => setForm({ ...form, [key]: e.target.value })} className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-cyan-500/50" />
                </div>
              ))}
            </div>
            <p className="text-white/30 text-xs mt-2">E.g. breakfast 0.5 means two breakfasts count as one full meal in the rate calculation.</p>
          </div>
          <label className="flex items-center gap-3 bg-[#12122a] border border-white/10 rounded-xl px-4 py-3 cursor-pointer">
            <input type="checkbox" checked={form.has_maid} onChange={e => setForm({ ...form, has_maid: e.target.checked })} className="accent-purple-500 w-4 h-4" />
            <span className="text-white text-sm">We have a maid (kajer bua) who cooks</span>
            <span className="text-white/40 text-xs ml-auto">Hides cooking duty from the roster</span>
          </label>
          <div className="flex justify-end">
            <button type="submit" disabled={saving} className="flex items-center gap-2 bg-cyan-500 hover:bg-cyan-600 text-white px-6 py-2.5 rounded-xl shadow-lg shadow-cyan-500/20 font-medium disabled:opacity-50">
              <Save size={16} /> {saving ? 'Saving...' : 'Save Settings'}
            </button>
          </div>
        </form>
      ) : (
        <div className="bg-[#1a1a2e] border border-white/10 rounded-2xl p-6 text-sm text-white/60 space-y-2">
          <h3 className="text-white font-semibold mb-3">Group Settings</h3>
          <p>Meal values — Breakfast: <span className="text-white">{group.breakfast_value}</span>, Lunch: <span className="text-white">{group.lunch_value}</span>, Dinner: <span className="text-white">{group.dinner_value}</span></p>
          <p>Maid (kajer bua): <span className="text-white">{group.has_maid ? 'Yes — maid cooks' : 'No'}</span></p>
          <p className="text-white/30 text-xs mt-2">Only the manager can change these.</p>
        </div>
      )}
    </div>
  );
}

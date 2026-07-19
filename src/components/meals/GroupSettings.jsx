import { useState, useEffect } from 'react';
import { Copy, RefreshCw, Save, Wallet } from 'lucide-react';

export default function GroupSettings({ group, isManager, updateGroup, regenerateCode, paymentInfo, updatePaymentInfo }) {
  const [form, setForm] = useState({
    name: '', has_maid: false,
    breakfast_value: 0.5, lunch_value: 1, dinner_value: 1,
    cutoff_time: ''
  });
  const [saving, setSaving] = useState(false);
  const [copied, setCopied] = useState(false);
  const [payForm, setPayForm] = useState({ bkash_number: '', nagad_number: '' });
  const [savingPay, setSavingPay] = useState(false);

  useEffect(() => {
    setPayForm({
      bkash_number: paymentInfo?.bkash_number || '',
      nagad_number: paymentInfo?.nagad_number || ''
    });
  }, [paymentInfo]);

  useEffect(() => {
    if (group) {
      setForm({
        name: group.name,
        has_maid: group.has_maid,
        breakfast_value: group.breakfast_value,
        lunch_value: group.lunch_value,
        dinner_value: group.dinner_value,
        cutoff_time: group.cutoff_time ? group.cutoff_time.slice(0, 5) : ''
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
        dinner_value: Number(form.dinner_value),
        cutoff_time: form.cutoff_time || null
      });
    } catch (err) {
      console.error(err);
      alert('Error saving settings: ' + err.message);
    } finally {
      setSaving(false);
    }
  };

  const handleSavePay = async (e) => {
    e.preventDefault();
    setSavingPay(true);
    try {
      await updatePaymentInfo(payForm);
    } catch (err) {
      console.error(err);
      alert('Error saving payment info: ' + err.message);
    } finally {
      setSavingPay(false);
    }
  };

  return (
    <div className="space-y-6 max-w-2xl">
      <div className="bg-card border border-foreground/10 rounded-2xl p-6">
        <h3 className="text-foreground font-semibold mb-4">Invite Code</h3>
        <div className="flex flex-wrap items-center gap-3">
          <code className="text-2xl font-bold tracking-[0.3em] text-cyan-400 bg-muted border border-foreground/10 rounded-xl px-5 py-3">
            {group.invite_code}
          </code>
          <button onClick={copyCode} className="flex items-center gap-2 px-4 py-2.5 rounded-xl bg-foreground/5 border border-foreground/10 text-foreground/70 hover:text-foreground">
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
        <p className="text-foreground/40 text-xs mt-3">Share this code with your mess mates so they can join.</p>
      </div>

      {isManager ? (
        <form onSubmit={handleSave} className="bg-card border border-foreground/10 rounded-2xl p-6 space-y-4">
          <h3 className="text-foreground font-semibold">Group Settings</h3>
          <div>
            <label className="block text-sm text-foreground/60 mb-1">Group Name</label>
            <input required type="text" value={form.name} onChange={e => setForm({ ...form, name: e.target.value })} className="w-full bg-muted border border-foreground/10 rounded-xl px-4 py-2.5 text-foreground focus:outline-none focus:border-cyan-500/50" />
          </div>
          <div>
            <p className="text-sm text-foreground/60 mb-2">Meal values (how much one meal of each slot counts)</p>
            <div className="grid grid-cols-3 gap-4">
              {[['breakfast_value', 'Breakfast'], ['lunch_value', 'Lunch'], ['dinner_value', 'Dinner']].map(([key, label]) => (
                <div key={key}>
                  <label className="block text-xs text-foreground/40 mb-1">{label}</label>
                  <input required type="number" min="0" step="0.25" value={form[key]} onChange={e => setForm({ ...form, [key]: e.target.value })} className="w-full bg-muted border border-foreground/10 rounded-xl px-4 py-2.5 text-foreground focus:outline-none focus:border-cyan-500/50" />
                </div>
              ))}
            </div>
            <p className="text-foreground/30 text-xs mt-2">E.g. breakfast 0.5 means two breakfasts count as one full meal in the rate calculation.</p>
          </div>
          <div>
            <label className="block text-sm text-foreground/60 mb-1">Meal request cutoff time</label>
            <div className="flex items-center gap-3">
              <input type="time" value={form.cutoff_time} onChange={e => setForm({ ...form, cutoff_time: e.target.value })} className="bg-muted border border-foreground/10 rounded-xl px-4 py-2.5 text-foreground focus:outline-none focus:border-cyan-500/50" />
              {form.cutoff_time && (
                <button type="button" onClick={() => setForm({ ...form, cutoff_time: '' })} className="text-foreground/40 hover:text-foreground text-xs underline">
                  No cutoff
                </button>
              )}
            </div>
            <p className="text-foreground/30 text-xs mt-2">E.g. 21:00 means a meal off/guest request for tomorrow must be in by 9pm tonight. Empty = no deadline.</p>
          </div>
          <label className="flex items-center gap-3 bg-muted border border-foreground/10 rounded-xl px-4 py-3 cursor-pointer">
            <input type="checkbox" checked={form.has_maid} onChange={e => setForm({ ...form, has_maid: e.target.checked })} className="accent-purple-500 w-4 h-4" />
            <span className="text-foreground text-sm">We have a maid (kajer bua) who cooks</span>
            <span className="text-foreground/40 text-xs ml-auto">Hides cooking duty from the roster</span>
          </label>
          <div className="flex justify-end">
            <button type="submit" disabled={saving} className="flex items-center gap-2 bg-cyan-500 hover:bg-cyan-600 text-white px-6 py-2.5 rounded-xl shadow-lg shadow-cyan-500/20 font-medium disabled:opacity-50">
              <Save size={16} /> {saving ? 'Saving...' : 'Save Settings'}
            </button>
          </div>
        </form>
      ) : (
        <div className="bg-card border border-foreground/10 rounded-2xl p-6 text-sm text-foreground/60 space-y-2">
          <h3 className="text-foreground font-semibold mb-3">Group Settings</h3>
          <p>Meal values — Breakfast: <span className="text-foreground">{group.breakfast_value}</span>, Lunch: <span className="text-foreground">{group.lunch_value}</span>, Dinner: <span className="text-foreground">{group.dinner_value}</span></p>
          <p>Maid (kajer bua): <span className="text-foreground">{group.has_maid ? 'Yes — maid cooks' : 'No'}</span></p>
          <p>Meal request cutoff: <span className="text-foreground">{group.cutoff_time ? `${group.cutoff_time.slice(0, 5)} (the day before)` : 'None'}</span></p>
          <p className="text-foreground/30 text-xs mt-2">Only the manager can change these.</p>
        </div>
      )}

      {isManager ? (
        <form onSubmit={handleSavePay} className="bg-card border border-foreground/10 rounded-2xl p-6 space-y-4">
          <h3 className="text-foreground font-semibold flex items-center gap-2"><Wallet size={16} /> bKash / Nagad Payment</h3>
          <p className="text-foreground/40 text-xs -mt-2">Members will see a QR code to scan when paying a deposit. This is just a number + QR — no automatic payment gateway.</p>
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div>
              <label className="block text-sm text-foreground/60 mb-1">bKash number</label>
              <input type="tel" value={payForm.bkash_number} onChange={e => setPayForm({ ...payForm, bkash_number: e.target.value })} placeholder="01XXXXXXXXX" className="w-full bg-muted border border-foreground/10 rounded-xl px-4 py-2.5 text-foreground focus:outline-none focus:border-pink-500/50" />
            </div>
            <div>
              <label className="block text-sm text-foreground/60 mb-1">Nagad number</label>
              <input type="tel" value={payForm.nagad_number} onChange={e => setPayForm({ ...payForm, nagad_number: e.target.value })} placeholder="01XXXXXXXXX" className="w-full bg-muted border border-foreground/10 rounded-xl px-4 py-2.5 text-foreground focus:outline-none focus:border-orange-500/50" />
            </div>
          </div>
          <div className="flex justify-end">
            <button type="submit" disabled={savingPay} className="flex items-center gap-2 bg-pink-500 hover:bg-pink-600 text-white px-6 py-2.5 rounded-xl shadow-lg shadow-pink-500/20 font-medium disabled:opacity-50">
              <Save size={16} /> {savingPay ? 'Saving...' : 'Save Payment Info'}
            </button>
          </div>
        </form>
      ) : (paymentInfo?.bkash_number || paymentInfo?.nagad_number) ? (
        <div className="bg-card border border-foreground/10 rounded-2xl p-6 text-sm text-foreground/60 space-y-2">
          <h3 className="text-foreground font-semibold mb-3 flex items-center gap-2"><Wallet size={16} /> bKash / Nagad Payment</h3>
          {paymentInfo.bkash_number && <p>bKash: <span className="text-foreground">{paymentInfo.bkash_number}</span></p>}
          {paymentInfo.nagad_number && <p>Nagad: <span className="text-foreground">{paymentInfo.nagad_number}</span></p>}
          <p className="text-foreground/30 text-xs mt-2">Scan the QR on the Deposits page to pay.</p>
        </div>
      ) : null}
    </div>
  );
}

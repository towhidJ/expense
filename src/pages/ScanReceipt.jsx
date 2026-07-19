import { useState, useRef } from 'react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../context/AuthContext';
import { useEntity } from '../context/EntityContext';
import { useAccounts } from '../context/AccountContext';
import { useCategories } from '../hooks/useCategories';
import { parseReceipt } from '../lib/ai';
import { ScanLine, Upload, Trash2, Check, Loader2 } from 'lucide-react';

const today = () => new Date().toISOString().split('T')[0];

export default function ScanReceipt() {
  const { user } = useAuth();
  const { currentEntity } = useEntity();
  const { accounts, fetchAccounts } = useAccounts();
  const { categories } = useCategories();
  const fileInput = useRef(null);
  const [preview, setPreview] = useState(null);
  const [scanning, setScanning] = useState(false);
  const [saving, setSaving] = useState(false);
  const [items, setItems] = useState([]);
  const [accountId, setAccountId] = useState('');
  const [savedCount, setSavedCount] = useState(0);

  const catFor = (type) => categories?.filter(c => c.type === type) || [];

  const guessCategory = (suggested, type) => {
    if (!suggested) return '';
    const list = catFor(type);
    const hit = list.find(c => c.name.toLowerCase().includes(suggested.toLowerCase()) || suggested.toLowerCase().includes(c.name.toLowerCase()));
    return hit?.id || '';
  };

  const handleFile = async (file) => {
    if (!file) return;
    setSavedCount(0);
    setItems([]);
    setPreview(URL.createObjectURL(file));
    setScanning(true);
    try {
      const base64 = await new Promise((resolve, reject) => {
        const reader = new FileReader();
        reader.onload = () => resolve(String(reader.result).split(',')[1]);
        reader.onerror = reject;
        reader.readAsDataURL(file);
      });
      const result = await parseReceipt(base64, file.type || 'image/jpeg');
      const parsed = (result?.items || []).map(it => ({
        type: it.type === 'income' ? 'income' : 'expense',
        amount: it.amount || '',
        description: it.description || '',
        date: it.date || today(),
        category_id: guessCategory(it.suggested_category, it.type === 'income' ? 'income' : 'expense')
      }));
      if (!parsed.length) alert('Could not read any line items from this image. Try a clearer photo.');
      setItems(parsed);
    } catch (err) {
      alert('Scan failed: ' + err.message);
    }
    setScanning(false);
  };

  const updateItem = (i, patch) => setItems(prev => prev.map((it, idx) => idx === i ? { ...it, ...patch } : it));

  const saveAll = async () => {
    if (!accountId) return alert('Select the account these were paid from.');
    if (items.some(it => !it.category_id || !it.amount)) return alert('Every row needs an amount and a category.');
    setSaving(true);
    let ok = 0;
    try {
      for (const it of items) {
        const { error } = await supabase.rpc('process_transaction', {
          p_user_id: user.id,
          p_entity_id: currentEntity.id,
          p_account_id: accountId,
          p_category_id: it.category_id,
          p_asset_id: null,
          p_type: it.type,
          p_amount: parseFloat(it.amount),
          p_date: it.date,
          p_description: it.description || 'Receipt scan'
        });
        if (error) throw error;
        ok++;
      }
      await fetchAccounts();
      setSavedCount(ok);
      setItems([]);
      setPreview(null);
    } catch (err) {
      alert(`Saved ${ok} of ${items.length}, then failed: ${err.message}`);
    }
    setSaving(false);
  };

  return (
    <div className="space-y-6 animate-in">
      <div>
        <h1 className="text-2xl font-bold text-foreground">Scan Receipt</h1>
        <p className="text-foreground/40 text-sm mt-1">Take a photo of a receipt — AI reads the items, you confirm, it saves as transactions.</p>
      </div>

      {savedCount > 0 && (
        <div className="bg-emerald-500/10 border border-emerald-500/20 rounded-2xl p-4 flex items-center gap-3">
          <Check className="text-emerald-400" size={20} />
          <p className="text-emerald-400 text-sm font-medium">{savedCount} transaction{savedCount > 1 ? 's' : ''} saved successfully!</p>
        </div>
      )}

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <div>
          <input ref={fileInput} type="file" accept="image/*" capture="environment" className="hidden" onChange={e => handleFile(e.target.files?.[0])} />
          <button
            onClick={() => fileInput.current?.click()}
            disabled={scanning}
            className="w-full border-2 border-dashed border-foreground/15 hover:border-violet-500/40 rounded-2xl p-10 text-center transition-all bg-white/[0.02] hover:bg-violet-500/5"
          >
            {scanning ? (
              <><Loader2 className="mx-auto text-violet-400 mb-3 animate-spin" size={36} /><p className="text-foreground/60 text-sm">Reading receipt with AI...</p></>
            ) : (
              <><Upload className="mx-auto text-foreground/30 mb-3" size={36} /><p className="text-foreground/60 text-sm font-medium">Tap to take a photo or choose an image</p><p className="text-foreground/30 text-xs mt-1">JPG / PNG — bazar receipt, restaurant bill, invoice</p></>
            )}
          </button>
          {preview && (
            <div className="mt-4 rounded-2xl overflow-hidden border border-foreground/10">
              <img src={preview} alt="Receipt preview" className="w-full max-h-96 object-contain bg-black/40" />
            </div>
          )}
        </div>

        <div className="space-y-4">
          {items.length > 0 && (
            <>
              <div>
                <label className="block text-sm text-foreground/60 mb-1">Paid from account (all rows)</label>
                <select required value={accountId} onChange={e => setAccountId(e.target.value)} className="w-full bg-muted border border-foreground/10 rounded-xl px-4 py-2.5 text-foreground focus:outline-none focus:border-violet-500/50">
                  <option value="">Select an account...</option>
                  {accounts.map(a => <option key={a.id} value={a.id}>{a.name} ({a.currency}{a.current_balance})</option>)}
                </select>
              </div>
              <div className="space-y-2.5 max-h-96 overflow-y-auto pr-1">
                {items.map((it, i) => (
                  <div key={i} className="bg-card border border-foreground/10 rounded-xl p-3 space-y-2">
                    <div className="flex gap-2">
                      <input type="text" value={it.description} onChange={e => updateItem(i, { description: e.target.value })} placeholder="Description" className="flex-1 min-w-0 bg-muted border border-foreground/10 rounded-lg px-3 py-2 text-foreground text-sm focus:outline-none focus:border-violet-500/50" />
                      <input type="number" step="0.01" value={it.amount} onChange={e => updateItem(i, { amount: e.target.value })} placeholder="৳" className="w-24 bg-muted border border-foreground/10 rounded-lg px-3 py-2 text-foreground text-sm focus:outline-none focus:border-violet-500/50" />
                      <button onClick={() => setItems(prev => prev.filter((_, idx) => idx !== i))} className="text-foreground/30 hover:text-red-400 px-1"><Trash2 size={15} /></button>
                    </div>
                    <div className="flex gap-2">
                      <select value={it.category_id} onChange={e => updateItem(i, { category_id: e.target.value })} className={`flex-1 min-w-0 bg-muted border rounded-lg px-3 py-2 text-foreground text-sm focus:outline-none ${it.category_id ? 'border-foreground/10' : 'border-amber-500/40'}`}>
                        <option value="">Pick category...</option>
                        {catFor(it.type).map(c => <option key={c.id} value={c.id}>{c.icon} {c.name}</option>)}
                      </select>
                      <input type="date" value={it.date} onChange={e => updateItem(i, { date: e.target.value })} className="bg-muted border border-foreground/10 rounded-lg px-3 py-2 text-foreground text-sm focus:outline-none focus:border-violet-500/50" />
                    </div>
                  </div>
                ))}
              </div>
              <button onClick={saveAll} disabled={saving} className="w-full flex items-center justify-center gap-2 bg-violet-500 hover:bg-violet-600 disabled:opacity-50 text-white py-3 rounded-xl font-medium shadow-lg shadow-violet-500/20 transition-all">
                {saving ? <><Loader2 size={16} className="animate-spin" /> Saving...</> : <><Check size={16} /> Save {items.length} transaction{items.length > 1 ? 's' : ''}</>}
              </button>
            </>
          )}
          {items.length === 0 && !scanning && (
            <div className="h-full flex items-center justify-center border border-foreground/5 rounded-2xl bg-white/[0.02] py-16">
              <div className="text-center">
                <ScanLine className="mx-auto text-foreground/20 mb-3" size={40} />
                <p className="text-foreground/40 text-sm">Scanned items will appear here for review.</p>
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

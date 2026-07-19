import { useState } from 'react';
import Papa from 'papaparse';
import { supabase } from '../lib/supabase';
import { useAuth } from '../context/AuthContext';
import { useTransactions } from '../hooks/useTransactions';
import { useCategories } from '../hooks/useCategories';
import { useAccounts } from '../context/AccountContext';
import { Upload, ArrowRight, Check } from 'lucide-react';

// CSV only — bank PDF statements are too format-fragile to parse reliably
// without the AI/OCR capability this whole plan explicitly excludes.
export default function ImportTransactions() {
  const { user } = useAuth();
  const { importTransactionsBulk } = useTransactions();
  const { categories } = useCategories();
  const { accounts } = useAccounts();

  const [step, setStep] = useState(1); // 1 = pick file, 2 = map columns, 3 = preview & import
  const [csvRows, setCsvRows] = useState([]);
  const [csvColumns, setCsvColumns] = useState([]);
  const [colMap, setColMap] = useState({ date: '', description: '', amount: '' });
  const [accountId, setAccountId] = useState('');
  const [rows, setRows] = useState([]); // built preview rows
  const [remember, setRemember] = useState({}); // { [rowIndex]: boolean }
  const [importing, setImporting] = useState(false);
  const [result, setResult] = useState(null);

  const handleFile = (e) => {
    const file = e.target.files?.[0];
    if (!file) return;
    Papa.parse(file, {
      header: true,
      skipEmptyLines: true,
      complete: (res) => {
        setCsvRows(res.data);
        setCsvColumns(res.meta.fields || []);
        setColMap({ date: '', description: '', amount: '' });
        setStep(2);
      },
      error: (err) => alert('Could not read CSV: ' + err.message)
    });
  };

  const buildPreview = async () => {
    if (!colMap.date || !colMap.description || !colMap.amount || !accountId) {
      alert('Map date, description, amount and pick an account first.');
      return;
    }
    const { data: mappings } = await supabase
      .from('import_category_mappings').select('*').eq('user_id', user.id);

    const guessCategory = (description) => {
      const lower = (description || '').toLowerCase();
      const hit = (mappings || []).find(m => lower.includes(m.keyword.toLowerCase()));
      return hit?.category_id || '';
    };

    const built = csvRows.map(r => {
      const rawAmount = parseFloat(String(r[colMap.amount]).replace(/[,৳$\s]/g, ''));
      return {
        date: r[colMap.date],
        description: r[colMap.description] || '',
        amount: Math.abs(rawAmount || 0),
        type: rawAmount < 0 ? 'expense' : 'income',
        category_id: guessCategory(r[colMap.description])
      };
    }).filter(r => r.amount > 0 && r.date);

    setRows(built);
    setRemember(Object.fromEntries(built.map((_, i) => [i, true])));
    setStep(3);
  };

  const updateRow = (i, patch) => {
    setRows(rs => rs.map((r, idx) => idx === i ? { ...r, ...patch } : r));
  };

  const allCategorized = rows.length > 0 && rows.every(r => r.category_id);

  const handleImport = async () => {
    if (!allCategorized) return;
    setImporting(true);
    try {
      // Remember any new mappings first (per-row, keyword = full description —
      // matches by substring on future imports).
      const toRemember = rows
        .map((r, i) => ({ ...r, i }))
        .filter(r => remember[r.i] && r.description);
      for (const r of toRemember) {
        await supabase.from('import_category_mappings').upsert(
          { user_id: user.id, keyword: r.description.toLowerCase(), category_id: r.category_id },
          { onConflict: 'user_id,keyword' }
        );
      }

      const payload = rows.map(r => ({
        account_id: accountId,
        category_id: r.category_id,
        asset_id: null,
        type: r.type,
        amount: r.amount,
        date: r.date,
        description: r.description
      }));
      const ids = await importTransactionsBulk(payload);
      setResult({ count: ids.length });
    } catch (err) {
      alert('Import failed — no rows were saved: ' + err.message);
    } finally {
      setImporting(false);
    }
  };

  const reset = () => {
    setStep(1); setCsvRows([]); setCsvColumns([]); setColMap({ date: '', description: '', amount: '' });
    setRows([]); setResult(null);
  };

  return (
    <div className="space-y-6 animate-in max-w-4xl">
      <div>
        <h1 className="text-2xl font-bold text-foreground">Import Transactions</h1>
        <p className="text-foreground/40 text-sm mt-1">Bring in a bank statement CSV — map its columns, confirm categories, then import.</p>
      </div>

      {step === 1 && (
        <div className="bg-card border border-foreground/10 rounded-2xl p-10 text-center">
          <Upload className="mx-auto mb-4 text-foreground/20" size={40} />
          <p className="text-foreground/60 text-sm mb-4">Choose a CSV exported from your bank.</p>
          <label className="inline-flex items-center gap-2 bg-cyan-500 hover:bg-cyan-600 text-white px-5 py-2.5 rounded-xl cursor-pointer font-medium">
            <Upload size={16} /> Choose CSV file
            <input type="file" accept=".csv,text/csv" onChange={handleFile} className="hidden" />
          </label>
        </div>
      )}

      {step === 2 && (
        <div className="bg-card border border-foreground/10 rounded-2xl p-6 space-y-4">
          <h2 className="text-lg font-semibold text-foreground">Map Columns</h2>
          <p className="text-foreground/40 text-xs">{csvRows.length} rows found. Tell us which CSV column is which.</p>
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div>
              <label className="block text-sm text-foreground/60 mb-1">Date column</label>
              <select value={colMap.date} onChange={e => setColMap({ ...colMap, date: e.target.value })} className="w-full bg-muted border border-foreground/10 rounded-xl px-4 py-2.5 text-foreground focus:outline-none focus:border-cyan-500/50">
                <option value="">Select...</option>
                {csvColumns.map(c => <option key={c} value={c}>{c}</option>)}
              </select>
            </div>
            <div>
              <label className="block text-sm text-foreground/60 mb-1">Description column</label>
              <select value={colMap.description} onChange={e => setColMap({ ...colMap, description: e.target.value })} className="w-full bg-muted border border-foreground/10 rounded-xl px-4 py-2.5 text-foreground focus:outline-none focus:border-cyan-500/50">
                <option value="">Select...</option>
                {csvColumns.map(c => <option key={c} value={c}>{c}</option>)}
              </select>
            </div>
            <div>
              <label className="block text-sm text-foreground/60 mb-1">Amount column</label>
              <select value={colMap.amount} onChange={e => setColMap({ ...colMap, amount: e.target.value })} className="w-full bg-muted border border-foreground/10 rounded-xl px-4 py-2.5 text-foreground focus:outline-none focus:border-cyan-500/50">
                <option value="">Select...</option>
                {csvColumns.map(c => <option key={c} value={c}>{c}</option>)}
              </select>
              <p className="text-foreground/30 text-xs mt-1">Negative = expense, positive = income (adjust per row after).</p>
            </div>
            <div>
              <label className="block text-sm text-foreground/60 mb-1">Import into account</label>
              <select value={accountId} onChange={e => setAccountId(e.target.value)} className="w-full bg-muted border border-foreground/10 rounded-xl px-4 py-2.5 text-foreground focus:outline-none focus:border-cyan-500/50">
                <option value="">Select account...</option>
                {accounts.map(a => <option key={a.id} value={a.id}>{a.name}</option>)}
              </select>
            </div>
          </div>
          <div className="flex justify-end gap-3">
            <button onClick={reset} className="px-5 py-2.5 rounded-xl text-foreground/60 hover:text-foreground hover:bg-foreground/5">Cancel</button>
            <button onClick={buildPreview} className="flex items-center gap-2 bg-cyan-500 hover:bg-cyan-600 text-white px-6 py-2.5 rounded-xl font-medium">
              Preview <ArrowRight size={16} />
            </button>
          </div>
        </div>
      )}

      {step === 3 && !result && (
        <div className="bg-card border border-foreground/10 rounded-2xl p-6 space-y-4">
          <div className="flex items-center justify-between">
            <h2 className="text-lg font-semibold text-foreground">Preview ({rows.length} rows)</h2>
            {!allCategorized && <p className="text-orange-400 text-xs">Pick a category for every row to enable import.</p>}
          </div>
          <div className="overflow-x-auto max-h-[420px] overflow-y-auto rounded-xl border border-foreground/10">
            <table className="w-full text-sm">
              <thead className="sticky top-0 bg-muted">
                <tr className="text-left text-foreground/50">
                  <th className="px-3 py-2">Date</th>
                  <th className="px-3 py-2">Description</th>
                  <th className="px-3 py-2 text-right">Amount</th>
                  <th className="px-3 py-2">Type</th>
                  <th className="px-3 py-2">Category</th>
                  <th className="px-3 py-2">Remember</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-foreground/5">
                {rows.map((r, i) => (
                  <tr key={i}>
                    <td className="px-3 py-2 text-foreground/70 whitespace-nowrap">{r.date}</td>
                    <td className="px-3 py-2 text-foreground/70 max-w-[220px] truncate" title={r.description}>{r.description}</td>
                    <td className="px-3 py-2 text-right text-foreground">৳{r.amount.toLocaleString()}</td>
                    <td className="px-3 py-2">
                      <select value={r.type} onChange={e => updateRow(i, { type: e.target.value })} className="bg-muted border border-foreground/10 rounded-lg px-2 py-1 text-foreground text-xs">
                        <option value="expense">Expense</option>
                        <option value="income">Income</option>
                      </select>
                    </td>
                    <td className="px-3 py-2">
                      <select
                        value={r.category_id}
                        onChange={e => updateRow(i, { category_id: e.target.value })}
                        className={`bg-muted border rounded-lg px-2 py-1 text-xs ${r.category_id ? 'border-foreground/10 text-foreground' : 'border-orange-500/50 text-orange-400'}`}
                      >
                        <option value="">Select...</option>
                        {categories.filter(c => c.type === r.type).map(c => (
                          <option key={c.id} value={c.id}>{c.icon} {c.name}</option>
                        ))}
                      </select>
                    </td>
                    <td className="px-3 py-2 text-center">
                      <input type="checkbox" checked={!!remember[i]} onChange={e => setRemember(rm => ({ ...rm, [i]: e.target.checked }))} className="accent-cyan-500" />
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <div className="flex justify-end gap-3">
            <button onClick={reset} className="px-5 py-2.5 rounded-xl text-foreground/60 hover:text-foreground hover:bg-foreground/5">Cancel</button>
            <button
              onClick={handleImport}
              disabled={!allCategorized || importing}
              className="flex items-center gap-2 bg-cyan-500 hover:bg-cyan-600 text-white px-6 py-2.5 rounded-xl font-medium disabled:opacity-40"
            >
              {importing ? 'Importing...' : `Import ${rows.length} Transactions`}
            </button>
          </div>
        </div>
      )}

      {result && (
        <div className="bg-card border border-emerald-500/20 rounded-2xl p-10 text-center">
          <Check className="mx-auto mb-4 text-emerald-400" size={40} />
          <p className="text-foreground font-medium">Imported {result.count} transactions.</p>
          <button onClick={reset} className="mt-4 text-cyan-400 hover:underline text-sm">Import another file</button>
        </div>
      )}
    </div>
  );
}

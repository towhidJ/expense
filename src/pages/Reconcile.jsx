import { useState } from 'react';
import { Link } from 'react-router';
import Papa from 'papaparse';
import { useTransactions } from '../hooks/useTransactions';
import { useCategories } from '../hooks/useCategories';
import { useAccounts } from '../context/AccountContext';
import StatCard from '../components/StatCard';
import { Upload, CheckCircle2, AlertCircle, ArrowRight, ScanSearch } from 'lucide-react';

const fmt = (n) => `৳${Math.round(Number(n || 0)).toLocaleString()}`;
const DAY_MS = 86400000;
const MATCH_WINDOW_DAYS = 3;

export default function Reconcile() {
  const { transactions, importTransactionsBulk } = useTransactions();
  const { categories } = useCategories();
  const { accounts } = useAccounts();

  const [step, setStep] = useState(1);
  const [accountId, setAccountId] = useState('');
  const [csvRows, setCsvRows] = useState([]);
  const [csvColumns, setCsvColumns] = useState([]);
  const [colMap, setColMap] = useState({ date: '', description: '', amount: '' });
  const [diff, setDiff] = useState(null); // { matched, missingInApp, staleInApp }
  const [selected, setSelected] = useState({});
  const [expenseCategoryId, setExpenseCategoryId] = useState('');
  const [incomeCategoryId, setIncomeCategoryId] = useState('');
  const [importing, setImporting] = useState(false);
  const [result, setResult] = useState(null);

  const expenseCategories = categories?.filter(c => c.type === 'expense') || [];
  const incomeCategories = categories?.filter(c => c.type === 'income') || [];

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

  const buildDiff = () => {
    if (!colMap.date || !colMap.description || !colMap.amount || !accountId) {
      alert('Map date, description, amount and pick an account first.');
      return;
    }
    const statementRows = csvRows.map(r => {
      const rawAmount = parseFloat(String(r[colMap.amount]).replace(/[,৳$\s]/g, ''));
      const d = new Date(r[colMap.date]);
      return {
        date: r[colMap.date],
        dateMs: d.getTime(),
        description: r[colMap.description] || '',
        amount: Math.abs(rawAmount || 0),
        type: rawAmount < 0 ? 'expense' : 'income'
      };
    }).filter(r => r.amount > 0 && !isNaN(r.dateMs));

    if (statementRows.length === 0) {
      alert('No usable rows found — check the column mapping.');
      return;
    }

    const appRows = transactions.filter(t => t.account_id === accountId);
    const claimedAppIds = new Set();
    const missingInApp = [];
    const matched = [];

    statementRows.forEach(sr => {
      const hit = appRows.find(ar =>
        !claimedAppIds.has(ar.id) &&
        ar.type === sr.type &&
        Math.abs(Number(ar.amount) - sr.amount) < 1 &&
        Math.abs(new Date(ar.date).getTime() - sr.dateMs) <= MATCH_WINDOW_DAYS * DAY_MS
      );
      if (hit) { claimedAppIds.add(hit.id); matched.push({ statement: sr, app: hit }); }
      else missingInApp.push(sr);
    });

    const minDate = Math.min(...statementRows.map(r => r.dateMs));
    const maxDate = Math.max(...statementRows.map(r => r.dateMs));
    const staleInApp = appRows.filter(ar => {
      const t = new Date(ar.date).getTime();
      return !claimedAppIds.has(ar.id) && t >= minDate - DAY_MS * MATCH_WINDOW_DAYS && t <= maxDate + DAY_MS * MATCH_WINDOW_DAYS;
    });

    setDiff({ matched, missingInApp, staleInApp });
    setSelected(Object.fromEntries(missingInApp.map((_, i) => [i, true])));
    setStep(3);
  };

  const missingExpenseCount = diff?.missingInApp.filter(r => r.type === 'expense').length || 0;
  const missingIncomeCount = diff?.missingInApp.filter(r => r.type === 'income').length || 0;

  const handleImport = async () => {
    const toImport = diff.missingInApp.filter((_, i) => selected[i]);
    if (toImport.some(r => r.type === 'expense') && !expenseCategoryId) { alert('Pick an expense category for the missing expense rows.'); return; }
    if (toImport.some(r => r.type === 'income') && !incomeCategoryId) { alert('Pick an income category for the missing income rows.'); return; }
    setImporting(true);
    try {
      const rows = toImport.map(r => ({
        account_id: accountId,
        category_id: r.type === 'expense' ? expenseCategoryId : incomeCategoryId,
        type: r.type,
        amount: r.amount,
        date: new Date(r.date).toISOString().split('T')[0],
        description: r.description
      }));
      const ids = await importTransactionsBulk(rows);
      setResult({ count: ids.length });
    } catch (err) {
      alert('Import failed: ' + err.message);
    }
    setImporting(false);
  };

  const reset = () => {
    setStep(1); setAccountId(''); setCsvRows([]); setCsvColumns([]); setColMap({ date: '', description: '', amount: '' });
    setDiff(null); setSelected({}); setExpenseCategoryId(''); setIncomeCategoryId(''); setResult(null);
  };

  return (
    <div className="space-y-6 animate-in">
      <div>
        <h1 className="text-2xl font-bold text-white">Bank Reconciliation</h1>
        <p className="text-white/40 text-sm mt-1">
          Upload a bank/mobile-banking CSV statement and find transactions missing from your ledger.
          Blind-importing everything? Use <Link to="/import" className="text-cyan-400 hover:underline">Import</Link> instead.
        </p>
      </div>

      {step === 1 && (
        <div className="bg-[#1a1a2e] border border-white/10 rounded-2xl p-8 text-center space-y-4">
          <ScanSearch className="mx-auto text-white/20" size={48} />
          <div>
            <label className="block text-sm text-white/60 mb-2">Which account is this statement for?</label>
            <select value={accountId} onChange={e => setAccountId(e.target.value)} className="w-full max-w-sm mx-auto bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-cyan-500/50">
              <option value="">Select an account...</option>
              {accounts.map(a => <option key={a.id} value={a.id}>{a.name}</option>)}
            </select>
          </div>
          <label className={`inline-flex items-center gap-2 px-6 py-3 rounded-xl font-medium cursor-pointer transition-colors ${accountId ? 'bg-cyan-500 hover:bg-cyan-600 text-white' : 'bg-white/5 text-white/30 cursor-not-allowed'}`}>
            <Upload size={16} /> Choose CSV File
            <input type="file" accept=".csv" disabled={!accountId} onChange={handleFile} className="hidden" />
          </label>
        </div>
      )}

      {step === 2 && (
        <div className="bg-[#1a1a2e] border border-white/10 rounded-2xl p-6 space-y-4">
          <h2 className="text-lg font-semibold text-white">Map Columns</h2>
          <p className="text-sm text-white/40">{csvRows.length} rows found. Match your CSV's columns to date/description/amount (negative = expense).</p>
          <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
            {['date', 'description', 'amount'].map(field => (
              <div key={field}>
                <label className="block text-sm text-white/60 mb-1 capitalize">{field}</label>
                <select value={colMap[field]} onChange={e => setColMap({ ...colMap, [field]: e.target.value })} className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-cyan-500/50">
                  <option value="">Select column...</option>
                  {csvColumns.map(c => <option key={c} value={c}>{c}</option>)}
                </select>
              </div>
            ))}
          </div>
          <div className="flex justify-end gap-3">
            <button onClick={() => setStep(1)} className="px-5 py-2.5 rounded-xl text-white/60 hover:text-white hover:bg-white/5 transition-colors">Back</button>
            <button onClick={buildDiff} className="flex items-center gap-2 bg-cyan-500 hover:bg-cyan-600 text-white px-6 py-2.5 rounded-xl shadow-lg shadow-cyan-500/20 transition-all font-medium">
              Compare <ArrowRight size={16} />
            </button>
          </div>
        </div>
      )}

      {step === 3 && diff && !result && (
        <>
          <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
            <StatCard title="Matched" value={diff.matched.length} icon={CheckCircle2} gradient={["#34d399", "#10b981"]} iconBg="bg-emerald-500/10" />
            <StatCard title="Missing In App" value={diff.missingInApp.length} icon={AlertCircle} gradient={["#f59e0b", "#d97706"]} iconBg="bg-amber-500/10" />
            <StatCard title="In App, Not In Statement" value={diff.staleInApp.length} icon={AlertCircle} gradient={["#f87171", "#ef4444"]} iconBg="bg-red-500/10" />
          </div>

          {diff.missingInApp.length > 0 ? (
            <div className="bg-[#1a1a2e] border border-white/10 rounded-2xl overflow-hidden">
              <div className="px-5 py-4 border-b border-white/10 flex flex-wrap items-center gap-3">
                <h2 className="text-white font-semibold">Missing In App — import these?</h2>
                <div className="ml-auto flex gap-3">
                  {missingExpenseCount > 0 && (
                    <select value={expenseCategoryId} onChange={e => setExpenseCategoryId(e.target.value)} className="bg-[#12122a] border border-white/10 rounded-xl px-3 py-2 text-white text-sm focus:outline-none focus:border-cyan-500/50">
                      <option value="">Expense category...</option>
                      {expenseCategories.map(c => <option key={c.id} value={c.id}>{c.icon} {c.name}</option>)}
                    </select>
                  )}
                  {missingIncomeCount > 0 && (
                    <select value={incomeCategoryId} onChange={e => setIncomeCategoryId(e.target.value)} className="bg-[#12122a] border border-white/10 rounded-xl px-3 py-2 text-white text-sm focus:outline-none focus:border-cyan-500/50">
                      <option value="">Income category...</option>
                      {incomeCategories.map(c => <option key={c.id} value={c.id}>{c.icon} {c.name}</option>)}
                    </select>
                  )}
                </div>
              </div>
              <div className="overflow-x-auto">
                <table className="w-full text-sm">
                  <thead>
                    <tr className="bg-white/5 border-b border-white/10">
                      <th className="text-left py-2.5 px-5"></th>
                      <th className="text-left py-2.5 px-5 text-white/60 font-medium">Date</th>
                      <th className="text-left py-2.5 px-5 text-white/60 font-medium">Description</th>
                      <th className="text-left py-2.5 px-5 text-white/60 font-medium">Type</th>
                      <th className="text-right py-2.5 px-5 text-white/60 font-medium">Amount</th>
                    </tr>
                  </thead>
                  <tbody>
                    {diff.missingInApp.map((r, i) => (
                      <tr key={i} className="border-b border-white/5 hover:bg-white/[0.02]">
                        <td className="py-2 px-5"><input type="checkbox" checked={!!selected[i]} onChange={e => setSelected({ ...selected, [i]: e.target.checked })} className="w-4 h-4 rounded accent-cyan-500" /></td>
                        <td className="py-2 px-5 text-white/70">{r.date}</td>
                        <td className="py-2 px-5 text-white/60">{r.description}</td>
                        <td className="py-2 px-5"><span className={r.type === 'expense' ? 'text-red-400' : 'text-emerald-400'}>{r.type}</span></td>
                        <td className="py-2 px-5 text-right text-white">{fmt(r.amount)}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
              <div className="px-5 py-4 border-t border-white/10 flex justify-end gap-3">
                <button onClick={reset} className="px-5 py-2.5 rounded-xl text-white/60 hover:text-white hover:bg-white/5 transition-colors">Start Over</button>
                <button onClick={handleImport} disabled={importing} className="bg-cyan-500 hover:bg-cyan-600 text-white px-6 py-2.5 rounded-xl shadow-lg shadow-cyan-500/20 transition-all font-medium disabled:opacity-50">
                  {importing ? 'Importing...' : `Import ${Object.values(selected).filter(Boolean).length} Selected`}
                </button>
              </div>
            </div>
          ) : (
            <div className="text-center py-12 border border-white/5 rounded-2xl bg-white/[0.02]">
              <CheckCircle2 className="mx-auto text-emerald-400/50 mb-4" size={48} />
              <h3 className="text-white/60 font-medium">Everything in the statement is already in your ledger.</h3>
              <button onClick={reset} className="mt-4 text-sm text-cyan-400 hover:underline">Reconcile another statement</button>
            </div>
          )}

          {diff.staleInApp.length > 0 && (
            <div className="bg-[#1a1a2e] border border-white/10 rounded-2xl overflow-hidden">
              <h2 className="text-white font-semibold px-5 pt-4 pb-2">In App, Not Seen In Statement</h2>
              <p className="text-xs text-white/40 px-5 pb-3">These app transactions in the same date range didn't match a statement row — worth a second look.</p>
              <div className="overflow-x-auto">
                <table className="w-full text-sm">
                  <tbody>
                    {diff.staleInApp.map(t => (
                      <tr key={t.id} className="border-t border-white/5">
                        <td className="py-2 px-5 text-white/70">{new Date(t.date).toLocaleDateString()}</td>
                        <td className="py-2 px-5 text-white/60">{t.description || t.categories?.name || '—'}</td>
                        <td className="py-2 px-5 text-right text-white">{fmt(t.amount)}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>
          )}
        </>
      )}

      {result && (
        <div className="text-center py-12 border border-emerald-500/20 bg-emerald-500/5 rounded-2xl">
          <CheckCircle2 className="mx-auto text-emerald-400 mb-4" size={48} />
          <h3 className="text-white font-semibold text-lg">Imported {result.count} transactions</h3>
          <button onClick={reset} className="mt-4 text-sm text-cyan-400 hover:underline">Reconcile another statement</button>
        </div>
      )}
    </div>
  );
}

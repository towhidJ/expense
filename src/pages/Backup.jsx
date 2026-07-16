import { useState } from 'react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../context/AuthContext';
import { useEntity } from '../context/EntityContext';
import { DatabaseBackup, FileJson, FileSpreadsheet, Download } from 'lucide-react';

// Every entity-scoped table worth exporting (money data + records).
const EXPORT_TABLES = [
  'accounts', 'categories', 'transactions', 'transfers', 'budgets', 'goals',
  'savings', 'saving_heads', 'recurring_transactions', 'recurring_savings',
  'assets', 'liabilities', 'loan_repayments', 'investments', 'family_members',
  'bazar_purchases', 'insurance_policies', 'utility_bills', 'rental_units',
  'rent_payments', 'split_events', 'split_members', 'split_expenses'
];

function downloadBlob(content, filename, type) {
  const blob = new Blob([content], { type });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = filename;
  a.click();
  URL.revokeObjectURL(url);
}

function toCSV(rows) {
  if (!rows.length) return '';
  const cols = Object.keys(rows[0]);
  const esc = (v) => {
    if (v == null) return '';
    const s = typeof v === 'object' ? JSON.stringify(v) : String(v);
    return /[",\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
  };
  return [cols.join(','), ...rows.map(r => cols.map(c => esc(r[c])).join(','))].join('\n');
}

export default function Backup() {
  const { user } = useAuth();
  const { currentEntity } = useEntity();
  const [busy, setBusy] = useState(false);
  const [progress, setProgress] = useState('');
  const [lastCounts, setLastCounts] = useState(null);

  const fetchAll = async () => {
    const dump = {};
    const counts = {};
    for (const table of EXPORT_TABLES) {
      setProgress(`Fetching ${table}...`);
      const { data, error } = await supabase
        .from(table)
        .select('*')
        .eq('user_id', user.id)
        .eq('entity_id', currentEntity.id);
      if (error) {
        // table may not exist yet if a migration wasn't run — skip, don't fail the backup
        console.warn(`Skipping ${table}:`, error.message);
        continue;
      }
      dump[table] = data || [];
      counts[table] = (data || []).length;
    }
    setLastCounts(counts);
    return dump;
  };

  const stamp = () => new Date().toISOString().split('T')[0];

  const exportJSON = async () => {
    setBusy(true);
    try {
      const dump = await fetchAll();
      downloadBlob(
        JSON.stringify({ exported_at: new Date().toISOString(), entity: currentEntity.name, app: 'TakaKhata', tables: dump }, null, 2),
        `takakhata-backup-${currentEntity.name}-${stamp()}.json`,
        'application/json'
      );
    } catch (err) {
      alert('Backup failed: ' + err.message);
    }
    setProgress('');
    setBusy(false);
  };

  const exportCSVs = async () => {
    setBusy(true);
    try {
      const dump = await fetchAll();
      for (const [table, rows] of Object.entries(dump)) {
        if (rows.length) downloadBlob(toCSV(rows), `takakhata-${table}-${stamp()}.csv`, 'text/csv');
      }
    } catch (err) {
      alert('Export failed: ' + err.message);
    }
    setProgress('');
    setBusy(false);
  };

  return (
    <div className="space-y-6 animate-in max-w-3xl">
      <div>
        <h1 className="text-2xl font-bold text-white">Backup & Export</h1>
        <p className="text-white/40 text-sm mt-1">Download everything in the "{currentEntity?.name}" workspace. Keep a copy somewhere safe (Google Drive, pen drive).</p>
      </div>

      <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
        <div className="bg-[#1a1a2e] border border-white/10 rounded-2xl p-6">
          <FileJson className="text-cyan-400 mb-3" size={28} />
          <h3 className="text-white font-semibold mb-1">Full Backup (JSON)</h3>
          <p className="text-white/40 text-xs mb-4">One file with every table — best for safe-keeping and future restore.</p>
          <button onClick={exportJSON} disabled={busy} className="w-full flex items-center justify-center gap-2 bg-cyan-500 hover:bg-cyan-600 disabled:opacity-50 text-white px-4 py-2.5 rounded-xl font-medium transition-all">
            <Download size={16} /> {busy ? progress || 'Working...' : 'Download JSON'}
          </button>
        </div>
        <div className="bg-[#1a1a2e] border border-white/10 rounded-2xl p-6">
          <FileSpreadsheet className="text-emerald-400 mb-3" size={28} />
          <h3 className="text-white font-semibold mb-1">Spreadsheets (CSV)</h3>
          <p className="text-white/40 text-xs mb-4">One CSV per table — open in Excel / Google Sheets. Empty tables are skipped.</p>
          <button onClick={exportCSVs} disabled={busy} className="w-full flex items-center justify-center gap-2 bg-emerald-500 hover:bg-emerald-600 disabled:opacity-50 text-white px-4 py-2.5 rounded-xl font-medium transition-all">
            <Download size={16} /> {busy ? progress || 'Working...' : 'Download CSVs'}
          </button>
        </div>
      </div>

      {lastCounts && (
        <div className="bg-[#1a1a2e] border border-white/10 rounded-2xl p-5">
          <h3 className="text-white font-semibold text-sm mb-3 flex items-center gap-2"><DatabaseBackup size={16} className="text-cyan-400" /> Last export contents</h3>
          <div className="grid grid-cols-2 sm:grid-cols-3 gap-x-6 gap-y-1.5">
            {Object.entries(lastCounts).filter(([, n]) => n > 0).map(([table, n]) => (
              <div key={table} className="flex justify-between text-xs">
                <span className="text-white/50">{table.replace(/_/g, ' ')}</span>
                <span className="text-white/80 font-medium">{n}</span>
              </div>
            ))}
          </div>
        </div>
      )}

      <p className="text-xs text-white/30">
        Note: uploaded documents (receipts, agreements) live in Supabase Storage and are not inside these files — they stay linked by URL in the attachments data.
      </p>
    </div>
  );
}

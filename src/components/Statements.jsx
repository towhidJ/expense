import { useMemo } from 'react';
import { FileText } from 'lucide-react';
import { downloadHtmlAsPdf, statementHtml } from '../lib/htmlPdf';

const fmt = (n) => '৳' + Number(n || 0).toLocaleString('en-IN', { maximumFractionDigits: 2 });
const pdfNum = (n) => '৳' + Number(n || 0).toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 });

function StatementCard({ entityName, title, subtitle, onExport, children }) {
  return (
    <div className="bg-[#1a1a2e] border border-white/10 rounded-2xl overflow-hidden">
      <div className="relative border-b border-white/10 px-6 py-5 text-center">
        <p className="text-xs uppercase tracking-[0.2em] text-cyan-400/70">{entityName || 'ExpenseTracker'}</p>
        <h2 className="text-xl font-bold text-white mt-1">{title}</h2>
        <p className="text-white/40 text-xs mt-1">{subtitle}</p>
        <button
          onClick={onExport}
          className="absolute right-4 top-1/2 -translate-y-1/2 flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs bg-red-500/20 text-red-400 hover:bg-red-500/30 transition-all font-medium"
        >
          <FileText size={14} /> PDF
        </button>
      </div>
      <div className="p-4 sm:p-6">{children}</div>
    </div>
  );
}

const SectionRow = ({ label }) => (
  <tr><td colSpan="2" className="pt-4 pb-1.5 px-3 text-[11px] font-bold uppercase tracking-wider text-cyan-400/80">{label}</td></tr>
);
const LineRow = ({ label, value, indent = true, muted = false }) => (
  <tr className="hover:bg-white/[0.02]">
    <td className={`py-1.5 px-3 ${indent ? 'pl-7' : ''} ${muted ? 'text-white/40 italic text-xs' : 'text-white/70'}`}>{label}</td>
    <td className={`py-1.5 px-3 text-right tabular-nums ${muted ? 'text-white/40 text-xs' : 'text-white/80'}`}>{value}</td>
  </tr>
);
const TotalRow = ({ label, value, color = 'text-white' }) => (
  <tr className="border-t border-white/15">
    <td className={`py-2 px-3 font-semibold ${color}`}>{label}</td>
    <td className={`py-2 px-3 text-right font-bold tabular-nums ${color}`}>{value}</td>
  </tr>
);
const NetRow = ({ label, value, positive }) => (
  <tr>
    <td colSpan="2" className="pt-3 px-0">
      <div className={`flex justify-between items-center rounded-xl px-4 py-3 border font-bold ${
        positive ? 'bg-emerald-500/10 border-emerald-500/25 text-emerald-300' : 'bg-red-500/10 border-red-500/25 text-red-300'
      }`}>
        <span>{label}</span>
        <span className="tabular-nums">{value}</span>
      </div>
    </td>
  </tr>
);

function byCategory(txs) {
  const map = {};
  txs.forEach(t => {
    const name = t.categories?.name || 'Other';
    map[name] = (map[name] || 0) + Number(t.amount);
  });
  return Object.entries(map).map(([name, value]) => ({ name, value })).sort((a, b) => b.value - a.value);
}

// Rendered via the browser (html2canvas) so Bangla text and ৳ come out correctly —
// jsPDF's built-in fonts cannot shape Bengali script.
function exportStatementPDF({ entityName, title, subtitle, sections, fileName }) {
  downloadHtmlAsPdf(
    statementHtml({
      entityName,
      title,
      subtitle,
      head: sections.head,
      rows: sections.body,
      boldRows: sections.boldRows || []
    }),
    fileName
  );
}

// ---------------- Income Statement ----------------
export function IncomeStatement({ periodTx, periodLabel, entityName }) {
  const income = useMemo(() => byCategory(periodTx.filter(t => t.type === 'income')), [periodTx]);
  const expense = useMemo(() => byCategory(periodTx.filter(t => t.type === 'expense')), [periodTx]);
  const totalIncome = income.reduce((s, r) => s + r.value, 0);
  const totalExpense = expense.reduce((s, r) => s + r.value, 0);
  const net = totalIncome - totalExpense;

  const exportPDF = () => {
    const body = [];
    const boldRows = [];
    body.push(['INCOME', '']);
    income.forEach(r => body.push(['   ' + r.name, pdfNum(r.value)]));
    boldRows.push(body.length);
    body.push(['Total Income', pdfNum(totalIncome)]);
    body.push(['EXPENSES', '']);
    expense.forEach(r => body.push(['   ' + r.name, pdfNum(r.value)]));
    boldRows.push(body.length);
    body.push(['Total Expenses', pdfNum(totalExpense)]);
    boldRows.push(body.length);
    body.push([net >= 0 ? 'NET SURPLUS' : 'NET DEFICIT', pdfNum(Math.abs(net))]);
    exportStatementPDF({
      entityName,
      title: 'Income Statement',
      subtitle: `For the period: ${periodLabel} (Amounts in ৳)`,
      sections: { head: ['Particulars', 'Amount'], body, boldRows, columnStyles: { 1: { halign: 'right' } } },
      fileName: `Income_Statement_${periodLabel.replace(/[^a-zA-Z0-9]/g, '_')}.pdf`
    });
  };

  return (
    <StatementCard entityName={entityName} title="Income Statement" subtitle={`For the period: ${periodLabel}`} onExport={exportPDF}>
      <table className="w-full text-sm">
        <tbody>
          <SectionRow label="Income (আয়)" />
          {income.length === 0 && <LineRow label="No income recorded" value="—" muted />}
          {income.map(r => <LineRow key={r.name} label={r.name} value={fmt(r.value)} />)}
          <TotalRow label="Total Income" value={fmt(totalIncome)} color="text-emerald-400" />

          <SectionRow label="Expenses (ব্যয়)" />
          {expense.length === 0 && <LineRow label="No expenses recorded" value="—" muted />}
          {expense.map(r => <LineRow key={r.name} label={r.name} value={fmt(r.value)} />)}
          <TotalRow label="Total Expenses" value={fmt(totalExpense)} color="text-red-400" />

          <NetRow label={net >= 0 ? 'Net Surplus (নীট উদ্বৃত্ত)' : 'Net Deficit (নীট ঘাটতি)'} value={fmt(Math.abs(net))} positive={net >= 0} />
          {totalIncome > 0 && (
            <LineRow label="Savings rate" value={`${((net / totalIncome) * 100).toFixed(1)}%`} indent={false} muted />
          )}
        </tbody>
      </table>
    </StatementCard>
  );
}

// ---------------- Cash Flow Statement ----------------
export function CashFlowStatement({ periodTx, savings, repayments, liabilities, transfers, accounts, periodLabel, entityName, inPeriod }) {
  const d = useMemo(() => {
    const cashIncome = periodTx.filter(t => t.type === 'income' && t.account_id).reduce((s, t) => s + Number(t.amount), 0);
    const cashExpense = periodTx.filter(t => t.type === 'expense' && t.account_id).reduce((s, t) => s + Number(t.amount), 0);
    const creditPurchases = periodTx.filter(t => t.type === 'expense' && !t.account_id).reduce((s, t) => s + Number(t.amount), 0);

    const periodSavings = savings.filter(s => s.account_id && inPeriod(s.date));
    const savingsOut = periodSavings.filter(s => s.type === 'deposit').reduce((s, e) => s + Number(e.amount), 0);
    const savingsIn = periodSavings.filter(s => s.type !== 'deposit').reduce((s, e) => s + Number(e.amount), 0);

    const givenIds = new Set(liabilities.filter(l => l.type === 'loan_given').map(l => l.id));
    const shopIds = new Set(liabilities.filter(l => l.type === 'shop_due').map(l => l.id));
    const periodRepay = repayments.filter(r => r.account_id && inPeriod(r.date));
    const collectionsIn = periodRepay.filter(r => givenIds.has(r.liability_id)).reduce((s, r) => s + Number(r.amount), 0);
    const shopPaymentsOut = periodRepay.filter(r => shopIds.has(r.liability_id)).reduce((s, r) => s + Number(r.amount), 0);
    const loanPaymentsOut = periodRepay.filter(r => !givenIds.has(r.liability_id) && !shopIds.has(r.liability_id)).reduce((s, r) => s + Number(r.amount), 0);

    const transferVolume = transfers.filter(t => inPeriod(t.date)).reduce((s, t) => s + Number(t.amount), 0);
    const totalBalance = accounts.reduce((s, a) => s + Number(a.current_balance || 0), 0);

    const operating = cashIncome - cashExpense;
    const savingsNet = savingsIn - savingsOut;
    const financing = collectionsIn - shopPaymentsOut - loanPaymentsOut;
    return {
      cashIncome, cashExpense, creditPurchases, savingsIn, savingsOut, collectionsIn,
      shopPaymentsOut, loanPaymentsOut, transferVolume, totalBalance,
      operating, savingsNet, financing, net: operating + savingsNet + financing
    };
  }, [periodTx, savings, repayments, liabilities, transfers, accounts, inPeriod]);

  const rows = [
    ['section', 'A. Operating Activities (আয়-ব্যয়)'],
    ['line', 'Income received in cash/bank', d.cashIncome],
    ['line', 'Expenses paid in cash/bank', -d.cashExpense],
    ['total', 'Net Cash from Operations', d.operating],
    ['section', 'B. Savings Activities (সঞ্চয়)'],
    ['line', 'Withdrawn from savings', d.savingsIn],
    ['line', 'Deposited to savings', -d.savingsOut],
    ['total', 'Net Cash from Savings', d.savingsNet],
    ['section', 'C. Financing Activities (ঋণ ও বাকি)'],
    ['line', 'Collections from loans given', d.collectionsIn],
    ['line', 'Shop due payments (দোকান বাকি)', -d.shopPaymentsOut],
    ['line', 'Loan repayments made', -d.loanPaymentsOut],
    ['total', 'Net Cash from Financing', d.financing]
  ];

  const exportPDF = () => {
    const body = [];
    const boldRows = [];
    rows.forEach(([kind, label, value]) => {
      if (kind === 'section') body.push([label, '']);
      else if (kind === 'line') body.push(['   ' + label, pdfNum(value)]);
      else { boldRows.push(body.length); body.push([label, pdfNum(value)]); }
    });
    boldRows.push(body.length);
    body.push([d.net >= 0 ? 'NET INCREASE IN CASH' : 'NET DECREASE IN CASH', pdfNum(d.net)]);
    body.push(['Memo: purchases on credit (no cash impact)', pdfNum(d.creditPurchases)]);
    body.push(['Memo: internal transfers (no net effect)', pdfNum(d.transferVolume)]);
    body.push(['Total cash & bank balance today', pdfNum(d.totalBalance)]);
    exportStatementPDF({
      entityName,
      title: 'Cash Flow Statement',
      subtitle: `For the period: ${periodLabel} (Amounts in ৳)`,
      sections: { head: ['Particulars', 'Amount'], body, boldRows, columnStyles: { 1: { halign: 'right' } } },
      fileName: `Cash_Flow_${periodLabel.replace(/[^a-zA-Z0-9]/g, '_')}.pdf`
    });
  };

  const signed = (v) => (v < 0 ? `(${fmt(Math.abs(v))})` : fmt(v));

  return (
    <StatementCard entityName={entityName} title="Cash Flow Statement" subtitle={`For the period: ${periodLabel}`} onExport={exportPDF}>
      <table className="w-full text-sm">
        <tbody>
          {rows.map(([kind, label, value], i) =>
            kind === 'section' ? <SectionRow key={i} label={label} />
            : kind === 'line' ? <LineRow key={i} label={label} value={signed(value)} />
            : <TotalRow key={i} label={label} value={signed(value)} color={value >= 0 ? 'text-emerald-400' : 'text-red-400'} />
          )}
          <NetRow label={d.net >= 0 ? 'Net Increase in Cash (নগদ বৃদ্ধি)' : 'Net Decrease in Cash (নগদ হ্রাস)'} value={signed(d.net)} positive={d.net >= 0} />
          <LineRow label={`Memo: purchases on credit this period (no cash impact) — ${fmt(d.creditPurchases)}`} value="" indent={false} muted />
          <LineRow label={`Memo: internal transfers between accounts — ${fmt(d.transferVolume)} (no net effect)`} value="" indent={false} muted />
          <TotalRow label="Total Cash & Bank Balance (today)" value={fmt(d.totalBalance)} color="text-cyan-400" />
        </tbody>
      </table>
    </StatementCard>
  );
}

// ---------------- Trial Balance ----------------
export function TrialBalance({ accounts, assets, investments, savings, liabilities, periodTx, periodLabel, entityName }) {
  const rows = useMemo(() => {
    const dr = [];
    const cr = [];

    accounts.forEach(a => {
      const bal = Number(a.current_balance || 0);
      if (bal >= 0) dr.push({ name: `${a.name} (account)`, value: bal });
      else cr.push({ name: `${a.name} (overdrawn account)`, value: -bal });
    });

    const assetTotal = assets.reduce((s, a) => s + (Number(a.current_value) || Number(a.value) || 0), 0);
    if (assetTotal > 0) dr.push({ name: 'Fixed & other assets', value: assetTotal });

    const invTotal = investments.reduce((s, i) => s + (Number(i.current_value) || Number(i.invested_amount) || 0), 0);
    if (invTotal > 0) dr.push({ name: 'Investments', value: invTotal });

    const savingsBal = savings.reduce((s, e) => s + (e.type === 'deposit' ? 1 : -1) * Number(e.amount), 0);
    if (savingsBal > 0) dr.push({ name: 'Savings balance', value: savingsBal });

    liabilities.filter(l => Number(l.remaining_balance) > 0).forEach(l => {
      if (l.type === 'loan_given') dr.push({ name: `${l.name} (receivable)`, value: Number(l.remaining_balance) });
      else cr.push({ name: `${l.name} (${l.type === 'shop_due' ? 'shop due' : l.type.replace('_', ' ')})`, value: Number(l.remaining_balance) });
    });

    byCategory(periodTx.filter(t => t.type === 'expense')).forEach(r => dr.push({ name: `${r.name} (expense)`, value: r.value, period: true }));
    byCategory(periodTx.filter(t => t.type === 'income')).forEach(r => cr.push({ name: `${r.name} (income)`, value: r.value, period: true }));

    const drTotal = dr.reduce((s, r) => s + r.value, 0);
    const crTotal = cr.reduce((s, r) => s + r.value, 0);
    const diff = drTotal - crTotal;
    if (diff >= 0) cr.push({ name: "Owner's equity (balancing figure)", value: diff, balancing: true });
    else dr.push({ name: 'Accumulated deficit (balancing figure)', value: -diff, balancing: true });

    return { dr, cr, total: Math.max(drTotal, crTotal) };
  }, [accounts, assets, investments, savings, liabilities, periodTx]);

  const merged = [];
  const maxLen = Math.max(rows.dr.length, rows.cr.length);
  for (let i = 0; i < maxLen; i++) merged.push([rows.dr[i], rows.cr[i]]);

  const exportPDF = () => {
    const body = [];
    rows.dr.forEach(r => body.push([r.name, pdfNum(r.value), '']));
    rows.cr.forEach(r => body.push([r.name, '', pdfNum(r.value)]));
    const boldRows = [body.length];
    body.push(['TOTAL', pdfNum(rows.total), pdfNum(rows.total)]);
    exportStatementPDF({
      entityName,
      title: 'Trial Balance',
      subtitle: `As of today · Income/expense for: ${periodLabel} (Amounts in ৳)`,
      sections: { head: ['Ledger Head', 'Debit', 'Credit'], body, boldRows },
      fileName: `Trial_Balance_${periodLabel.replace(/[^a-zA-Z0-9]/g, '_')}.pdf`
    });
  };

  const Cell = ({ r }) => r ? (
    <div className="flex justify-between gap-2 py-1.5">
      <span className={`truncate ${r.balancing ? 'text-purple-300 italic' : 'text-white/70'}`}>
        {r.name}{r.period && <span className="text-white/30 text-[10px] ml-1">(period)</span>}
      </span>
      <span className={`tabular-nums shrink-0 ${r.balancing ? 'text-purple-300' : 'text-white/80'}`}>{fmt(r.value)}</span>
    </div>
  ) : <div className="py-1.5">&nbsp;</div>;

  return (
    <StatementCard entityName={entityName} title="Trial Balance" subtitle={`As of today · Income & expenses for: ${periodLabel}`} onExport={exportPDF}>
      <div className="overflow-x-auto">
        <div className="min-w-[560px]">
          <div className="grid grid-cols-2 gap-x-6 border-b border-white/15 pb-2 mb-1">
            <p className="text-[11px] font-bold uppercase tracking-wider text-emerald-400/80">Debit (ডেবিট)</p>
            <p className="text-[11px] font-bold uppercase tracking-wider text-red-400/80">Credit (ক্রেডিট)</p>
          </div>
          {merged.map(([l, r], i) => (
            <div key={i} className="grid grid-cols-2 gap-x-6 text-sm border-b border-white/[0.03] hover:bg-white/[0.02]">
              <Cell r={l} /><Cell r={r} />
            </div>
          ))}
          <div className="grid grid-cols-2 gap-x-6 text-sm font-bold border-t-2 border-white/20 mt-1 pt-2">
            <div className="flex justify-between"><span className="text-white">Total</span><span className="text-emerald-400 tabular-nums">{fmt(rows.total)}</span></div>
            <div className="flex justify-between"><span className="text-white">Total</span><span className="text-red-400 tabular-nums">{fmt(rows.total)}</span></div>
          </div>
        </div>
      </div>
      <p className="text-white/30 text-xs mt-4">
        * Balance-sheet heads are as of today; income & expense heads cover the selected period. The balancing figure represents owner's equity.
      </p>
    </StatementCard>
  );
}

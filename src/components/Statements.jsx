import { useMemo } from 'react';
import { FileText, Banknote, HandCoins } from 'lucide-react';
import { downloadHtmlAsPdf, statementHtml, multiSectionHtml } from '../lib/htmlPdf';

const fmt = (n) => '৳' + Number(n || 0).toLocaleString('en-IN', { maximumFractionDigits: 2 });
const pdfNum = (n) => '৳' + Number(n || 0).toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 });

function StatementCard({ entityName, title, subtitle, onExport, children }) {
  return (
    <div className="bg-[#1a1a2e] border border-white/10 rounded-2xl overflow-hidden">
      <div className="relative border-b border-white/10 px-6 py-5 text-center">
        <p className="text-xs uppercase tracking-[0.2em] text-cyan-400/70">{entityName || 'TakaKhata'}</p>
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

// ---------------- Balance Sheet ----------------
export function BalanceSheet({ accounts, assets, investments, savings, liabilities, entityName }) {
  const d = useMemo(() => {
    const assetRows = [];
    const liabRows = [];

    accounts.forEach(a => {
      const bal = Number(a.current_balance || 0);
      if (bal >= 0) assetRows.push({ name: `${a.name} (cash & bank)`, value: bal });
      else liabRows.push({ name: `${a.name} (overdrawn account)`, value: -bal });
    });

    const savingsBal = savings.reduce((s, e) => s + (e.type === 'deposit' ? 1 : -1) * Number(e.amount), 0);
    if (savingsBal > 0) assetRows.push({ name: 'Savings', value: savingsBal });

    const invTotal = investments.reduce((s, i) => s + (Number(i.current_value) || Number(i.invested_amount) || 0), 0);
    if (invTotal > 0) assetRows.push({ name: 'Investments', value: invTotal });

    const fixedTotal = assets.reduce((s, a) => s + (Number(a.current_value) || Number(a.value) || 0), 0);
    if (fixedTotal > 0) assetRows.push({ name: 'Fixed & other assets', value: fixedTotal });

    liabilities.filter(l => Number(l.remaining_balance) > 0).forEach(l => {
      if (l.type === 'loan_given') assetRows.push({ name: `${l.name} (receivable)`, value: Number(l.remaining_balance) });
      else liabRows.push({ name: `${l.name} (${l.type === 'shop_due' ? 'shop due' : l.type.replace('_', ' ')})`, value: Number(l.remaining_balance) });
    });

    const totalAssets = assetRows.reduce((s, r) => s + r.value, 0);
    const totalLiab = liabRows.reduce((s, r) => s + r.value, 0);
    return { assetRows, liabRows, totalAssets, totalLiab, equity: totalAssets - totalLiab };
  }, [accounts, assets, investments, savings, liabilities]);

  const exportPDF = () => {
    const body = [];
    const boldRows = [];
    body.push(['ASSETS (সম্পদ)', '']);
    d.assetRows.forEach(r => body.push(['   ' + r.name, pdfNum(r.value)]));
    boldRows.push(body.length);
    body.push(['Total Assets', pdfNum(d.totalAssets)]);
    body.push(['LIABILITIES (দায়)', '']);
    if (d.liabRows.length === 0) body.push(['   No liabilities', '—']);
    d.liabRows.forEach(r => body.push(['   ' + r.name, pdfNum(r.value)]));
    boldRows.push(body.length);
    body.push(['Total Liabilities', pdfNum(d.totalLiab)]);
    boldRows.push(body.length);
    body.push(["OWNER'S EQUITY / NET WORTH", pdfNum(d.equity)]);
    boldRows.push(body.length);
    body.push(['Total Liabilities + Equity', pdfNum(d.totalLiab + d.equity)]);
    exportStatementPDF({
      entityName,
      title: 'Balance Sheet',
      subtitle: `As of ${new Date().toLocaleDateString('en-GB')} (Amounts in ৳)`,
      sections: { head: ['Particulars', 'Amount'], body, boldRows },
      fileName: `Balance_Sheet_${new Date().toISOString().slice(0, 10)}.pdf`
    });
  };

  return (
    <StatementCard entityName={entityName} title="Balance Sheet" subtitle={`As of today · ${new Date().toLocaleDateString('en-GB')}`} onExport={exportPDF}>
      <table className="w-full text-sm">
        <tbody>
          <SectionRow label="Assets (সম্পদ)" />
          {d.assetRows.map(r => <LineRow key={r.name} label={r.name} value={fmt(r.value)} />)}
          <TotalRow label="Total Assets" value={fmt(d.totalAssets)} color="text-emerald-400" />

          <SectionRow label="Liabilities (দায়)" />
          {d.liabRows.length === 0 && <LineRow label="No liabilities" value="—" muted />}
          {d.liabRows.map(r => <LineRow key={r.name} label={r.name} value={fmt(r.value)} />)}
          <TotalRow label="Total Liabilities" value={fmt(d.totalLiab)} color="text-red-400" />

          <NetRow label="Owner's Equity / Net Worth (নীট সম্পদ)" value={fmt(d.equity)} positive={d.equity >= 0} />
          <TotalRow label="Total Liabilities + Equity" value={fmt(d.totalLiab + d.equity)} color="text-cyan-400" />
        </tbody>
      </table>
      <p className="text-white/30 text-xs mt-4">* Total Liabilities + Equity always equals Total Assets.</p>
    </StatementCard>
  );
}

// ---------------- Bazar Report (shop-wise due + monthly purchases) ----------------
export function BazarReport({ shops, purchases, payments, periodLabel, inPeriod, entityName }) {
  const d = useMemo(() => {
    const periodPurchases = purchases.filter(p => inPeriod(p.date));
    const periodPayments = payments.filter(p => inPeriod(p.date));
    const total = periodPurchases.reduce((s, p) => s + Number(p.amount), 0);
    const cash = periodPurchases.filter(p => p.payment_type === 'cash').reduce((s, p) => s + Number(p.amount), 0);
    const paid = periodPayments.reduce((s, p) => s + Number(p.amount), 0);
    const totalDue = shops.reduce((s, x) => s + Number(x.remaining_balance || 0), 0);

    const perShop = {};
    periodPurchases.forEach(p => {
      const key = p.payment_type === 'cash' ? 'Cash bazar (নগদ)' : (p.liabilities?.name || 'Deleted shop');
      perShop[key] = (perShop[key] || 0) + Number(p.amount);
    });
    return { periodPurchases, total, cash, due: total - cash, paid, totalDue, perShop };
  }, [shops, purchases, payments, inPeriod]);

  const exportPDF = () => {
    const summary = [
      ['Total bazar this period', pdfNum(d.total)],
      ['Bought with cash (নগদ)', pdfNum(d.cash)],
      ['Bought on due (বাকিতে)', pdfNum(d.due)],
      ['Paid to shops this period', pdfNum(d.paid)],
      ['Outstanding shop due today (মোট বাকি)', pdfNum(d.totalDue)]
    ];
    const shopRows = shops.map(s => [
      s.name,
      s.phone || '-',
      pdfNum(s.principal),
      pdfNum(s.remaining_balance)
    ]);
    shopRows.push(['Total', '', pdfNum(shops.reduce((x, s) => x + Number(s.principal || 0), 0)), pdfNum(d.totalDue)]);
    const purchaseRows = d.periodPurchases.map(p => [
      p.date,
      p.payment_type === 'cash' ? 'Cash' : 'Due',
      p.payment_type === 'cash' ? (p.accounts?.name || '-') : (p.liabilities?.name || '-'),
      p.description || '-',
      pdfNum(p.amount)
    ]);
    purchaseRows.push(['Total', '', '', '', pdfNum(d.total)]);
    downloadHtmlAsPdf(
      multiSectionHtml({
        entityName,
        title: 'Bazar Report (বাজার রিপোর্ট)',
        subtitle: `Period: ${periodLabel} (Amounts in ৳)`,
        sections: [
          { title: 'Summary', head: ['Particulars', 'Amount'], rows: summary, boldRows: [0] },
          { title: 'Shop-wise Due (দোকানভিত্তিক বাকি) — as of today', head: ['Shop', 'Phone', 'Lifetime Purchases', 'Current Due'], rows: shopRows, boldRows: [shopRows.length - 1] },
          { title: `Purchases (${periodLabel})`, head: ['Date', 'Payment', 'Source', 'Description', 'Amount'], rows: purchaseRows, boldRows: [purchaseRows.length - 1] }
        ]
      }),
      `Bazar_Report_${periodLabel.replace(/[^a-zA-Z0-9]/g, '_')}.pdf`
    );
  };

  return (
    <StatementCard entityName={entityName} title="Bazar Report (বাজার রিপোর্ট)" subtitle={`Period: ${periodLabel}`} onExport={exportPDF}>
      {/* Summary */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-3 mb-5">
        <div className="bg-white/5 border border-white/10 rounded-xl p-3">
          <p className="text-white/40 text-xs">Total Bazar</p>
          <p className="text-white font-semibold mt-0.5">{fmt(d.total)}</p>
        </div>
        <div className="bg-white/5 border border-white/10 rounded-xl p-3">
          <p className="text-white/40 text-xs">Cash (নগদ)</p>
          <p className="text-emerald-400 font-semibold mt-0.5">{fmt(d.cash)}</p>
        </div>
        <div className="bg-white/5 border border-white/10 rounded-xl p-3">
          <p className="text-white/40 text-xs">On Due (বাকিতে)</p>
          <p className="text-amber-400 font-semibold mt-0.5">{fmt(d.due)}</p>
        </div>
        <div className="bg-white/5 border border-white/10 rounded-xl p-3">
          <p className="text-white/40 text-xs">Shop Due Today</p>
          <p className="text-red-400 font-semibold mt-0.5">{fmt(d.totalDue)}</p>
          {d.paid > 0 && <p className="text-white/30 text-[11px]">Paid this period: {fmt(d.paid)}</p>}
        </div>
      </div>

      {/* Shop-wise due */}
      <p className="text-[11px] font-bold uppercase tracking-wider text-cyan-400/80 mb-2">Shop-wise Due (দোকানভিত্তিক বাকি)</p>
      <div className="overflow-x-auto mb-5">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b border-white/10">
              <th className="text-left py-2 px-3 text-white/40 font-medium">Shop</th>
              <th className="text-left py-2 px-3 text-white/40 font-medium">Phone</th>
              <th className="text-right py-2 px-3 text-white/40 font-medium">Lifetime Purchases</th>
              <th className="text-right py-2 px-3 text-white/40 font-medium">Current Due</th>
            </tr>
          </thead>
          <tbody>
            {shops.length === 0 ? (
              <tr><td colSpan="4" className="text-center py-5 text-white/40">No shops yet.</td></tr>
            ) : shops.map(s => (
              <tr key={s.id} className="border-b border-white/5">
                <td className="py-2 px-3 text-white/80">{s.name}</td>
                <td className="py-2 px-3 text-white/50">{s.phone || '-'}</td>
                <td className="py-2 px-3 text-right text-white/70">{fmt(s.principal)}</td>
                <td className={`py-2 px-3 text-right font-semibold ${Number(s.remaining_balance) > 0 ? 'text-red-400' : 'text-emerald-400'}`}>{fmt(s.remaining_balance)}</td>
              </tr>
            ))}
            {shops.length > 0 && (
              <tr className="border-t border-white/15 font-semibold">
                <td className="py-2 px-3 text-white" colSpan="3">Total Outstanding</td>
                <td className="py-2 px-3 text-right text-red-400">{fmt(d.totalDue)}</td>
              </tr>
            )}
          </tbody>
        </table>
      </div>

      {/* Per-source breakdown for the period */}
      <p className="text-[11px] font-bold uppercase tracking-wider text-cyan-400/80 mb-2">This Period by Source</p>
      <table className="w-full text-sm mb-5">
        <tbody>
          {Object.keys(d.perShop).length === 0 && <LineRow label="No bazar purchases in this period" value="—" muted />}
          {Object.entries(d.perShop).sort((a, b) => b[1] - a[1]).map(([name, v]) => (
            <LineRow key={name} label={name} value={fmt(v)} />
          ))}
          <TotalRow label="Total" value={fmt(d.total)} color="text-white" />
        </tbody>
      </table>

      {/* Purchase list */}
      <p className="text-[11px] font-bold uppercase tracking-wider text-cyan-400/80 mb-2">Purchases ({d.periodPurchases.length})</p>
      <div className="overflow-x-auto">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b border-white/10">
              <th className="text-left py-2 px-3 text-white/40 font-medium">Date</th>
              <th className="text-left py-2 px-3 text-white/40 font-medium">Payment</th>
              <th className="text-left py-2 px-3 text-white/40 font-medium">Source</th>
              <th className="text-right py-2 px-3 text-white/40 font-medium">Amount</th>
              <th className="text-left py-2 px-3 text-white/40 font-medium">Description</th>
            </tr>
          </thead>
          <tbody>
            {d.periodPurchases.length === 0 ? (
              <tr><td colSpan="5" className="text-center py-5 text-white/40">No purchases in this period.</td></tr>
            ) : d.periodPurchases.map(p => (
              <tr key={p.id} className="border-b border-white/5">
                <td className="py-2 px-3 text-white/70 whitespace-nowrap">{p.date}</td>
                <td className="py-2 px-3">
                  <span className={`inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-medium ${p.payment_type === 'cash' ? 'bg-emerald-500/15 text-emerald-300' : 'bg-amber-500/15 text-amber-300'}`}>
                    {p.payment_type === 'cash' ? <><Banknote size={11} /> Cash</> : <><HandCoins size={11} /> Due</>}
                  </span>
                </td>
                <td className="py-2 px-3 text-white/70">{p.payment_type === 'cash' ? (p.accounts?.name || '-') : (p.liabilities?.name || '-')}</td>
                <td className="py-2 px-3 text-right font-medium text-white">{fmt(p.amount)}</td>
                <td className="py-2 px-3 text-white/50 max-w-[220px] truncate">{p.description || '-'}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </StatementCard>
  );
}

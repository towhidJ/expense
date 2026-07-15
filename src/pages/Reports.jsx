import { useState, useMemo } from 'react';
import { useTransactions } from '../hooks/useTransactions';
import { useCategories } from '../hooks/useCategories';
import { useAccounts } from '../context/AccountContext';
import { useLiabilities } from '../hooks/useLiabilities';
import { useSavings } from '../hooks/useSavings';
import { useAssets } from '../hooks/useAssets';
import { useInvestments } from '../hooks/useInvestments';
import { useTransfers } from '../hooks/useTransfers';
import { useEntity } from '../context/EntityContext';
import ChartCard from '../components/ChartCard';
import StatCard from '../components/StatCard';
import { IncomeStatement, CashFlowStatement, TrialBalance, BalanceSheet, BazarReport } from '../components/Statements';
import { useBazar } from '../hooks/useBazar';
import { TrendingUp, TrendingDown, PiggyBank, BarChart3, FileText, FileSpreadsheet, LayoutGrid, Receipt, ArrowDownUp, Scale, Landmark, ShoppingBasket } from 'lucide-react';
import {
  PieChart, Pie, Cell, ResponsiveContainer,
  XAxis, YAxis, Tooltip, CartesianGrid, Legend, Area, AreaChart,
  BarChart, Bar
} from 'recharts';
import { downloadHtmlAsPdf, multiSectionHtml } from '../lib/htmlPdf';
import * as XLSX from 'xlsx';

const COLORS = ['#06b6d4', '#8b5cf6', '#f59e0b', '#ef4444', '#10b981', '#ec4899', '#6366f1', '#f97316', '#14b8a6', '#64748b'];

const CustomTooltip = ({ active, payload, label }) => {
  if (active && payload && payload.length) {
    return (
      <div className="bg-popover border border-border rounded-xl p-3 shadow-xl text-popover-foreground">
        <p className="text-muted-foreground text-xs mb-1">{typeof label === 'number' ? `Day ${label}` : label}</p>
        {payload.map((p, i) => (
          <p key={i} className="text-sm font-medium" style={{ color: p.color }}>
            {p.name}: ৳{p.value.toLocaleString()}
          </p>
        ))}
      </div>
    );
  }
  return null;
};

const REPORT_TYPES = [
  { id: 'full', label: 'Full Report' },
  { id: 'income', label: 'Income Report' },
  { id: 'expense', label: 'Expense Report' },
  { id: 'loans', label: 'Loan & Due Report' }
];

const VIEWS = [
  { id: 'overview', label: 'Overview', icon: LayoutGrid },
  { id: 'income_statement', label: 'Income Statement', icon: Receipt },
  { id: 'cash_flow', label: 'Cash Flow', icon: ArrowDownUp },
  { id: 'balance_sheet', label: 'Balance Sheet', icon: Landmark },
  { id: 'trial_balance', label: 'Trial Balance', icon: Scale },
  { id: 'bazar_report', label: 'Bazar Report', icon: ShoppingBasket }
];

export default function Reports() {
  const { transactions } = useTransactions();
  const { categories } = useCategories();
  const { accounts } = useAccounts();
  const { liabilities, repayments } = useLiabilities();
  const { savings } = useSavings();
  const { assets } = useAssets();
  const { investments } = useInvestments();
  const { transfers } = useTransfers();
  const { shops, purchases: bazarPurchases, payments: bazarPayments } = useBazar();
  const { currentEntity } = useEntity();
  const [view, setView] = useState('overview');
  const now = new Date();
  const [filterType, setFilterType] = useState('monthly'); // 'monthly' or 'custom'
  const [month, setMonth] = useState(now.getMonth() + 1);
  const [year, setYear] = useState(now.getFullYear());
  const [startDate, setStartDate] = useState(new Date(now.getFullYear(), now.getMonth(), 1).toISOString().split('T')[0]);
  const [endDate, setEndDate] = useState(new Date(now.getFullYear(), now.getMonth() + 1, 0).toISOString().split('T')[0]);
  const [accountFilter, setAccountFilter] = useState('all');
  const [categoryFilter, setCategoryFilter] = useState('all');
  const [reportType, setReportType] = useState('full');

  const inPeriod = (dateStr) => {
    const d = new Date(dateStr);
    if (filterType === 'monthly') return d.getMonth() + 1 === month && d.getFullYear() === year;
    return d.getTime() >= new Date(startDate).getTime() && d.getTime() <= new Date(endDate).getTime();
  };

  const monthTx = useMemo(() => {
    return transactions.filter(t => {
      const d = new Date(t.date);
      let passDate;
      if (filterType === 'monthly') {
        passDate = d.getMonth() + 1 === month && d.getFullYear() === year;
      } else {
        const tTime = d.getTime();
        const sTime = new Date(startDate).getTime();
        const eTime = new Date(endDate).getTime();
        passDate = tTime >= sTime && tTime <= eTime;
      }
      if (!passDate) return false;
      if (accountFilter !== 'all' && t.account_id !== accountFilter) return false;
      if (categoryFilter !== 'all' && t.category_id !== categoryFilter) return false;
      return true;
    });
  }, [transactions, month, year, filterType, startDate, endDate, accountFilter, categoryFilter]);

  // All transactions in the period, ignoring account/category filters — used by the financial statements
  const statementTx = useMemo(() => transactions.filter(t => inPeriod(t.date)),
    [transactions, filterType, month, year, startDate, endDate]); // eslint-disable-line react-hooks/exhaustive-deps

  const stats = useMemo(() => {
    const income = monthTx.filter(t => t.type === 'income').reduce((s, t) => s + t.amount, 0);
    const expense = monthTx.filter(t => t.type === 'expense').reduce((s, t) => s + t.amount, 0);
    const net = income - expense;
    const savingsRate = income > 0 ? ((net / income) * 100) : 0;
    return { income, expense, net, savingsRate, count: monthTx.length };
  }, [monthTx]);

  const categoryData = useMemo(() => {
    const map = {};
    monthTx.filter(t => t.type === 'expense').forEach(t => {
      const name = t.categories?.name || 'Other';
      const color = t.categories?.color || '#64748b';
      if (!map[name]) map[name] = { name, value: 0, color };
      map[name].value += t.amount;
    });
    return Object.values(map).sort((a, b) => b.value - a.value);
  }, [monthTx]);

  const incomeByCategory = useMemo(() => {
    const map = {};
    monthTx.filter(t => t.type === 'income').forEach(t => {
      const name = t.categories?.name || 'Other';
      if (!map[name]) map[name] = { name, value: 0 };
      map[name].value += t.amount;
    });
    return Object.values(map).sort((a, b) => b.value - a.value);
  }, [monthTx]);

  const dailyTrend = useMemo(() => {
    const days = [];
    if (filterType === 'monthly') {
      const daysInMonth = new Date(year, month, 0).getDate();
      for (let d = 1; d <= daysInMonth; d++) {
        const dayTx = monthTx.filter(t => new Date(t.date).getDate() === d);
        const income = dayTx.filter(t => t.type === 'income').reduce((s, t) => s + t.amount, 0);
        const expense = dayTx.filter(t => t.type === 'expense').reduce((s, t) => s + t.amount, 0);
        days.push({ day: d, income, expense });
      }
    } else {
      // For custom range, group by distinct dates
      const dateMap = {};
      monthTx.forEach(t => {
        const dateStr = t.date;
        if (!dateMap[dateStr]) dateMap[dateStr] = { day: dateStr, income: 0, expense: 0 };
        if (t.type === 'income') dateMap[dateStr].income += t.amount;
        if (t.type === 'expense') dateMap[dateStr].expense += t.amount;
      });
      return Object.values(dateMap).sort((a, b) => new Date(a.day) - new Date(b.day));
    }
    return days;
  }, [monthTx, month, year, filterType]);

  const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];

  // Income vs Expense for the last 6 calendar months (ignores period filter)
  const sixMonthComparison = useMemo(() => {
    const rows = [];
    const today = new Date();
    for (let i = 5; i >= 0; i--) {
      const d = new Date(today.getFullYear(), today.getMonth() - i, 1);
      const mTx = transactions.filter(t => {
        const td = new Date(t.date);
        return td.getMonth() === d.getMonth() && td.getFullYear() === d.getFullYear();
      });
      rows.push({
        month: months[d.getMonth()],
        Income: mTx.filter(t => t.type === 'income').reduce((s, t) => s + t.amount, 0),
        Expense: mTx.filter(t => t.type === 'expense').reduce((s, t) => s + t.amount, 0)
      });
    }
    return rows;
  }, [transactions]); // eslint-disable-line react-hooks/exhaustive-deps

  const insights = useMemo(() => {
    const list = [];
    const { income, expense } = stats;

    // Savings rate check
    if (income > 0) {
      const rate = ((income - expense) / income) * 100;
      if (expense > income) {
        list.push({ tone: 'bad', text: `You spent ৳${(expense - income).toLocaleString()} MORE than you earned this period. Check the biggest categories below.` });
      } else if (rate < 10) {
        list.push({ tone: 'warn', text: `You're saving only ${rate.toFixed(0)}% of your income this period. Try to push it to at least 20%.` });
      } else if (rate < 20) {
        list.push({ tone: 'info', text: `You're saving ${rate.toFixed(0)}% of your income. Not bad — 20%+ is a healthy target.` });
      } else {
        list.push({ tone: 'good', text: `Great — you're saving ${rate.toFixed(0)}% of your income this period. Keep it up!` });
      }
    }

    // Biggest expense category + what cutting it 10% would save
    if (categoryData.length > 0 && expense > 0) {
      const top = categoryData[0];
      const pctOfExpense = (top.value / expense) * 100;
      const pctOfIncome = income > 0 ? (top.value / income) * 100 : null;
      list.push({
        tone: pctOfExpense > 35 ? 'warn' : 'info',
        text: `Your biggest expense is ${top.name}: ৳${top.value.toLocaleString()} — ${pctOfExpense.toFixed(0)}% of all spending${pctOfIncome !== null ? ` and ${pctOfIncome.toFixed(0)}% of your income` : ''}. Cutting it by just 10% would save ৳${Math.round(top.value * 0.1).toLocaleString()}.`
      });
    }

    // Categories that jumped vs the previous month (monthly mode only)
    if (filterType === 'monthly') {
      const prevMonth = month === 1 ? 12 : month - 1;
      const prevYear = month === 1 ? year - 1 : year;
      const sumByCat = (m, y) => {
        const map = {};
        transactions.forEach(t => {
          const d = new Date(t.date);
          if (t.type === 'expense' && d.getMonth() + 1 === m && d.getFullYear() === y) {
            const name = t.categories?.name || 'Other';
            map[name] = (map[name] || 0) + t.amount;
          }
        });
        return map;
      };
      const cur = sumByCat(month, year);
      const prev = sumByCat(prevMonth, prevYear);
      Object.entries(cur)
        .filter(([name, val]) => prev[name] > 0 && val > prev[name] * 1.3 && val - prev[name] >= 500)
        .sort((a, b) => (b[1] - prev[b[0]]) - (a[1] - prev[a[0]]))
        .slice(0, 3)
        .forEach(([name, val]) => {
          const p = prev[name];
          list.push({ tone: 'warn', text: `${name} jumped ${(((val - p) / p) * 100).toFixed(0)}% vs last month (৳${p.toLocaleString()} → ৳${val.toLocaleString()}). Worth a look.` });
        });
    }

    return list.slice(0, 6);
  }, [stats, categoryData, transactions, filterType, month, year]);

  const periodLabel = filterType === 'monthly' ? `${months[month - 1]} ${year}` : `${startDate} to ${endDate}`;
  const categoryLabel = categoryFilter !== 'all' ? categories.find(c => c.id === categoryFilter)?.name : null;

  const exportLoanPDF = () => {
    const takenRemaining = liabilities.filter(l => l.type !== 'loan_given').reduce((s, l) => s + Number(l.remaining_balance), 0);
    const givenRemaining = liabilities.filter(l => l.type === 'loan_given').reduce((s, l) => s + Number(l.remaining_balance), 0);
    const periodRepayments = repayments.filter(r => inPeriod(r.date));

    downloadHtmlAsPdf(
      multiSectionHtml({
        entityName: currentEntity?.name,
        title: 'Loan & Due Report',
        subtitle: periodLabel,
        sections: [
          {
            title: 'Summary',
            head: ['', 'Amount (৳)'],
            rows: [
              ['Total Payable (loans taken, dues)', takenRemaining.toLocaleString()],
              ['Total Receivable (loans given)', givenRemaining.toLocaleString()]
            ]
          },
          {
            title: 'Liabilities',
            head: ['Name', 'Type', 'Principal (৳)', 'Remaining (৳)', 'Due Date', 'Status'],
            rows: liabilities.map(l => [
              l.name,
              l.type.replace('_', ' '),
              Number(l.principal).toLocaleString(),
              Number(l.remaining_balance).toLocaleString(),
              l.due_date || '-',
              l.remaining_balance <= 0 ? 'PAID' : 'ACTIVE'
            ])
          },
          {
            title: `Repayments (${periodLabel})`,
            head: ['Date', 'Liability', 'Account', 'Amount (৳)', 'Notes'],
            rows: periodRepayments.length
              ? periodRepayments.map(r => [
                  r.date,
                  liabilities.find(l => l.id === r.liability_id)?.name || 'Unknown',
                  r.accounts?.name || '-',
                  Number(r.amount).toLocaleString(),
                  r.notes || '-'
                ])
              : [['No repayments in this period', '', '', '', '']]
          }
        ]
      }),
      `Loan_Due_Report_${periodLabel.replace(/[^a-zA-Z0-9]/g, '_')}.pdf`
    );
  };

  const exportPDF = () => {
    if (reportType === 'loans') {
      exportLoanPDF();
      return;
    }

    const typeLabel = REPORT_TYPES.find(r => r.id === reportType)?.label || 'Report';
    const title = `${typeLabel}${categoryLabel ? ` (${categoryLabel})` : ''} - ${periodLabel}`;
    const txs = reportType === 'full' ? monthTx : monthTx.filter(t => t.type === reportType);
    const income = txs.filter(t => t.type === 'income').reduce((s, t) => s + t.amount, 0);
    const expense = txs.filter(t => t.type === 'expense').reduce((s, t) => s + t.amount, 0);

    const summaryRows = [];
    if (reportType !== 'expense') summaryRows.push(['Total Income', income.toLocaleString()]);
    if (reportType !== 'income') summaryRows.push(['Total Expense', expense.toLocaleString()]);
    if (reportType === 'full') summaryRows.push(['Net Savings', (income - expense).toLocaleString()]);

    downloadHtmlAsPdf(
      multiSectionHtml({
        entityName: currentEntity?.name,
        title: `${typeLabel}${categoryLabel ? ` (${categoryLabel})` : ''}`,
        subtitle: periodLabel,
        sections: [
          {
            title: 'Summary',
            head: ['', 'Amount (৳)'],
            rows: summaryRows,
            boldRows: reportType === 'full' ? [summaryRows.length - 1] : []
          },
          {
            title: 'Transactions',
            head: ['Date', 'Type', 'Category', 'Account', 'Amount (৳)', 'Description'],
            rows: txs.map(t => [
              t.date,
              t.type.toUpperCase(),
              t.categories?.name || 'Other',
              t.accounts?.name || '-',
              t.amount.toLocaleString(),
              t.description || '-'
            ])
          }
        ]
      }),
      `${title.replace(/[^a-zA-Z0-9]/g, '_')}.pdf`
    );
  };

  const exportExcel = () => {
    const wb = XLSX.utils.book_new();

    if (reportType === 'loans') {
      const liabilityRows = [
        ['Name', 'Type', 'Principal', 'Remaining', 'Due Date', 'Status'],
        ...liabilities.map(l => [l.name, l.type.replace('_', ' '), Number(l.principal), Number(l.remaining_balance), l.due_date || '-', l.remaining_balance <= 0 ? 'PAID' : 'ACTIVE'])
      ];
      const repaymentRows = [
        ['Date', 'Liability', 'Account', 'Amount', 'Notes'],
        ...repayments.filter(r => inPeriod(r.date)).map(r => [
          r.date,
          liabilities.find(l => l.id === r.liability_id)?.name || 'Unknown',
          r.accounts?.name || '-',
          Number(r.amount),
          r.notes || '-'
        ])
      ];
      XLSX.utils.book_append_sheet(wb, XLSX.utils.aoa_to_sheet(liabilityRows), 'Liabilities');
      XLSX.utils.book_append_sheet(wb, XLSX.utils.aoa_to_sheet(repaymentRows), 'Repayments');
      XLSX.writeFile(wb, `Loan_Due_Report_${periodLabel.replace(/[^a-zA-Z0-9]/g, '_')}.xlsx`);
      return;
    }

    const typeLabel = REPORT_TYPES.find(r => r.id === reportType)?.label || 'Report';
    const title = `${typeLabel}${categoryLabel ? ` (${categoryLabel})` : ''} - ${periodLabel}`;
    const txs = reportType === 'full' ? monthTx : monthTx.filter(t => t.type === reportType);
    const income = txs.filter(t => t.type === 'income').reduce((s, t) => s + t.amount, 0);
    const expense = txs.filter(t => t.type === 'expense').reduce((s, t) => s + t.amount, 0);

    const summaryData = [
      ['Report', title],
      ['Total Income', income],
      ['Total Expense', expense],
      ['Net Savings', income - expense],
      ['Total Transactions', txs.length],
      [],
      ['Date', 'Type', 'Category', 'Account', 'Amount', 'Description']
    ];

    const txData = txs.map(t => [
      t.date,
      t.type.toUpperCase(),
      t.categories?.name || 'Other',
      t.accounts?.name || '-',
      t.amount,
      t.description || '-'
    ]);

    XLSX.utils.book_append_sheet(wb, XLSX.utils.aoa_to_sheet([...summaryData, ...txData]), 'Report');
    XLSX.writeFile(wb, `${title.replace(/[^a-zA-Z0-9]/g, '_')}.xlsx`);
  };


  return (
    <div className="space-y-6 animate-in">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-white">Reports & Statements</h1>
          <p className="text-white/40 text-sm mt-1">Detailed financial analysis</p>
        </div>
        <div className="flex flex-col items-stretch sm:items-end gap-3">
          <div className="flex flex-col sm:flex-row gap-3">
            {view === 'overview' && (
              <div className="flex gap-2">
                <select
                  value={reportType}
                  onChange={e => setReportType(e.target.value)}
                  className="bg-white/5 border border-white/10 rounded-lg px-3 py-1.5 text-white text-sm focus:outline-none focus:border-cyan-500/50 appearance-none cursor-pointer"
                  title="Which report to download"
                >
                  {REPORT_TYPES.map(r => (
                    <option key={r.id} value={r.id} className="bg-[#12122a]">{r.label}</option>
                  ))}
                </select>
                <button onClick={exportPDF} className="flex items-center gap-2 px-3 py-1.5 rounded-lg text-sm bg-red-500/20 text-red-400 hover:bg-red-500/30 transition-all font-medium whitespace-nowrap">
                  <FileText size={16} /> PDF
                </button>
                <button onClick={exportExcel} className="flex items-center gap-2 px-3 py-1.5 rounded-lg text-sm bg-emerald-500/20 text-emerald-400 hover:bg-emerald-500/30 transition-all font-medium whitespace-nowrap">
                  <FileSpreadsheet size={16} /> Excel
                </button>
              </div>
            )}
            <div className="flex gap-2 bg-white/5 p-1 rounded-xl">
              <button
                onClick={() => setFilterType('monthly')}
                className={`px-3 py-1.5 rounded-lg text-sm transition-all whitespace-nowrap ${filterType === 'monthly' ? 'bg-cyan-500/20 text-cyan-400' : 'text-white/40 hover:text-white'}`}
              >Monthly</button>
              <button
                onClick={() => setFilterType('custom')}
                className={`px-3 py-1.5 rounded-lg text-sm transition-all whitespace-nowrap ${filterType === 'custom' ? 'bg-cyan-500/20 text-cyan-400' : 'text-white/40 hover:text-white'}`}
              >Custom Range</button>
            </div>
          </div>

          {/* Account & category filters */}
          {view === 'overview' && (
          <div className="flex flex-wrap gap-3">
            <select
              value={accountFilter}
              onChange={e => setAccountFilter(e.target.value)}
              className="flex-1 sm:flex-none min-w-0 bg-white/5 border border-white/10 rounded-xl px-4 py-2 text-white text-sm focus:outline-none focus:border-cyan-500/50 appearance-none cursor-pointer"
            >
              <option value="all" className="bg-[#12122a]">All Accounts</option>
              {accounts.map(a => (
                <option key={a.id} value={a.id} className="bg-[#12122a]">{a.name}</option>
              ))}
            </select>
            <select
              value={categoryFilter}
              onChange={e => setCategoryFilter(e.target.value)}
              className="flex-1 sm:flex-none min-w-0 bg-white/5 border border-white/10 rounded-xl px-4 py-2 text-white text-sm focus:outline-none focus:border-cyan-500/50 appearance-none cursor-pointer"
            >
              <option value="all" className="bg-[#12122a]">All Categories</option>
              {categories.map(c => (
                <option key={c.id} value={c.id} className="bg-[#12122a]">{c.icon} {c.name}</option>
              ))}
            </select>
          </div>
          )}

          {filterType === 'monthly' ? (
            <div className="flex flex-wrap gap-3">
              <select
                value={month}
                onChange={e => setMonth(parseInt(e.target.value))}
                className="flex-1 sm:flex-none min-w-0 bg-white/5 border border-white/10 rounded-xl px-4 py-2.5 text-white text-sm focus:outline-none focus:border-cyan-500/50 appearance-none cursor-pointer"
              >
                {months.map((m, i) => (
                  <option key={i} value={i + 1} className="bg-[#12122a]">{m}</option>
                ))}
              </select>
              <select
                value={year}
                onChange={e => setYear(parseInt(e.target.value))}
                className="flex-1 sm:flex-none min-w-0 bg-white/5 border border-white/10 rounded-xl px-4 py-2.5 text-white text-sm focus:outline-none focus:border-cyan-500/50 appearance-none cursor-pointer"
              >
                {[2024, 2025, 2026, 2027].map(y => (
                  <option key={y} value={y} className="bg-[#12122a]">{y}</option>
                ))}
              </select>
            </div>
          ) : (
            <div className="flex flex-wrap gap-3 items-center">
              <input type="date" value={startDate} onChange={e => setStartDate(e.target.value)} className="flex-1 min-w-0 bg-white/5 border border-white/10 rounded-xl px-4 py-2.5 text-white text-sm focus:outline-none focus:border-cyan-500/50" />
              <span className="text-white/40">to</span>
              <input type="date" value={endDate} onChange={e => setEndDate(e.target.value)} className="flex-1 min-w-0 bg-white/5 border border-white/10 rounded-xl px-4 py-2.5 text-white text-sm focus:outline-none focus:border-cyan-500/50" />
            </div>
          )}
        </div>
      </div>

      {/* View tabs */}
      <div className="grid grid-cols-2 sm:flex gap-1 bg-white/5 border border-white/10 p-1 rounded-xl">
        {VIEWS.map(({ id, label, icon: Icon }) => (
          <button
            key={id}
            onClick={() => setView(id)}
            className={`flex items-center justify-center sm:justify-start gap-2 px-3 sm:px-4 py-2.5 rounded-lg text-sm font-medium whitespace-nowrap transition-all ${
              view === id ? 'bg-gradient-to-r from-cyan-500/20 to-purple-600/20 text-cyan-400 border border-cyan-500/20' : 'text-white/40 hover:text-white border border-transparent'
            }`}
          >
            <Icon size={15} /> {label}
          </button>
        ))}
      </div>

      {view === 'income_statement' && (
        <IncomeStatement periodTx={statementTx} periodLabel={periodLabel} entityName={currentEntity?.name} />
      )}
      {view === 'cash_flow' && (
        <CashFlowStatement
          periodTx={statementTx}
          savings={savings}
          repayments={repayments}
          liabilities={liabilities}
          transfers={transfers}
          accounts={accounts}
          periodLabel={periodLabel}
          entityName={currentEntity?.name}
          inPeriod={inPeriod}
        />
      )}
      {view === 'balance_sheet' && (
        <BalanceSheet
          accounts={accounts}
          assets={assets}
          investments={investments}
          savings={savings}
          liabilities={liabilities}
          entityName={currentEntity?.name}
        />
      )}
      {view === 'trial_balance' && (
        <TrialBalance
          accounts={accounts}
          assets={assets}
          investments={investments}
          savings={savings}
          liabilities={liabilities}
          periodTx={statementTx}
          periodLabel={periodLabel}
          entityName={currentEntity?.name}
        />
      )}
      {view === 'bazar_report' && (
        <BazarReport
          shops={shops}
          purchases={bazarPurchases}
          payments={bazarPayments}
          periodLabel={periodLabel}
          inPeriod={inPeriod}
          entityName={currentEntity?.name}
        />
      )}

      {view === 'overview' && (<>
      {/* Stats */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        <StatCard title="Total Income" value={`৳${stats.income.toLocaleString()}`} icon={TrendingUp} gradient={['#10b981', '#06b6d4']} iconBg="bg-emerald-500/10" />
        <StatCard title="Total Expense" value={`৳${stats.expense.toLocaleString()}`} icon={TrendingDown} gradient={['#ef4444', '#f59e0b']} iconBg="bg-red-500/10" />
        <StatCard title="Net Savings" value={`৳${stats.net.toLocaleString()}`} icon={PiggyBank} gradient={['#8b5cf6', '#ec4899']} iconBg="bg-purple-500/10" />
        <StatCard title="Transactions" value={stats.count} icon={BarChart3} gradient={['#06b6d4', '#8b5cf6']} iconBg="bg-cyan-500/10" />
      </div>

      {/* Daily Trend */}
      <ChartCard title="Daily Spending Trend" subtitle={filterType === 'monthly' ? `${months[month - 1]} ${year}` : `${startDate} to ${endDate}`}>
        <ResponsiveContainer width="100%" height={300}>
          <AreaChart data={dailyTrend}>
            <defs>
              <linearGradient id="incomeGrad" x1="0" y1="0" x2="0" y2="1">
                <stop offset="5%" stopColor="#10b981" stopOpacity={0.3} />
                <stop offset="95%" stopColor="#10b981" stopOpacity={0} />
              </linearGradient>
              <linearGradient id="expenseGrad" x1="0" y1="0" x2="0" y2="1">
                <stop offset="5%" stopColor="#ef4444" stopOpacity={0.3} />
                <stop offset="95%" stopColor="#ef4444" stopOpacity={0} />
              </linearGradient>
            </defs>
            <CartesianGrid strokeDasharray="3 3" stroke="#ffffff08" />
            <XAxis dataKey="day" tick={{ fill: '#ffffff40', fontSize: 11 }} axisLine={false} tickLine={false} />
            <YAxis tick={{ fill: '#ffffff40', fontSize: 11 }} axisLine={false} tickLine={false} />
            <Tooltip content={<CustomTooltip />} />
            <Legend wrapperStyle={{ color: '#ffffff60', fontSize: 12 }} />
            <Area type="monotone" dataKey="income" stroke="#10b981" fill="url(#incomeGrad)" strokeWidth={2} name="Income" />
            <Area type="monotone" dataKey="expense" stroke="#ef4444" fill="url(#expenseGrad)" strokeWidth={2} name="Expense" />
          </AreaChart>
        </ResponsiveContainer>
      </ChartCard>

      {/* Income vs Expense + Suggestions */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <ChartCard title="Income vs Expense" subtitle="Last 6 months">
          <ResponsiveContainer width="100%" height={280}>
            <BarChart data={sixMonthComparison} barGap={4}>
              <CartesianGrid strokeDasharray="3 3" stroke="#ffffff08" />
              <XAxis dataKey="month" tick={{ fill: '#ffffff40', fontSize: 11 }} axisLine={false} tickLine={false} />
              <YAxis tick={{ fill: '#ffffff40', fontSize: 11 }} axisLine={false} tickLine={false} />
              <Tooltip content={<CustomTooltip />} cursor={{ fill: '#ffffff08' }} />
              <Legend wrapperStyle={{ color: '#ffffff60', fontSize: 12 }} />
              <Bar dataKey="Income" fill="#10b981" radius={[6, 6, 0, 0]} />
              <Bar dataKey="Expense" fill="#ef4444" radius={[6, 6, 0, 0]} />
            </BarChart>
          </ResponsiveContainer>
        </ChartCard>

        <ChartCard title="💡 Suggestions" subtitle="How to cut your spending">
          {insights.length > 0 ? (
            <div className="space-y-3 pt-2">
              {insights.map((ins, i) => (
                <div
                  key={i}
                  className={`rounded-xl px-4 py-3 border text-sm leading-relaxed ${
                    ins.tone === 'bad' ? 'bg-red-500/10 border-red-500/20 text-red-300'
                    : ins.tone === 'warn' ? 'bg-amber-500/10 border-amber-500/20 text-amber-200'
                    : ins.tone === 'good' ? 'bg-emerald-500/10 border-emerald-500/20 text-emerald-300'
                    : 'bg-cyan-500/10 border-cyan-500/20 text-cyan-200'
                  }`}
                >
                  {ins.text}
                </div>
              ))}
            </div>
          ) : (
            <div className="flex items-center justify-center h-60 text-white/20 text-sm">Add some transactions to get suggestions</div>
          )}
        </ChartCard>
      </div>

      {/* Category Charts */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <ChartCard title="Expense by Category" subtitle="Breakdown">
          {categoryData.length > 0 ? (
            <div className="flex flex-col items-center">
              <ResponsiveContainer width="100%" height={260}>
                <PieChart>
                  <Pie data={categoryData} cx="50%" cy="50%" innerRadius={65} outerRadius={110} dataKey="value" stroke="none">
                    {categoryData.map((_, i) => <Cell key={i} fill={COLORS[i % COLORS.length]} />)}
                  </Pie>
                  <Tooltip content={<CustomTooltip />} />
                </PieChart>
              </ResponsiveContainer>
              <div className="grid grid-cols-2 gap-x-6 gap-y-2 mt-4">
                {categoryData.map((c, i) => (
                  <div key={c.name} className="flex items-center gap-2">
                    <div className="w-2.5 h-2.5 rounded-full" style={{ backgroundColor: COLORS[i % COLORS.length] }} />
                    <span className="text-xs text-white/50">{c.name}</span>
                    <span className="text-xs text-white/70 font-medium ml-auto">৳{c.value.toLocaleString()}</span>
                  </div>
                ))}
              </div>
            </div>
          ) : (
            <div className="flex items-center justify-center h-60 text-white/20 text-sm">No expense data</div>
          )}
        </ChartCard>

        <ChartCard title="Income Sources" subtitle="Breakdown">
          {incomeByCategory.length > 0 ? (
            <div className="space-y-4 pt-4">
              {incomeByCategory.map((c, i) => {
                const pct = stats.income > 0 ? (c.value / stats.income * 100) : 0;
                return (
                  <div key={c.name}>
                    <div className="flex justify-between mb-1">
                      <span className="text-sm text-white/70">{c.name}</span>
                      <span className="text-sm text-white font-medium">৳{c.value.toLocaleString()} ({pct.toFixed(1)}%)</span>
                    </div>
                    <div className="w-full h-2 bg-white/5 rounded-full overflow-hidden">
                      <div className="h-full rounded-full transition-all duration-500" style={{ width: `${pct}%`, backgroundColor: COLORS[i % COLORS.length] }} />
                    </div>
                  </div>
                );
              })}
            </div>
          ) : (
            <div className="flex items-center justify-center h-60 text-white/20 text-sm">No income data</div>
          )}
        </ChartCard>
      </div>

      {/* Summary Table */}
      <ChartCard title="Transaction Summary" subtitle={filterType === 'monthly' ? `${months[month - 1]} ${year}` : `${startDate} to ${endDate}`}>
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-white/10">
                <th className="text-left py-3 px-4 text-white/40 font-medium">Category</th>
                <th className="text-right py-3 px-4 text-white/40 font-medium">Income</th>
                <th className="text-right py-3 px-4 text-white/40 font-medium">Expense</th>
                <th className="text-right py-3 px-4 text-white/40 font-medium">Count</th>
              </tr>
            </thead>
            <tbody>
              {categories.map(cat => {
                const catTx = monthTx.filter(t => t.category_id === cat.id);
                if (catTx.length === 0) return null;
                const inc = catTx.filter(t => t.type === 'income').reduce((s, t) => s + t.amount, 0);
                const exp = catTx.filter(t => t.type === 'expense').reduce((s, t) => s + t.amount, 0);
                return (
                  <tr key={cat.id} className="border-b border-white/5 hover:bg-white/[0.02] transition-colors">
                    <td className="py-3 px-4">
                      <div className="flex items-center gap-2">
                        <span>{cat.icon}</span>
                        <span className="text-white/70">{cat.name}</span>
                      </div>
                    </td>
                    <td className="py-3 px-4 text-right text-emerald-400">{inc > 0 ? `৳${inc.toLocaleString()}` : '-'}</td>
                    <td className="py-3 px-4 text-right text-red-400">{exp > 0 ? `৳${exp.toLocaleString()}` : '-'}</td>
                    <td className="py-3 px-4 text-right text-white/50">{catTx.length}</td>
                  </tr>
                );
              })}
              <tr className="border-t border-white/10 font-semibold">
                <td className="py-3 px-4 text-white">Total</td>
                <td className="py-3 px-4 text-right text-emerald-400">৳{stats.income.toLocaleString()}</td>
                <td className="py-3 px-4 text-right text-red-400">৳{stats.expense.toLocaleString()}</td>
                <td className="py-3 px-4 text-right text-white/70">{stats.count}</td>
              </tr>
            </tbody>
          </table>
        </div>
      </ChartCard>
      </>)}
    </div>
  );
}

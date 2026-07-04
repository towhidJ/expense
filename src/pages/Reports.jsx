import { useState, useMemo } from 'react';
import { useTransactions } from '../hooks/useTransactions';
import { useCategories } from '../hooks/useCategories';
import { useAccounts } from '../context/AccountContext';
import ChartCard from '../components/ChartCard';
import StatCard from '../components/StatCard';
import { TrendingUp, TrendingDown, PiggyBank, BarChart3, FileText, FileSpreadsheet } from 'lucide-react';
import {
  PieChart, Pie, Cell, ResponsiveContainer,
  XAxis, YAxis, Tooltip, CartesianGrid, Legend, Area, AreaChart
} from 'recharts';
import jsPDF from 'jspdf';
import 'jspdf-autotable';
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

export default function Reports() {
  const { transactions } = useTransactions();
  const { categories } = useCategories();
  const { accounts } = useAccounts();
  const now = new Date();
  const [filterType, setFilterType] = useState('monthly'); // 'monthly' or 'custom'
  const [month, setMonth] = useState(now.getMonth() + 1);
  const [year, setYear] = useState(now.getFullYear());
  const [startDate, setStartDate] = useState(new Date(now.getFullYear(), now.getMonth(), 1).toISOString().split('T')[0]);
  const [endDate, setEndDate] = useState(new Date(now.getFullYear(), now.getMonth() + 1, 0).toISOString().split('T')[0]);
  const [accountFilter, setAccountFilter] = useState('all');

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
      return true;
    });
  }, [transactions, month, year, filterType, startDate, endDate, accountFilter]);

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

  const exportPDF = () => {
    const doc = new jsPDF();
    const title = `Financial Report - ${filterType === 'monthly' ? `${months[month - 1]} ${year}` : `${startDate} to ${endDate}`}`;
    
    doc.setFontSize(18);
    doc.text(title, 14, 22);
    
    doc.setFontSize(12);
    doc.text(`Total Income: BDT ${stats.income.toLocaleString()}`, 14, 32);
    doc.text(`Total Expense: BDT ${stats.expense.toLocaleString()}`, 14, 38);
    doc.text(`Net Savings: BDT ${stats.net.toLocaleString()}`, 14, 44);

    const tableData = monthTx.map(t => [
      t.date,
      t.type.toUpperCase(),
      t.categories?.name || 'Other',
      t.amount.toLocaleString(),
      t.description || '-'
    ]);

    doc.autoTable({
      startY: 50,
      head: [['Date', 'Type', 'Category', 'Amount', 'Description']],
      body: tableData,
      theme: 'grid',
      headStyles: { fillColor: [6, 182, 212] }
    });

    doc.save(`Report_${title.replace(/[^a-zA-Z0-9]/g, '_')}.pdf`);
  };

  const exportExcel = () => {
    const title = `Financial Report - ${filterType === 'monthly' ? `${months[month - 1]} ${year}` : `${startDate} to ${endDate}`}`;
    
    const summaryData = [
      ['Report Period', filterType === 'monthly' ? `${months[month - 1]} ${year}` : `${startDate} to ${endDate}`],
      ['Total Income', stats.income],
      ['Total Expense', stats.expense],
      ['Net Savings', stats.net],
      ['Total Transactions', stats.count],
      [], 
      ['Date', 'Type', 'Category', 'Amount', 'Description']
    ];

    const txData = monthTx.map(t => [
      t.date,
      t.type.toUpperCase(),
      t.categories?.name || 'Other',
      t.amount,
      t.description || '-'
    ]);

    const ws = XLSX.utils.aoa_to_sheet([...summaryData, ...txData]);
    const wb = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(wb, ws, 'Report');
    XLSX.writeFile(wb, `Report_${title.replace(/[^a-zA-Z0-9]/g, '_')}.xlsx`);
  };


  return (
    <div className="space-y-6 animate-in">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-white">Monthly Report</h1>
          <p className="text-white/40 text-sm mt-1">Detailed financial analysis</p>
        </div>
        <div className="flex flex-col items-end gap-3">
          <div className="flex flex-col sm:flex-row gap-3">
            <div className="flex gap-2">
              <button onClick={exportPDF} className="flex items-center gap-2 px-3 py-1.5 rounded-lg text-sm bg-red-500/20 text-red-400 hover:bg-red-500/30 transition-all font-medium whitespace-nowrap">
                <FileText size={16} /> PDF
              </button>
              <button onClick={exportExcel} className="flex items-center gap-2 px-3 py-1.5 rounded-lg text-sm bg-emerald-500/20 text-emerald-400 hover:bg-emerald-500/30 transition-all font-medium whitespace-nowrap">
                <FileSpreadsheet size={16} /> Excel
              </button>
            </div>
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

          {/* Account filter */}
          <select
            value={accountFilter}
            onChange={e => setAccountFilter(e.target.value)}
            className="bg-white/5 border border-white/10 rounded-xl px-4 py-2 text-white text-sm focus:outline-none focus:border-cyan-500/50 appearance-none cursor-pointer"
          >
            <option value="all" className="bg-[#12122a]">All Accounts</option>
            {accounts.map(a => (
              <option key={a.id} value={a.id} className="bg-[#12122a]">{a.name}</option>
            ))}
          </select>

          {filterType === 'monthly' ? (
            <div className="flex gap-3">
              <select
                value={month}
                onChange={e => setMonth(parseInt(e.target.value))}
                className="bg-white/5 border border-white/10 rounded-xl px-4 py-2.5 text-white text-sm focus:outline-none focus:border-cyan-500/50 appearance-none cursor-pointer"
              >
                {months.map((m, i) => (
                  <option key={i} value={i + 1} className="bg-[#12122a]">{m}</option>
                ))}
              </select>
              <select
                value={year}
                onChange={e => setYear(parseInt(e.target.value))}
                className="bg-white/5 border border-white/10 rounded-xl px-4 py-2.5 text-white text-sm focus:outline-none focus:border-cyan-500/50 appearance-none cursor-pointer"
              >
                {[2024, 2025, 2026, 2027].map(y => (
                  <option key={y} value={y} className="bg-[#12122a]">{y}</option>
                ))}
              </select>
            </div>
          ) : (
            <div className="flex gap-3 items-center">
              <input type="date" value={startDate} onChange={e => setStartDate(e.target.value)} className="bg-white/5 border border-white/10 rounded-xl px-4 py-2.5 text-white text-sm focus:outline-none focus:border-cyan-500/50" />
              <span className="text-white/40">to</span>
              <input type="date" value={endDate} onChange={e => setEndDate(e.target.value)} className="bg-white/5 border border-white/10 rounded-xl px-4 py-2.5 text-white text-sm focus:outline-none focus:border-cyan-500/50" />
            </div>
          )}
        </div>
      </div>

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
    </div>
  );
}

import { useState, useEffect, useCallback } from 'react';
import {
  ResponsiveContainer, LineChart, Line, BarChart, Bar,
  CartesianGrid, XAxis, YAxis, Tooltip, Legend
} from 'recharts';
import { TrendingUp, Search } from 'lucide-react';

const fmt = (n) => `৳${Number(n || 0).toLocaleString()}`;
const MONTHS_SHORT = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

function ChartTooltip({ active, payload, label }) {
  if (!active || !payload || !payload.length) return null;
  return (
    <div className="bg-muted border border-foreground/10 rounded-xl p-3 shadow-xl">
      <p className="text-foreground/50 text-xs mb-1">{label}</p>
      {payload.map((p, i) => (
        <p key={i} className="text-sm font-medium" style={{ color: p.color }}>
          {p.name}: {typeof p.value === 'number' ? fmt(p.value) : p.value}
        </p>
      ))}
    </div>
  );
}

export default function MealReports({ fetchTrend, fetchItemNames, fetchItemPriceHistory }) {
  const [monthsBack, setMonthsBack] = useState(6);
  const [trend, setTrend] = useState([]);
  const [loading, setLoading] = useState(true);

  const [itemNames, setItemNames] = useState([]);
  const [selectedItem, setSelectedItem] = useState('');
  const [priceHistory, setPriceHistory] = useState([]);
  const [historyLoading, setHistoryLoading] = useState(false);

  const loadTrend = useCallback(async () => {
    setLoading(true);
    try {
      const rows = await fetchTrend(monthsBack);
      setTrend(rows.map(r => ({
        label: `${MONTHS_SHORT[r.month - 1]} ${String(r.year).slice(-2)}`,
        'Bazar Spend': Number(r.total_bazar),
        'Fixed Cost': Number(r.total_fixed),
        'Meal Rate': Number(r.meal_rate),
        topSpender: r.top_spender_name,
        topSpenderAmount: r.top_spender_amount
      })));
    } catch (err) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  }, [fetchTrend, monthsBack]);

  useEffect(() => { loadTrend(); }, [loadTrend]);

  useEffect(() => {
    fetchItemNames().then(setItemNames).catch(err => console.error(err));
  }, [fetchItemNames]);

  useEffect(() => {
    if (!selectedItem) { setPriceHistory([]); return; }
    setHistoryLoading(true);
    fetchItemPriceHistory(selectedItem)
      .then(rows => setPriceHistory(rows.map(r => ({ date: r.date, amount: Number(r.amount) }))))
      .catch(err => console.error(err))
      .finally(() => setHistoryLoading(false));
  }, [selectedItem, fetchItemPriceHistory]);

  const topSpenderRows = trend.filter(r => r.topSpender);

  return (
    <div className="space-y-6">
      <div className="bg-card border border-foreground/10 rounded-2xl p-6">
        <div className="flex flex-wrap items-center justify-between gap-3 mb-4">
          <h3 className="text-foreground font-semibold flex items-center gap-2"><TrendingUp size={18} /> Spend Trend</h3>
          <select value={monthsBack} onChange={e => setMonthsBack(Number(e.target.value))} className="bg-muted border border-foreground/10 rounded-xl px-3 py-2 text-foreground text-sm focus:outline-none focus:border-cyan-500/50">
            {[3, 6, 12].map(n => <option key={n} value={n}>Last {n} months</option>)}
          </select>
        </div>
        {loading ? (
          <div className="h-64 flex items-center justify-center text-foreground/30 text-sm">Loading...</div>
        ) : trend.length === 0 ? (
          <div className="h-64 flex items-center justify-center text-foreground/30 text-sm">No data yet.</div>
        ) : (
          <ResponsiveContainer width="100%" height={280}>
            <BarChart data={trend} barGap={4}>
              <CartesianGrid strokeDasharray="3 3" stroke="#ffffff08" />
              <XAxis dataKey="label" tick={{ fill: '#ffffff60', fontSize: 11 }} axisLine={false} tickLine={false} />
              <YAxis tick={{ fill: '#ffffff60', fontSize: 11 }} axisLine={false} tickLine={false} />
              <Tooltip content={<ChartTooltip />} cursor={{ fill: '#ffffff08' }} />
              <Legend wrapperStyle={{ color: '#ffffff60', fontSize: 12 }} />
              <Bar dataKey="Bazar Spend" fill="#06b6d4" radius={[6, 6, 0, 0]} />
              <Bar dataKey="Fixed Cost" fill="#f97316" radius={[6, 6, 0, 0]} />
            </BarChart>
          </ResponsiveContainer>
        )}
      </div>

      <div className="bg-card border border-foreground/10 rounded-2xl p-6">
        <h3 className="text-foreground font-semibold mb-4">Meal Rate Trend</h3>
        {!loading && trend.length > 0 && (
          <ResponsiveContainer width="100%" height={220}>
            <LineChart data={trend}>
              <CartesianGrid strokeDasharray="3 3" stroke="#ffffff08" />
              <XAxis dataKey="label" tick={{ fill: '#ffffff60', fontSize: 11 }} axisLine={false} tickLine={false} />
              <YAxis tick={{ fill: '#ffffff60', fontSize: 11 }} axisLine={false} tickLine={false} />
              <Tooltip content={<ChartTooltip />} />
              <Line type="monotone" dataKey="Meal Rate" stroke="#a78bfa" strokeWidth={2} dot={{ r: 3 }} />
            </LineChart>
          </ResponsiveContainer>
        )}
      </div>

      <div className="bg-card border border-foreground/10 rounded-2xl p-6">
        <h3 className="text-foreground font-semibold mb-4">Top Bazar Spender by Month</h3>
        <div className="divide-y divide-foreground/5">
          {topSpenderRows.map((r, i) => (
            <div key={i} className="flex justify-between items-center py-2 text-sm">
              <span className="text-foreground/60">{r.label}</span>
              <span className="text-foreground">{r.topSpender}</span>
              <span className="text-cyan-400 font-medium">{fmt(r.topSpenderAmount)}</span>
            </div>
          ))}
          {topSpenderRows.length === 0 && <p className="text-foreground/30 text-sm py-4 text-center">No bazar expenses recorded yet.</p>}
        </div>
      </div>

      <div className="bg-card border border-foreground/10 rounded-2xl p-6">
        <h3 className="text-foreground font-semibold mb-4 flex items-center gap-2"><Search size={18} /> Item Price History</h3>
        <select value={selectedItem} onChange={e => setSelectedItem(e.target.value)} className="w-full sm:w-72 bg-muted border border-foreground/10 rounded-xl px-4 py-2.5 text-foreground text-sm focus:outline-none focus:border-cyan-500/50 mb-4">
          <option value="">Select an item...</option>
          {itemNames.map(name => <option key={name} value={name}>{name}</option>)}
        </select>
        {historyLoading ? (
          <div className="h-48 flex items-center justify-center text-foreground/30 text-sm">Loading...</div>
        ) : selectedItem && priceHistory.length > 0 ? (
          <ResponsiveContainer width="100%" height={220}>
            <LineChart data={priceHistory}>
              <CartesianGrid strokeDasharray="3 3" stroke="#ffffff08" />
              <XAxis dataKey="date" tick={{ fill: '#ffffff60', fontSize: 11 }} axisLine={false} tickLine={false} />
              <YAxis tick={{ fill: '#ffffff60', fontSize: 11 }} axisLine={false} tickLine={false} />
              <Tooltip content={<ChartTooltip />} />
              <Line type="monotone" dataKey="amount" name="Price" stroke="#06b6d4" strokeWidth={2} dot={{ r: 3 }} />
            </LineChart>
          </ResponsiveContainer>
        ) : selectedItem ? (
          <p className="text-foreground/30 text-sm text-center py-8">No priced entries for "{selectedItem}" yet.</p>
        ) : (
          <p className="text-foreground/30 text-sm text-center py-8">Pick an item to see how its price has moved over time.</p>
        )}
      </div>
    </div>
  );
}

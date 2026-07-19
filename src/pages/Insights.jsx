import { useState, useEffect, useCallback, useMemo } from 'react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../context/AuthContext';
import { useEntity } from '../context/EntityContext';
import { getInsights } from '../lib/ai';
import { Sparkles, TrendingUp, TrendingDown, PiggyBank, Send, Bot } from 'lucide-react';

const fmt = (n) => `৳${Math.round(Number(n || 0)).toLocaleString()}`;
const monthKey = (d) => d.toISOString().slice(0, 7);

export default function Insights() {
  const { user } = useAuth();
  const { currentEntity } = useEntity();
  const [transactions, setTransactions] = useState([]);
  const [loading, setLoading] = useState(true);
  const [question, setQuestion] = useState('');
  const [chat, setChat] = useState([]); // { role: 'user' | 'ai', text }
  const [asking, setAsking] = useState(false);

  const fetchData = useCallback(async () => {
    if (!user || !currentEntity) return;
    setLoading(true);
    const start = new Date();
    start.setDate(1);
    start.setMonth(start.getMonth() - 3);
    const { data, error } = await supabase
      .from('transactions')
      .select('type, amount, date, description, categories(name, icon)')
      .eq('user_id', user.id)
      .eq('entity_id', currentEntity.id)
      .gte('date', start.toISOString().split('T')[0])
      .order('date', { ascending: false });
    if (error) console.error('Error fetching transactions:', error);
    else setTransactions(data || []);
    setLoading(false);
  }, [user, currentEntity]);

  useEffect(() => { fetchData(); }, [fetchData]);

  const stats = useMemo(() => {
    const now = new Date();
    const thisM = monthKey(now);
    const lastM = monthKey(new Date(now.getFullYear(), now.getMonth() - 1, 15));
    const sum = (list) => list.reduce((s, t) => s + Number(t.amount), 0);
    const inMonth = (m) => transactions.filter(t => t.date?.startsWith(m));
    const thisMonth = inMonth(thisM);
    const lastMonth = inMonth(lastM);
    const expThis = sum(thisMonth.filter(t => t.type === 'expense'));
    const expLast = sum(lastMonth.filter(t => t.type === 'expense'));
    const incThis = sum(thisMonth.filter(t => t.type === 'income'));

    // category totals this month
    const catMap = new Map();
    for (const t of thisMonth.filter(t => t.type === 'expense')) {
      const name = t.categories ? `${t.categories.icon || ''} ${t.categories.name}`.trim() : 'Uncategorized';
      catMap.set(name, (catMap.get(name) || 0) + Number(t.amount));
    }
    const topCats = [...catMap.entries()].sort((a, b) => b[1] - a[1]).slice(0, 5);

    // category comparison vs last month for auto insights
    const catLast = new Map();
    for (const t of lastMonth.filter(t => t.type === 'expense')) {
      const name = t.categories ? `${t.categories.icon || ''} ${t.categories.name}`.trim() : 'Uncategorized';
      catLast.set(name, (catLast.get(name) || 0) + Number(t.amount));
    }
    const findings = [];
    if (expLast > 0) {
      const change = ((expThis - expLast) / expLast) * 100;
      if (Math.abs(change) >= 10) {
        findings.push({
          up: change > 0,
          text: `Overall spending is ${Math.abs(change).toFixed(0)}% ${change > 0 ? 'higher' : 'lower'} than last month (${fmt(expThis)} vs ${fmt(expLast)}).`
        });
      }
    }
    for (const [cat, amt] of topCats) {
      const prev = catLast.get(cat) || 0;
      if (prev > 500 && amt > prev * 1.3) {
        findings.push({ up: true, text: `${cat} jumped ${(((amt - prev) / prev) * 100).toFixed(0)}% — ${fmt(amt)} this month vs ${fmt(prev)} last month.` });
      } else if (prev > 500 && amt < prev * 0.7) {
        findings.push({ up: false, text: `${cat} dropped to ${fmt(amt)} from ${fmt(prev)} — nice saving.` });
      }
    }
    const savingsRate = incThis > 0 ? ((incThis - expThis) / incThis) * 100 : null;
    if (savingsRate !== null) {
      findings.push({
        up: savingsRate >= 20,
        text: savingsRate >= 0
          ? `You're keeping ${savingsRate.toFixed(0)}% of this month's income (${fmt(incThis - expThis)}).`
          : `You've spent ${fmt(expThis - incThis)} more than you earned this month.`
      });
    }
    const biggest = [...thisMonth.filter(t => t.type === 'expense')].sort((a, b) => b.amount - a.amount)[0];
    if (biggest) findings.push({ up: null, text: `Biggest single expense this month: ${fmt(biggest.amount)}${biggest.description ? ` — ${biggest.description}` : ''}.` });

    return { expThis, expLast, incThis, topCats, findings, savingsRate };
  }, [transactions]);

  // compact aggregated context for the AI (numbers only, no raw dump)
  const aiContext = useMemo(() => {
    const byMonth = {};
    for (const t of transactions) {
      const m = t.date?.slice(0, 7);
      if (!m) continue;
      byMonth[m] = byMonth[m] || { income: 0, expense: 0 };
      byMonth[m][t.type === 'income' ? 'income' : 'expense'] += Number(t.amount);
    }
    return JSON.stringify({
      currency: 'BDT',
      months: byMonth,
      this_month_top_categories: Object.fromEntries(stats.topCats),
      savings_rate_pct: stats.savingsRate?.toFixed(1) ?? null
    });
  }, [transactions, stats]);

  const ask = async (q) => {
    const text = (q || question).trim();
    if (!text || asking) return;
    setQuestion('');
    setChat(prev => [...prev, { role: 'user', text }]);
    setAsking(true);
    try {
      const result = await getInsights(aiContext, text);
      setChat(prev => [...prev, { role: 'ai', text: result?.answer || String(result) }]);
    } catch (err) {
      setChat(prev => [...prev, { role: 'ai', text: '⚠️ ' + err.message }]);
    }
    setAsking(false);
  };

  if (loading) return <div className="text-foreground/50 p-6">Analyzing your spending...</div>;

  return (
    <div className="space-y-6 animate-in">
      <div>
        <h1 className="text-2xl font-bold text-foreground">Spending Insights</h1>
        <p className="text-foreground/40 text-sm mt-1">What changed, where the money went, and an AI you can ask.</p>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <div className="space-y-6">
          <div className="bg-card border border-foreground/10 rounded-2xl p-5">
            <h3 className="text-foreground font-semibold mb-3 flex items-center gap-2"><Sparkles size={16} className="text-violet-400" /> This Month's Findings</h3>
            <div className="space-y-2.5">
              {stats.findings.map((f, i) => (
                <div key={i} className="flex items-start gap-2.5 text-sm">
                  {f.up === true ? <TrendingUp size={16} className="text-red-400 shrink-0 mt-0.5" />
                    : f.up === false ? <TrendingDown size={16} className="text-emerald-400 shrink-0 mt-0.5" />
                    : <PiggyBank size={16} className="text-cyan-400 shrink-0 mt-0.5" />}
                  <p className="text-foreground/70">{f.text}</p>
                </div>
              ))}
              {stats.findings.length === 0 && <p className="text-xs text-foreground/30">Not enough data yet — add some transactions first.</p>}
            </div>
          </div>

          <div className="bg-card border border-foreground/10 rounded-2xl p-5">
            <h3 className="text-foreground font-semibold mb-3">Top Categories (this month)</h3>
            <div className="space-y-2.5">
              {stats.topCats.map(([cat, amt]) => {
                const pct = stats.expThis > 0 ? (amt / stats.expThis) * 100 : 0;
                return (
                  <div key={cat}>
                    <div className="flex justify-between text-sm mb-1">
                      <span className="text-foreground/60">{cat}</span>
                      <span className="text-foreground font-medium">{fmt(amt)} <span className="text-foreground/35 text-xs">({pct.toFixed(0)}%)</span></span>
                    </div>
                    <div className="h-1.5 w-full bg-muted rounded-full overflow-hidden">
                      <div className="h-full bg-violet-500 rounded-full" style={{ width: `${pct}%` }} />
                    </div>
                  </div>
                );
              })}
              {stats.topCats.length === 0 && <p className="text-xs text-foreground/30">No expenses recorded this month.</p>}
            </div>
          </div>
        </div>

        <div className="bg-card border border-foreground/10 rounded-2xl p-5 flex flex-col">
          <h3 className="text-foreground font-semibold mb-3 flex items-center gap-2"><Bot size={16} className="text-violet-400" /> Ask AI</h3>
          <div className="flex-1 space-y-3 overflow-y-auto min-h-48 max-h-96 mb-3">
            {chat.length === 0 && (
              <div className="space-y-2">
                <p className="text-xs text-foreground/35 mb-2">Try one of these:</p>
                {['Kon category te sobcheye beshi khoroch hocche?', 'How can I cut 10% of my spending?', 'Is my spending trend healthy?'].map(q => (
                  <button key={q} onClick={() => ask(q)} className="block w-full text-left text-xs bg-muted hover:bg-violet-500/10 text-white/50 hover:text-violet-300 rounded-xl px-3 py-2.5 transition-all">
                    💬 {q}
                  </button>
                ))}
              </div>
            )}
            {chat.map((m, i) => (
              <div key={i} className={`text-sm rounded-xl px-3.5 py-2.5 whitespace-pre-wrap ${m.role === 'user' ? 'bg-violet-500/15 text-violet-200 ml-8' : 'bg-muted text-white/70 mr-4'}`}>
                {m.text}
              </div>
            ))}
            {asking && <div className="text-sm bg-muted text-foreground/40 rounded-xl px-3.5 py-2.5 mr-4 animate-pulse">Thinking...</div>}
          </div>
          <form onSubmit={e => { e.preventDefault(); ask(); }} className="flex gap-2">
            <input
              type="text" value={question} onChange={e => setQuestion(e.target.value)}
              placeholder="Ask about your spending..."
              className="flex-1 min-w-0 bg-muted border border-foreground/10 rounded-xl px-4 py-2.5 text-foreground text-sm focus:outline-none focus:border-violet-500/50"
            />
            <button type="submit" disabled={asking || !question.trim()} className="bg-violet-500 hover:bg-violet-600 disabled:opacity-40 text-white px-4 rounded-xl transition-all">
              <Send size={16} />
            </button>
          </form>
          <p className="text-[10px] text-foreground/25 mt-2">Only aggregated totals are sent to the AI — not your individual transactions.</p>
        </div>
      </div>
    </div>
  );
}

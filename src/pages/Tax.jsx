import { useState, useEffect, useMemo, useCallback } from 'react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../context/AuthContext';
import { useEntity } from '../context/EntityContext';
import { Landmark, Info } from 'lucide-react';

const fmt = (n) => `৳${Math.round(Number(n || 0)).toLocaleString()}`;
const SETTINGS_KEY = 'tax_settings_v1';

// NBR-style progressive slabs (editable — verify against the current Finance Act).
const DEFAULT_SLABS = [
  { limit: 350000, rate: 0 },
  { limit: 100000, rate: 5 },
  { limit: 400000, rate: 10 },
  { limit: 500000, rate: 15 },
  { limit: 500000, rate: 20 },
  { limit: 2000000, rate: 25 },
  { limit: Infinity, rate: 30 }
];
const defaultSettings = {
  extraIncome: '',        // income not tracked in the app
  exemptIncome: '',       // e.g. allowances that are tax-exempt
  investmentForRebate: '',
  rebateRate: 15,         // % of eligible investment
  rebateCapPctOfIncome: 3,
  minTax: 5000,
  taxFreeLimit: 350000    // 400000 for women / 65+, editable
};

// FY = July..June. fyStartYear 2025 means FY 2025-26.
const currentFyStart = () => {
  const now = new Date();
  return now.getMonth() >= 6 ? now.getFullYear() : now.getFullYear() - 1;
};

export default function Tax() {
  const { user } = useAuth();
  const { currentEntity } = useEntity();
  const [fyStart, setFyStart] = useState(currentFyStart());
  const [trackedIncome, setTrackedIncome] = useState(0);
  const [loading, setLoading] = useState(true);
  const [s, setS] = useState(() => {
    try { return { ...defaultSettings, ...JSON.parse(localStorage.getItem(SETTINGS_KEY) || '{}') }; }
    catch { return defaultSettings; }
  });

  useEffect(() => { localStorage.setItem(SETTINGS_KEY, JSON.stringify(s)); }, [s]);
  const set = (patch) => setS(prev => ({ ...prev, ...patch }));

  const fetchIncome = useCallback(async () => {
    if (!user || !currentEntity) return;
    setLoading(true);
    const { data, error } = await supabase
      .from('transactions')
      .select('amount')
      .eq('user_id', user.id)
      .eq('entity_id', currentEntity.id)
      .eq('type', 'income')
      .gte('date', `${fyStart}-07-01`)
      .lte('date', `${fyStart + 1}-06-30`);
    if (error) console.error('Error fetching income:', error);
    else setTrackedIncome((data || []).reduce((sum, t) => sum + Number(t.amount), 0));
    setLoading(false);
  }, [user, currentEntity, fyStart]);

  useEffect(() => { fetchIncome(); }, [fetchIncome]);

  const calc = useMemo(() => {
    const gross = trackedIncome + (parseFloat(s.extraIncome) || 0);
    const taxable = Math.max(0, gross - (parseFloat(s.exemptIncome) || 0));
    // slabs with the editable tax-free limit swapped in
    const slabs = DEFAULT_SLABS.map((sl, i) => i === 0 ? { ...sl, limit: parseFloat(s.taxFreeLimit) || 0 } : sl);
    let remaining = taxable;
    let tax = 0;
    const breakdown = [];
    for (const slab of slabs) {
      if (remaining <= 0) break;
      const inSlab = Math.min(remaining, slab.limit);
      const slabTax = inSlab * slab.rate / 100;
      tax += slabTax;
      breakdown.push({ amount: inSlab, rate: slab.rate, tax: slabTax });
      remaining -= inSlab;
    }
    const eligibleInvestment = Math.min(
      parseFloat(s.investmentForRebate) || 0,
      taxable * (parseFloat(s.rebateCapPctOfIncome) || 0) / 100
    );
    const rebate = Math.min(eligibleInvestment * (parseFloat(s.rebateRate) || 0) / 100, tax);
    const afterRebate = Math.max(0, tax - rebate);
    const payable = taxable > (parseFloat(s.taxFreeLimit) || 0) ? Math.max(afterRebate, parseFloat(s.minTax) || 0) : afterRebate;
    return { gross, taxable, tax, breakdown, rebate, payable };
  }, [trackedIncome, s]);

  return (
    <div className="space-y-6 animate-in">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h1 className="text-2xl font-bold text-white">Income Tax Helper</h1>
          <p className="text-white/40 text-sm mt-1">Estimate for FY {fyStart}-{String(fyStart + 1).slice(2)} (July–June), from your tracked income.</p>
        </div>
        <select value={fyStart} onChange={e => setFyStart(Number(e.target.value))} className="bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white text-sm focus:outline-none focus:border-cyan-500/50">
          {[0, 1, 2, 3].map(i => {
            const y = currentFyStart() - i;
            return <option key={y} value={y}>FY {y}-{String(y + 1).slice(2)}</option>;
          })}
        </select>
      </div>

      <div className={`rounded-2xl p-6 border ${calc.payable > 0 ? 'bg-cyan-500/10 border-cyan-500/25' : 'bg-white/[0.03] border-white/10'}`}>
        <div className="flex items-center gap-4">
          <div className="w-14 h-14 rounded-2xl bg-cyan-500/20 flex items-center justify-center">
            <Landmark className="text-cyan-400" size={28} />
          </div>
          <div>
            <p className="text-sm text-cyan-400/90 font-medium">Estimated tax payable</p>
            <p className="text-3xl font-bold text-white mt-0.5">{loading ? '...' : fmt(calc.payable)}</p>
            <p className="text-xs text-white/40 mt-1">
              Taxable income {fmt(calc.taxable)} · gross tax {fmt(calc.tax)} − rebate {fmt(calc.rebate)}
            </p>
          </div>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <div className="bg-[#1a1a2e] border border-white/10 rounded-2xl p-5 space-y-4">
          <h3 className="text-white font-semibold">Income & Adjustments</h3>
          <div className="flex justify-between text-sm bg-[#12122a] rounded-xl px-4 py-3">
            <span className="text-white/50">Tracked income (this FY)</span>
            <span className="text-emerald-400 font-medium">{loading ? '...' : fmt(trackedIncome)}</span>
          </div>
          <div>
            <label className="block text-sm text-white/60 mb-1">Income NOT tracked in the app</label>
            <input type="number" value={s.extraIncome} onChange={e => set({ extraIncome: e.target.value })} placeholder="0" className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-cyan-500/50" />
          </div>
          <div>
            <label className="block text-sm text-white/60 mb-1">Exempt portion (allowances etc.)</label>
            <input type="number" value={s.exemptIncome} onChange={e => set({ exemptIncome: e.target.value })} placeholder="0" className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-cyan-500/50" />
          </div>
          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="block text-sm text-white/60 mb-1">Tax-free limit</label>
              <input type="number" value={s.taxFreeLimit} onChange={e => set({ taxFreeLimit: e.target.value })} className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-cyan-500/50" />
              <p className="text-[11px] text-white/30 mt-1">350k general · 400k women/65+</p>
            </div>
            <div>
              <label className="block text-sm text-white/60 mb-1">Minimum tax</label>
              <input type="number" value={s.minTax} onChange={e => set({ minTax: e.target.value })} className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-cyan-500/50" />
            </div>
          </div>
          <div>
            <label className="block text-sm text-white/60 mb-1">Investment eligible for rebate (DPS, sanchaypatra, shares…)</label>
            <input type="number" value={s.investmentForRebate} onChange={e => set({ investmentForRebate: e.target.value })} placeholder="0" className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-cyan-500/50" />
            <p className="text-[11px] text-white/30 mt-1">Rebate = {s.rebateRate}% of investment, capped at {s.rebateCapPctOfIncome}% of taxable income (both editable below)</p>
          </div>
          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="block text-sm text-white/60 mb-1">Rebate rate %</label>
              <input type="number" value={s.rebateRate} onChange={e => set({ rebateRate: e.target.value })} className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-cyan-500/50" />
            </div>
            <div>
              <label className="block text-sm text-white/60 mb-1">Cap (% of income)</label>
              <input type="number" value={s.rebateCapPctOfIncome} onChange={e => set({ rebateCapPctOfIncome: e.target.value })} className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-cyan-500/50" />
            </div>
          </div>
        </div>

        <div className="space-y-6">
          <div className="bg-[#1a1a2e] border border-white/10 rounded-2xl overflow-hidden">
            <div className="p-5 border-b border-white/10"><h3 className="text-white font-semibold">Slab Breakdown</h3></div>
            <table className="w-full text-sm">
              <thead>
                <tr className="bg-white/5 border-b border-white/10">
                  <th className="text-left py-2.5 px-5 text-white/60 font-medium">Income in slab</th>
                  <th className="text-right py-2.5 px-5 text-white/60 font-medium">Rate</th>
                  <th className="text-right py-2.5 px-5 text-white/60 font-medium">Tax</th>
                </tr>
              </thead>
              <tbody>
                {calc.breakdown.map((b, i) => (
                  <tr key={i} className="border-b border-white/5">
                    <td className="py-2.5 px-5 text-white/70">{fmt(b.amount)}</td>
                    <td className="py-2.5 px-5 text-right text-white/50">{b.rate}%</td>
                    <td className="py-2.5 px-5 text-right text-white font-medium">{fmt(b.tax)}</td>
                  </tr>
                ))}
                {calc.breakdown.length === 0 && (
                  <tr><td colSpan={3} className="py-6 px-5 text-center text-white/30 text-xs">No taxable income this FY yet.</td></tr>
                )}
              </tbody>
            </table>
          </div>

          <div className="flex items-start gap-3 bg-cyan-500/5 border border-cyan-500/15 rounded-2xl p-4">
            <Info className="text-cyan-400/70 shrink-0 mt-0.5" size={16} />
            <p className="text-xs text-white/50 leading-relaxed">
              This is an estimate only. Slabs, rebate rules and minimum tax change with each Finance Act — verify with NBR's current rules
              or a tax practitioner before filing your return. All the numbers above are editable so you can match the latest rules.
            </p>
          </div>
        </div>
      </div>
    </div>
  );
}

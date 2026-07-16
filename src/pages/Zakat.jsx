import { useState, useEffect, useMemo } from 'react';
import { useZakat } from '../hooks/useZakat';
import { useAccounts } from '../context/AccountContext';
import { Moon, Info } from 'lucide-react';

const fmt = (n) => `৳${Math.round(Number(n || 0)).toLocaleString()}`;

const VORI_GRAMS = 11.664;
const NISAB_GOLD_VORI = 7.5;    // 87.48 g
const NISAB_SILVER_VORI = 52.5; // 612.36 g
const ZAKAT_RATE = 0.025;

const SETTINGS_KEY = 'zakat_settings_v1';
const defaultSettings = {
  basis: 'silver', // silver nisab is the safer (lower) threshold, most commonly advised
  goldPriceVori: 145000,
  silverPriceVori: 2200,
  goldOwnedVori: '',
  silverOwnedVori: '',
  otherAssets: '',
  includeCash: true,
  includeSavings: true,
  includeInvestments: true,
  includeReceivables: true,
  deductDebts: true
};

function loadSettings() {
  try {
    const raw = localStorage.getItem(SETTINGS_KEY);
    return raw ? { ...defaultSettings, ...JSON.parse(raw) } : defaultSettings;
  } catch {
    return defaultSettings;
  }
}

export default function Zakat() {
  const { savingsBalance, investmentsValue, receivables, debts, loading } = useZakat();
  const { accounts } = useAccounts();
  const [s, setS] = useState(loadSettings);

  useEffect(() => {
    localStorage.setItem(SETTINGS_KEY, JSON.stringify(s));
  }, [s]);

  const set = (patch) => setS(prev => ({ ...prev, ...patch }));

  const cash = useMemo(
    () => accounts.reduce((sum, a) => sum + Number(a.current_balance || 0), 0),
    [accounts]
  );

  const goldValue = (parseFloat(s.goldOwnedVori) || 0) * (parseFloat(s.goldPriceVori) || 0);
  const silverValue = (parseFloat(s.silverOwnedVori) || 0) * (parseFloat(s.silverPriceVori) || 0);
  const otherValue = parseFloat(s.otherAssets) || 0;

  const rows = [
    { key: 'includeCash', label: 'Cash & Bank Accounts', value: cash, toggle: true },
    { key: 'includeSavings', label: 'Savings Balance', value: savingsBalance, toggle: true },
    { key: 'includeInvestments', label: 'Investments (current value)', value: investmentsValue, toggle: true },
    { key: 'includeReceivables', label: 'Receivables (loans you gave)', value: receivables, toggle: true },
    { key: 'gold', label: `Gold (${s.goldOwnedVori || 0} vori)`, value: goldValue, toggle: false },
    { key: 'silver', label: `Silver (${s.silverOwnedVori || 0} vori)`, value: silverValue, toggle: false },
    { key: 'other', label: 'Other zakatable assets', value: otherValue, toggle: false }
  ];

  const totalAssets =
    (s.includeCash ? cash : 0) +
    (s.includeSavings ? savingsBalance : 0) +
    (s.includeInvestments ? investmentsValue : 0) +
    (s.includeReceivables ? receivables : 0) +
    goldValue + silverValue + otherValue;

  const deductible = s.deductDebts ? debts : 0;
  const netWealth = totalAssets - deductible;

  const nisab = s.basis === 'gold'
    ? NISAB_GOLD_VORI * (parseFloat(s.goldPriceVori) || 0)
    : NISAB_SILVER_VORI * (parseFloat(s.silverPriceVori) || 0);

  const eligible = netWealth >= nisab && nisab > 0;
  const zakatDue = eligible ? netWealth * ZAKAT_RATE : 0;

  if (loading) return <div className="text-white/50 p-6">Loading your balance sheet...</div>;

  return (
    <div className="space-y-6 animate-in">
      <div>
        <h1 className="text-2xl font-bold text-white">Zakat Calculator</h1>
        <p className="text-white/40 text-sm mt-1">Your zakatable wealth, computed from what's already tracked in the app.</p>
      </div>

      {/* Result banner */}
      <div className={`rounded-2xl p-6 border ${eligible ? 'bg-emerald-500/10 border-emerald-500/25' : 'bg-white/[0.03] border-white/10'}`}>
        <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
          <div className="flex items-center gap-4">
            <div className={`w-14 h-14 rounded-2xl flex items-center justify-center ${eligible ? 'bg-emerald-500/20' : 'bg-white/5'}`}>
              <Moon className={eligible ? 'text-emerald-400' : 'text-white/40'} size={28} />
            </div>
            <div>
              {eligible ? (
                <>
                  <p className="text-sm text-emerald-400/90 font-medium">Zakat is due on your wealth</p>
                  <p className="text-3xl font-bold text-white mt-0.5">{fmt(zakatDue)}</p>
                  <p className="text-xs text-white/40 mt-1">2.5% of {fmt(netWealth)} net zakatable wealth</p>
                </>
              ) : (
                <>
                  <p className="text-sm text-white/60 font-medium">Below nisab — zakat is not obligatory</p>
                  <p className="text-3xl font-bold text-white mt-0.5">{fmt(netWealth)}</p>
                  <p className="text-xs text-white/40 mt-1">Net wealth is under the {fmt(nisab)} threshold</p>
                </>
              )}
            </div>
          </div>
          <div className="text-left sm:text-right">
            <p className="text-xs text-white/40">Nisab ({s.basis === 'gold' ? `${NISAB_GOLD_VORI} vori gold` : `${NISAB_SILVER_VORI} vori silver`})</p>
            <p className="text-lg font-semibold text-white">{fmt(nisab)}</p>
            <div className="flex sm:justify-end gap-2 mt-2">
              {['silver', 'gold'].map(b => (
                <button
                  key={b}
                  onClick={() => set({ basis: b })}
                  className={`px-3 py-1.5 rounded-lg text-xs font-medium capitalize transition-all border ${
                    s.basis === b
                      ? 'bg-cyan-500/20 text-cyan-400 border-cyan-500/40'
                      : 'bg-white/5 text-white/40 border-white/10 hover:bg-white/10'
                  }`}
                >
                  {b} basis
                </button>
              ))}
            </div>
          </div>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Wealth breakdown */}
        <div className="lg:col-span-2 bg-[#1a1a2e] border border-white/10 rounded-2xl overflow-hidden">
          <div className="p-5 border-b border-white/10">
            <h3 className="text-white font-semibold">Zakatable Wealth</h3>
            <p className="text-xs text-white/40 mt-0.5">Untick anything that shouldn't count (e.g. money set aside for immediate needs).</p>
          </div>
          <div className="divide-y divide-white/5">
            {rows.map(row => (
              <div key={row.key} className="flex items-center justify-between px-5 py-3.5">
                <label className="flex items-center gap-3 text-sm text-white/70 cursor-pointer">
                  {row.toggle ? (
                    <input
                      type="checkbox"
                      checked={s[row.key]}
                      onChange={e => set({ [row.key]: e.target.checked })}
                      className="w-4 h-4 rounded accent-cyan-500"
                    />
                  ) : (
                    <span className="w-4 h-4 flex items-center justify-center text-white/25">•</span>
                  )}
                  {row.label}
                </label>
                <span className={`font-medium ${row.toggle && !s[row.key] ? 'text-white/25 line-through' : 'text-white'}`}>
                  {fmt(row.value)}
                </span>
              </div>
            ))}
            <div className="flex items-center justify-between px-5 py-3.5">
              <label className="flex items-center gap-3 text-sm text-white/70 cursor-pointer">
                <input
                  type="checkbox"
                  checked={s.deductDebts}
                  onChange={e => set({ deductDebts: e.target.checked })}
                  className="w-4 h-4 rounded accent-cyan-500"
                />
                Less: outstanding debts you owe
              </label>
              <span className={`font-medium ${s.deductDebts ? 'text-red-400' : 'text-white/25 line-through'}`}>
                −{fmt(debts)}
              </span>
            </div>
            <div className="flex items-center justify-between px-5 py-4 bg-white/[0.03]">
              <span className="text-sm font-semibold text-white">Net Zakatable Wealth</span>
              <span className="font-bold text-white text-lg">{fmt(netWealth)}</span>
            </div>
          </div>
        </div>

        {/* Manual inputs */}
        <div className="space-y-6">
          <div className="bg-[#1a1a2e] border border-white/10 rounded-2xl p-5 space-y-4">
            <div>
              <h3 className="text-white font-semibold">Gold, Silver & Prices</h3>
              <p className="text-xs text-white/40 mt-0.5">Update prices with today's market rate (per vori).</p>
            </div>
            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="block text-xs text-white/50 mb-1">Gold price / vori</label>
                <input type="number" value={s.goldPriceVori} onChange={e => set({ goldPriceVori: e.target.value })}
                  className="w-full bg-[#12122a] border border-white/10 rounded-xl px-3 py-2 text-white text-sm focus:outline-none focus:border-amber-500/50" />
              </div>
              <div>
                <label className="block text-xs text-white/50 mb-1">Silver price / vori</label>
                <input type="number" value={s.silverPriceVori} onChange={e => set({ silverPriceVori: e.target.value })}
                  className="w-full bg-[#12122a] border border-white/10 rounded-xl px-3 py-2 text-white text-sm focus:outline-none focus:border-slate-400/50" />
              </div>
              <div>
                <label className="block text-xs text-white/50 mb-1">Gold you own (vori)</label>
                <input type="number" step="0.01" value={s.goldOwnedVori} onChange={e => set({ goldOwnedVori: e.target.value })} placeholder="0"
                  className="w-full bg-[#12122a] border border-white/10 rounded-xl px-3 py-2 text-white text-sm focus:outline-none focus:border-amber-500/50" />
              </div>
              <div>
                <label className="block text-xs text-white/50 mb-1">Silver you own (vori)</label>
                <input type="number" step="0.01" value={s.silverOwnedVori} onChange={e => set({ silverOwnedVori: e.target.value })} placeholder="0"
                  className="w-full bg-[#12122a] border border-white/10 rounded-xl px-3 py-2 text-white text-sm focus:outline-none focus:border-slate-400/50" />
              </div>
            </div>
            <div>
              <label className="block text-xs text-white/50 mb-1">Other zakatable assets (business stock, etc.)</label>
              <input type="number" value={s.otherAssets} onChange={e => set({ otherAssets: e.target.value })} placeholder="0"
                className="w-full bg-[#12122a] border border-white/10 rounded-xl px-3 py-2 text-white text-sm focus:outline-none focus:border-cyan-500/50" />
            </div>
            <p className="text-[11px] text-white/30">1 vori = {VORI_GRAMS} g · Nisab: {NISAB_GOLD_VORI} vori gold or {NISAB_SILVER_VORI} vori silver</p>
          </div>

          <div className="flex items-start gap-3 bg-cyan-500/5 border border-cyan-500/15 rounded-2xl p-4">
            <Info className="text-cyan-400/70 shrink-0 mt-0.5" size={16} />
            <p className="text-xs text-white/50 leading-relaxed">
              This is an estimate to help you calculate — zakat rules vary by madhhab and personal circumstances
              (lunar year completion, personal-use gold, etc.). Please confirm the final amount with a knowledgeable scholar.
            </p>
          </div>
        </div>
      </div>
    </div>
  );
}

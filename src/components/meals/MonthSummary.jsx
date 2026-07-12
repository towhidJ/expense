import { ShoppingBasket, Utensils, Calculator, Wallet } from 'lucide-react';

const fmt = (n) => `৳${Number(n || 0).toLocaleString()}`;

export default function MonthSummary({ summary, currentUserId }) {
  if (!summary) return <div className="text-white/50 p-6">No summary yet.</div>;

  const members = summary.members || [];
  const me = members.find(m => m.user_id === currentUserId);

  const cards = [
    { label: 'Total Bazar', value: fmt(summary.total_bazar), icon: ShoppingBasket, color: 'text-cyan-400' },
    { label: 'Total Meals', value: Number(summary.total_meals || 0).toLocaleString(), icon: Utensils, color: 'text-purple-400' },
    { label: 'Meal Rate', value: fmt(summary.meal_rate), icon: Calculator, color: 'text-orange-400' },
    {
      label: 'My Balance',
      value: me ? fmt(me.balance) : '—',
      icon: Wallet,
      color: me && Number(me.balance) < 0 ? 'text-red-400' : 'text-emerald-400'
    }
  ];

  return (
    <div className="space-y-6">
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        {cards.map(card => (
          <div key={card.label} className="bg-[#1a1a2e] border border-white/10 rounded-2xl p-5">
            <div className="flex items-center gap-2 text-white/40 text-sm mb-2">
              <card.icon size={16} /> {card.label}
            </div>
            <p className={`text-xl font-bold ${card.color}`}>{card.value}</p>
          </div>
        ))}
      </div>

      {Number(summary.total_fixed) > 0 && (
        <div className="bg-[#1a1a2e] border border-white/10 rounded-2xl p-4 text-sm text-white/60">
          Fixed costs (utility / maid / other) this month:{' '}
          <span className="text-white font-medium">{fmt(summary.total_fixed)}</span>
          {' '}— split among active members. Total deposits:{' '}
          <span className="text-white font-medium">{fmt(summary.total_deposits)}</span>
        </div>
      )}

      <div className="bg-[#1a1a2e] border border-white/10 rounded-2xl overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-white/10 text-white/40 text-left">
                <th className="px-4 py-3 font-medium">Member</th>
                <th className="px-4 py-3 font-medium text-right">Meals</th>
                <th className="px-4 py-3 font-medium text-right">Deposit</th>
                <th className="px-4 py-3 font-medium text-right">Advance</th>
                <th className="px-4 py-3 font-medium text-right">Meal Cost</th>
                <th className="px-4 py-3 font-medium text-right">Fixed Share</th>
                <th className="px-4 py-3 font-medium text-right">Total Cost</th>
                <th className="px-4 py-3 font-medium text-right">Balance</th>
              </tr>
            </thead>
            <tbody>
              {members.map(m => (
                <tr key={m.member_id} className="border-b border-white/5 last:border-0">
                  <td className="px-4 py-3 text-white">
                    {m.display_name}
                    {m.user_id === currentUserId && <span className="text-cyan-400 text-xs ml-1">(you)</span>}
                    {m.status !== 'approved' && <span className="text-white/30 text-xs ml-1">({m.status})</span>}
                  </td>
                  <td className="px-4 py-3 text-right text-white/80">{Number(m.meals || 0).toLocaleString()}</td>
                  <td className="px-4 py-3 text-right text-white/80">{fmt(m.deposits)}</td>
                  <td className="px-4 py-3 text-right text-white/60">{fmt(m.advance)}</td>
                  <td className="px-4 py-3 text-right text-white/80">{fmt(m.meal_cost)}</td>
                  <td className="px-4 py-3 text-right text-white/80">{fmt(m.fixed_share)}</td>
                  <td className="px-4 py-3 text-right text-white/80">{fmt(m.total_cost)}</td>
                  <td className={`px-4 py-3 text-right font-semibold ${Number(m.balance) < 0 ? 'text-red-400' : 'text-emerald-400'}`}>
                    {fmt(m.balance)}
                  </td>
                </tr>
              ))}
              {members.length === 0 && (
                <tr><td colSpan={8} className="px-4 py-8 text-center text-white/40">No members yet.</td></tr>
              )}
            </tbody>
          </table>
        </div>
      </div>
      <p className="text-white/30 text-xs">
        Balance = deposits − (meals × meal rate + fixed share). Negative (red) means the member owes money.
        Advance (জামানত) is held separately{Number(summary.total_advance) > 0 ? ` — mess is holding ৳${Number(summary.total_advance).toLocaleString()} in total` : ''}; it is returned when a member leaves or adjusted against their dues.
      </p>
    </div>
  );
}

import { ShoppingBasket, Utensils, Calculator, Wallet } from 'lucide-react';

const fmt = (n) => `৳${Number(n || 0).toLocaleString()}`;

export default function MonthSummary({ summary, currentUserId }) {
  if (!summary) return <div className="text-foreground/50 p-6">No summary yet.</div>;

  const members = summary.members || [];
  const me = members.find(m => m.user_id === currentUserId);
  // Carry column only appears once a previous month has been closed
  const hasCarry = members.some(m => Number(m.opening_balance || 0) !== 0);

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
          <div key={card.label} className="bg-card border border-foreground/10 rounded-2xl p-5">
            <div className="flex items-center gap-2 text-foreground/40 text-sm mb-2">
              <card.icon size={16} /> {card.label}
            </div>
            <p className={`text-xl font-bold ${card.color}`}>{card.value}</p>
          </div>
        ))}
      </div>

      {Number(summary.total_fixed) > 0 && (
        <div className="bg-card border border-foreground/10 rounded-2xl p-4 text-sm text-foreground/60">
          Fixed costs (utility / maid / other) this month:{' '}
          <span className="text-foreground font-medium">{fmt(summary.total_fixed)}</span>
          {' '}— split among active members. Total deposits:{' '}
          <span className="text-foreground font-medium">{fmt(summary.total_deposits)}</span>
        </div>
      )}

      <div className="bg-card border border-foreground/10 rounded-2xl overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-foreground/10 text-foreground/40 text-left">
                <th className="px-4 py-3 font-medium">Member</th>
                <th className="px-4 py-3 font-medium text-right">Meals</th>
                {hasCarry && <th className="px-4 py-3 font-medium text-right">Carry</th>}
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
                <tr key={m.member_id} className="border-b border-foreground/5 last:border-0">
                  <td className="px-4 py-3 text-foreground">
                    {m.display_name}
                    {m.user_id === currentUserId && <span className="text-cyan-400 text-xs ml-1">(you)</span>}
                    {m.status !== 'approved' && <span className="text-foreground/30 text-xs ml-1">({m.status})</span>}
                  </td>
                  <td className="px-4 py-3 text-right text-foreground/80">{Number(m.meals || 0).toLocaleString()}</td>
                  {hasCarry && (
                    <td className={`px-4 py-3 text-right ${Number(m.opening_balance) < 0 ? 'text-red-400/80' : 'text-foreground/60'}`}>
                      {fmt(m.opening_balance)}
                    </td>
                  )}
                  <td className="px-4 py-3 text-right text-foreground/80">{fmt(m.deposits)}</td>
                  <td className="px-4 py-3 text-right text-foreground/60">{fmt(m.advance)}</td>
                  <td className="px-4 py-3 text-right text-foreground/80">{fmt(m.meal_cost)}</td>
                  <td className="px-4 py-3 text-right text-foreground/80">{fmt(m.fixed_share)}</td>
                  <td className="px-4 py-3 text-right text-foreground/80">{fmt(m.total_cost)}</td>
                  <td className={`px-4 py-3 text-right font-semibold ${Number(m.balance) < 0 ? 'text-red-400' : 'text-emerald-400'}`}>
                    {fmt(m.balance)}
                  </td>
                </tr>
              ))}
              {members.length === 0 && (
                <tr><td colSpan={hasCarry ? 9 : 8} className="px-4 py-8 text-center text-foreground/40">No members yet.</td></tr>
              )}
            </tbody>
          </table>
        </div>
      </div>
      <p className="text-foreground/30 text-xs">
        Balance = {hasCarry ? 'carry + ' : ''}deposits − (meals × meal rate + fixed share). Negative (red) means the member owes money.
        {hasCarry && ' Carry is the balance carried forward from the previous closed month.'}
        Advance (জামানত) is held separately{Number(summary.total_advance) > 0 ? ` — mess is holding ৳${Number(summary.total_advance).toLocaleString()} in total` : ''}; it is returned when a member leaves or adjusted against their dues.
      </p>
    </div>
  );
}

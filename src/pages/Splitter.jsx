import { useState, useEffect, useCallback, useMemo } from 'react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../context/AuthContext';
import { useEntityTable } from '../hooks/useEntityTable';
import { Users, Plus, Trash2, ArrowRight, ReceiptText, ChevronLeft } from 'lucide-react';

const fmt = (n) => `৳${Math.round(Number(n || 0)).toLocaleString()}`;

// Greedy settlement: minimal-ish list of "X pays Y amount" from net balances.
function settle(balances) {
  const debtors = balances.filter(b => b.net < -0.01).map(b => ({ ...b, net: -b.net })).sort((a, b) => b.net - a.net);
  const creditors = balances.filter(b => b.net > 0.01).map(b => ({ ...b })).sort((a, b) => b.net - a.net);
  const moves = [];
  let i = 0, j = 0;
  while (i < debtors.length && j < creditors.length) {
    const pay = Math.min(debtors[i].net, creditors[j].net);
    moves.push({ from: debtors[i].name, to: creditors[j].name, amount: pay });
    debtors[i].net -= pay;
    creditors[j].net -= pay;
    if (debtors[i].net < 0.01) i++;
    if (creditors[j].net < 0.01) j++;
  }
  return moves;
}

export default function Splitter() {
  const { user } = useAuth();
  const { rows: events, loading, addRow: addEvent, updateRow: updateEvent, deleteRow: deleteEvent } = useEntityTable('split_events', { orderBy: 'event_date' });
  const [selected, setSelected] = useState(null);
  const [members, setMembers] = useState([]);
  const [expenses, setExpenses] = useState([]);
  const [eventName, setEventName] = useState('');
  const [memberName, setMemberName] = useState('');
  const [expForm, setExpForm] = useState({ description: '', amount: '', payer_member_id: '', participant_ids: [] });

  const fetchDetail = useCallback(async (eventId) => {
    const [memRes, expRes] = await Promise.all([
      supabase.from('split_members').select('*').eq('event_id', eventId).order('created_at'),
      supabase.from('split_expenses').select('*').eq('event_id', eventId).order('created_at', { ascending: false })
    ]);
    setMembers(memRes.data || []);
    setExpenses(expRes.data || []);
  }, []);

  useEffect(() => {
    if (selected) fetchDetail(selected.id);
    else { setMembers([]); setExpenses([]); }
  }, [selected, fetchDetail]);

  const balances = useMemo(() => {
    const map = new Map(members.map(m => [m.id, { id: m.id, name: m.name, paid: 0, share: 0 }]));
    for (const exp of expenses) {
      const payer = map.get(exp.payer_member_id);
      if (payer) payer.paid += Number(exp.amount);
      const sharers = (exp.participant_ids?.length ? exp.participant_ids : [...map.keys()]).filter(id => map.has(id));
      if (!sharers.length) continue;
      const each = Number(exp.amount) / sharers.length;
      for (const id of sharers) map.get(id).share += each;
    }
    return [...map.values()].map(b => ({ ...b, net: b.paid - b.share }));
  }, [members, expenses]);

  const settlements = useMemo(() => settle(balances), [balances]);
  const totalSpent = expenses.reduce((s, e) => s + Number(e.amount), 0);

  const handleAddEvent = async (e) => {
    e.preventDefault();
    if (!eventName.trim()) return;
    try {
      const ev = await addEvent({ name: eventName.trim() });
      setEventName('');
      setSelected(ev);
    } catch (err) { alert(err.message); }
  };

  const handleAddMember = async (e) => {
    e.preventDefault();
    if (!memberName.trim()) return;
    const { error } = await supabase.from('split_members').insert({
      user_id: user.id, event_id: selected.id, name: memberName.trim(), is_me: members.length === 0
    });
    if (error) return alert(error.message);
    setMemberName('');
    fetchDetail(selected.id);
  };

  const handleAddExpense = async (e) => {
    e.preventDefault();
    const { error } = await supabase.from('split_expenses').insert({
      user_id: user.id,
      event_id: selected.id,
      payer_member_id: expForm.payer_member_id,
      description: expForm.description.trim(),
      amount: parseFloat(expForm.amount),
      participant_ids: expForm.participant_ids.length ? expForm.participant_ids : null
    });
    if (error) return alert(error.message);
    setExpForm({ description: '', amount: '', payer_member_id: '', participant_ids: [] });
    fetchDetail(selected.id);
  };

  const removeRow = async (table, id) => {
    const { error } = await supabase.from(table).delete().eq('id', id).eq('user_id', user.id);
    if (error) return alert(error.message);
    fetchDetail(selected.id);
  };

  if (loading) return <div className="text-foreground/50 p-6">Loading splitter...</div>;

  // ---------- Event list view ----------
  if (!selected) {
    return (
      <div className="space-y-6 animate-in">
        <div>
          <h1 className="text-2xl font-bold text-foreground">Bill Splitter</h1>
          <p className="text-foreground/40 text-sm mt-1">Trips, dinners, picnics — split fairly, settle with the fewest payments.</p>
        </div>

        <form onSubmit={handleAddEvent} className="flex gap-3">
          <input
            type="text" value={eventName} onChange={e => setEventName(e.target.value)}
            placeholder="New event — e.g. Cox's Bazar Trip"
            className="flex-1 bg-muted border border-foreground/10 rounded-xl px-4 py-2.5 text-foreground focus:outline-none focus:border-pink-500/50"
          />
          <button type="submit" className="flex items-center gap-2 bg-pink-500 hover:bg-pink-600 text-white px-4 py-2 rounded-xl transition-colors shadow-lg shadow-pink-500/20">
            <Plus size={18} /> Create
          </button>
        </form>

        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
          {events.map(ev => (
            <button key={ev.id} onClick={() => setSelected(ev)} className={`text-left bg-card border rounded-2xl p-5 hover:border-pink-500/30 transition-all ${ev.is_settled ? 'border-emerald-500/20' : 'border-foreground/10'}`}>
              <div className="flex justify-between items-start">
                <h3 className="text-foreground font-medium">{ev.name}</h3>
                {ev.is_settled && <span className="px-2 py-0.5 rounded text-[10px] font-bold bg-emerald-500/20 text-emerald-400">SETTLED</span>}
              </div>
              <p className="text-foreground/40 text-xs mt-1">{new Date(ev.event_date).toLocaleDateString()}</p>
            </button>
          ))}
        </div>

        {events.length === 0 && (
          <div className="text-center py-12 border border-foreground/5 rounded-2xl bg-white/[0.02]">
            <Users className="mx-auto text-foreground/20 mb-4" size={48} />
            <h3 className="text-foreground/60 font-medium">No events yet</h3>
            <p className="text-foreground/40 text-sm mt-1">Create one, add friends, add who paid what — we'll compute who owes whom.</p>
          </div>
        )}
      </div>
    );
  }

  // ---------- Event detail view ----------
  return (
    <div className="space-y-6 animate-in">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div className="flex items-center gap-3">
          <button onClick={() => setSelected(null)} className="p-2 rounded-xl bg-foreground/5 hover:bg-foreground/10 text-foreground/60"><ChevronLeft size={18} /></button>
          <div>
            <h1 className="text-2xl font-bold text-foreground">{selected.name}</h1>
            <p className="text-foreground/40 text-sm">{members.length} people · {fmt(totalSpent)} total</p>
          </div>
        </div>
        <div className="flex gap-2">
          <button
            onClick={async () => { await updateEvent(selected.id, { is_settled: !selected.is_settled }); setSelected({ ...selected, is_settled: !selected.is_settled }); }}
            className={`px-3 py-2 rounded-xl text-sm font-medium border transition-all ${selected.is_settled ? 'bg-emerald-500/20 text-emerald-400 border-emerald-500/30' : 'bg-foreground/5 text-white/50 border-foreground/10 hover:bg-foreground/10'}`}
          >
            {selected.is_settled ? '✓ Settled' : 'Mark Settled'}
          </button>
          <button
            onClick={() => { if (confirm(`Delete event "${selected.name}" and all its expenses?`)) deleteEvent(selected.id).then(() => setSelected(null)).catch(err => alert(err.message)); }}
            className="p-2 rounded-xl bg-foreground/5 hover:bg-red-500/10 text-white/40 hover:text-red-400"
          >
            <Trash2 size={16} />
          </button>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Members + balances */}
        <div className="bg-card border border-foreground/10 rounded-2xl p-5">
          <h3 className="text-foreground font-semibold mb-3 flex items-center gap-2"><Users size={16} className="text-pink-400" /> People</h3>
          <form onSubmit={handleAddMember} className="flex gap-2 mb-4">
            <input type="text" value={memberName} onChange={e => setMemberName(e.target.value)} placeholder="Add person..." className="flex-1 min-w-0 bg-muted border border-foreground/10 rounded-xl px-3 py-2 text-foreground text-sm focus:outline-none focus:border-pink-500/50" />
            <button type="submit" className="bg-pink-500 hover:bg-pink-600 text-white px-3 rounded-xl"><Plus size={16} /></button>
          </form>
          <div className="space-y-2">
            {balances.map(b => (
              <div key={b.id} className="flex items-center justify-between bg-muted rounded-xl px-3 py-2.5">
                <div className="min-w-0">
                  <p className="text-sm text-foreground/80 truncate">{b.name}</p>
                  <p className="text-[11px] text-foreground/35">paid {fmt(b.paid)} · share {fmt(b.share)}</p>
                </div>
                <div className="flex items-center gap-2">
                  <span className={`text-xs font-semibold ${b.net > 0.01 ? 'text-emerald-400' : b.net < -0.01 ? 'text-red-400' : 'text-foreground/40'}`}>
                    {b.net > 0.01 ? `gets ${fmt(b.net)}` : b.net < -0.01 ? `owes ${fmt(-b.net)}` : 'even'}
                  </span>
                  <button onClick={() => { if (confirm(`Remove ${b.name}? Their paid expenses will also be removed.`)) removeRow('split_members', b.id); }} className="text-foreground/25 hover:text-red-400 p-1">
                    <Trash2 size={13} />
                  </button>
                </div>
              </div>
            ))}
            {members.length === 0 && <p className="text-xs text-foreground/30">Add the people first (including yourself).</p>}
          </div>
        </div>

        {/* Add + list expenses */}
        <div className="bg-card border border-foreground/10 rounded-2xl p-5">
          <h3 className="text-foreground font-semibold mb-3 flex items-center gap-2"><ReceiptText size={16} className="text-pink-400" /> Expenses</h3>
          {members.length > 0 && (
            <form onSubmit={handleAddExpense} className="space-y-2.5 mb-4 pb-4 border-b border-foreground/5">
              <input required type="text" value={expForm.description} onChange={e => setExpForm({ ...expForm, description: e.target.value })} placeholder="What for? e.g. Hotel" className="w-full bg-muted border border-foreground/10 rounded-xl px-3 py-2 text-foreground text-sm focus:outline-none focus:border-pink-500/50" />
              <div className="flex gap-2">
                <input required type="number" step="0.01" min="0.01" value={expForm.amount} onChange={e => setExpForm({ ...expForm, amount: e.target.value })} placeholder="Amount" className="w-28 bg-muted border border-foreground/10 rounded-xl px-3 py-2 text-foreground text-sm focus:outline-none focus:border-pink-500/50" />
                <select required value={expForm.payer_member_id} onChange={e => setExpForm({ ...expForm, payer_member_id: e.target.value })} className="flex-1 min-w-0 bg-muted border border-foreground/10 rounded-xl px-3 py-2 text-foreground text-sm focus:outline-none focus:border-pink-500/50">
                  <option value="">Paid by...</option>
                  {members.map(m => <option key={m.id} value={m.id}>{m.name}</option>)}
                </select>
              </div>
              <div>
                <p className="text-[11px] text-foreground/35 mb-1.5">Split between (none selected = everyone):</p>
                <div className="flex flex-wrap gap-1.5">
                  {members.map(m => {
                    const on = expForm.participant_ids.includes(m.id);
                    return (
                      <button
                        key={m.id} type="button"
                        onClick={() => setExpForm({ ...expForm, participant_ids: on ? expForm.participant_ids.filter(id => id !== m.id) : [...expForm.participant_ids, m.id] })}
                        className={`px-2.5 py-1 rounded-lg text-[11px] font-medium border transition-all ${on ? 'bg-pink-500/20 text-pink-400 border-pink-500/40' : 'bg-foreground/5 text-white/40 border-foreground/10'}`}
                      >
                        {m.name}
                      </button>
                    );
                  })}
                </div>
              </div>
              <button type="submit" className="w-full bg-pink-500 hover:bg-pink-600 text-white py-2 rounded-xl text-sm font-medium">Add Expense</button>
            </form>
          )}
          <div className="space-y-1.5 max-h-72 overflow-y-auto">
            {expenses.map(exp => {
              const payer = members.find(m => m.id === exp.payer_member_id);
              return (
                <div key={exp.id} className="flex items-center justify-between text-xs bg-muted rounded-lg px-3 py-2">
                  <div className="min-w-0">
                    <p className="text-foreground/70 truncate">{exp.description}</p>
                    <p className="text-foreground/30">{payer?.name || '?'} paid{exp.participant_ids?.length ? ` · ${exp.participant_ids.length} people` : ' · everyone'}</p>
                  </div>
                  <div className="flex items-center gap-2 shrink-0">
                    <span className="text-foreground font-medium">{fmt(exp.amount)}</span>
                    <button onClick={() => removeRow('split_expenses', exp.id)} className="text-foreground/25 hover:text-red-400 p-0.5"><Trash2 size={12} /></button>
                  </div>
                </div>
              );
            })}
            {expenses.length === 0 && <p className="text-xs text-foreground/30">No expenses yet.</p>}
          </div>
        </div>

        {/* Settlement */}
        <div className="bg-card border border-foreground/10 rounded-2xl p-5">
          <h3 className="text-foreground font-semibold mb-3">Settle Up</h3>
          {settlements.length > 0 ? (
            <div className="space-y-2">
              {settlements.map((s, i) => (
                <div key={i} className="flex items-center gap-2 bg-muted rounded-xl px-3 py-3 text-sm">
                  <span className="text-red-400 font-medium">{s.from}</span>
                  <ArrowRight size={14} className="text-foreground/30 shrink-0" />
                  <span className="text-emerald-400 font-medium">{s.to}</span>
                  <span className="ml-auto text-foreground font-semibold">{fmt(s.amount)}</span>
                </div>
              ))}
              <p className="text-[11px] text-foreground/30 mt-2">{settlements.length} payment{settlements.length > 1 ? 's' : ''} settles everything.</p>
            </div>
          ) : (
            <p className="text-xs text-foreground/30">{expenses.length ? 'All even — nothing to settle 🎉' : 'Add expenses to see who owes whom.'}</p>
          )}
        </div>
      </div>
    </div>
  );
}

import { useState, useMemo } from 'react';
import { useLending } from '../hooks/useLending';
import { useAccounts } from '../context/AccountContext';
import StatCard from '../components/StatCard';
import {
  HandCoins, Plus, Phone, Trash2, ChevronDown, ChevronUp,
  ArrowUpRight, ArrowDownLeft, CalendarClock
} from 'lucide-react';

const today = () => new Date().toISOString().split('T')[0];
const fmt = (n) => `৳${Number(n || 0).toLocaleString()}`;

export default function Lending() {
  const { people, totals, loading, addLoan, settleLoan, deleteLoan } = useLending();
  const { accounts, fetchAccounts } = useAccounts();
  const [isAdding, setIsAdding] = useState(false);
  const [showSettled, setShowSettled] = useState(false);
  const [expandedPerson, setExpandedPerson] = useState(null);
  const [submitting, setSubmitting] = useState(false);

  const initialForm = {
    direction: 'given',
    person: '',
    phone: '',
    amount: '',
    movement: 'account', // 'account' | 'opening'
    account_id: '',
    due_date: '',
    notes: ''
  };
  const [form, setForm] = useState(initialForm);

  // Settle modal state
  const [settlingLoan, setSettlingLoan] = useState(null);
  const [settleForm, setSettleForm] = useState({ account_id: '', amount: '', date: today(), notes: '' });

  const personNames = useMemo(() => people.map(p => p.name), [people]);

  const openAdd = (prefill = {}) => {
    setForm({ ...initialForm, ...prefill });
    setIsAdding(true);
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setSubmitting(true);
    try {
      await addLoan({
        direction: form.direction,
        person: form.person.trim(),
        phone: form.phone.trim(),
        amount: parseFloat(form.amount),
        account_id: form.movement === 'account' ? form.account_id : null,
        due_date: form.due_date || null,
        notes: form.notes
      });
      if (form.movement === 'account') await fetchAccounts();
      setIsAdding(false);
      setForm(initialForm);
    } catch (err) {
      console.error(err);
      alert('Error saving loan: ' + (err.message || JSON.stringify(err)));
    }
    setSubmitting(false);
  };

  const handleSettle = async (e) => {
    e.preventDefault();
    setSubmitting(true);
    try {
      await settleLoan(
        settlingLoan.id,
        settleForm.account_id,
        parseFloat(settleForm.amount),
        settleForm.date,
        settleForm.notes
      );
      await fetchAccounts();
      setSettlingLoan(null);
      setSettleForm({ account_id: '', amount: '', date: today(), notes: '' });
    } catch (err) {
      console.error(err);
      alert('Error recording payment: ' + (err.message || JSON.stringify(err)));
    }
    setSubmitting(false);
  };

  const visiblePeople = people.filter(p => showSettled || p.receivable > 0 || p.payable > 0);

  if (loading) return <div className="text-white/50 p-6">Loading dena-paona...</div>;

  return (
    <div className="space-y-6 animate-in">
      <div className="flex justify-between items-center">
        <div>
          <h1 className="text-2xl font-bold text-white">Dena-Paona</h1>
          <p className="text-white/40 text-sm mt-1">Personal lending ledger — who owes you, whom you owe.</p>
        </div>
        <div className="flex items-center gap-3">
          <button
            onClick={() => setShowSettled(v => !v)}
            className={`px-3 py-2 rounded-xl text-sm font-medium transition-all border ${
              showSettled ? 'bg-white/10 text-white border-white/20' : 'bg-white/5 text-white/40 border-white/10 hover:bg-white/10 hover:text-white'
            }`}
          >
            {showSettled ? 'Hide Settled' : 'Show Settled'}
          </button>
          <button
            onClick={() => openAdd()}
            className="flex items-center gap-2 bg-cyan-500 hover:bg-cyan-600 text-white px-4 py-2 rounded-xl transition-colors shadow-lg shadow-cyan-500/20"
          >
            <Plus size={18} /> Add Loan
          </button>
        </div>
      </div>

      <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
        <StatCard title="Paona (You'll receive)" value={fmt(totals.receivable)} icon={ArrowDownLeft} gradient={["#34d399", "#10b981"]} iconBg="bg-emerald-500/10" />
        <StatCard title="Dena (You owe)" value={fmt(totals.payable)} icon={ArrowUpRight} gradient={["#f87171", "#ef4444"]} iconBg="bg-red-500/10" />
        <StatCard title="Net Position" value={`${totals.net >= 0 ? '+' : '−'}${fmt(Math.abs(totals.net))}`} icon={HandCoins} gradient={totals.net >= 0 ? ["#22d3ee", "#06b6d4"] : ["#f87171", "#ef4444"]} iconBg="bg-cyan-500/10" />
      </div>

      {isAdding && (
        <div className="bg-[#1a1a2e] border border-white/10 rounded-2xl p-6">
          <h2 className="text-lg font-semibold text-white mb-4">New Loan Entry</h2>
          <form onSubmit={handleSubmit} className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div className="sm:col-span-2 flex gap-2">
              {[
                { id: 'given', label: 'Ami Dilam (I lent)', icon: '↗️', color: 'emerald' },
                { id: 'taken', label: 'Ami Nilam (I borrowed)', icon: '↘️', color: 'red' }
              ].map(d => (
                <button
                  key={d.id}
                  type="button"
                  onClick={() => setForm({ ...form, direction: d.id })}
                  className={`flex-1 flex flex-col items-center justify-center py-2.5 px-2 rounded-xl text-xs sm:text-sm font-medium transition-all ${
                    form.direction === d.id
                      ? d.id === 'given'
                        ? 'bg-emerald-500/20 text-emerald-400 border border-emerald-500/30'
                        : 'bg-red-500/20 text-red-400 border border-red-500/30'
                      : 'bg-white/5 text-white/40 border border-white/10 hover:bg-white/10'
                  }`}
                >
                  <span className="text-lg mb-0.5">{d.icon}</span>
                  <span>{d.label}</span>
                </button>
              ))}
            </div>

            <div>
              <label className="block text-sm text-white/60 mb-1">Person Name</label>
              <input
                required type="text" list="lending-people" value={form.person}
                onChange={e => setForm({ ...form, person: e.target.value })}
                className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-cyan-500/50"
                placeholder="e.g. Rahim Bhai"
              />
              <datalist id="lending-people">
                {personNames.map(n => <option key={n} value={n} />)}
              </datalist>
            </div>
            <div>
              <label className="block text-sm text-white/60 mb-1">Phone (Optional)</label>
              <input
                type="tel" value={form.phone}
                onChange={e => setForm({ ...form, phone: e.target.value })}
                className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-cyan-500/50"
                placeholder="01XXXXXXXXX"
              />
            </div>
            <div>
              <label className="block text-sm text-white/60 mb-1">Amount</label>
              <input
                required type="number" step="0.01" min="0.01" value={form.amount}
                onChange={e => setForm({ ...form, amount: e.target.value })}
                className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-cyan-500/50"
                placeholder="0.00"
              />
            </div>
            <div>
              <label className="block text-sm text-white/60 mb-1">Return Date (Optional)</label>
              <input
                type="date" value={form.due_date}
                onChange={e => setForm({ ...form, due_date: e.target.value })}
                className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-cyan-500/50"
              />
            </div>

            <div className="sm:col-span-2">
              <label className="block text-sm text-white/60 mb-2">Money movement</label>
              <div className="grid grid-cols-2 gap-2 mb-3">
                {[
                  { id: 'account', label: form.direction === 'given' ? '💵 Paid from account' : '💵 Received into account' },
                  { id: 'opening', label: '🕰️ Past / Opening balance' }
                ].map(opt => (
                  <button
                    key={opt.id}
                    type="button"
                    onClick={() => setForm({ ...form, movement: opt.id })}
                    className={`py-2 px-2 rounded-xl text-xs sm:text-sm font-medium transition-all border ${
                      form.movement === opt.id
                        ? 'bg-cyan-500/20 text-cyan-400 border-cyan-500/50'
                        : 'bg-white/5 text-white/40 border-white/10 hover:bg-white/10'
                    }`}
                  >
                    {opt.label}
                  </button>
                ))}
              </div>
              {form.movement === 'account' ? (
                <div className="animate-in fade-in slide-in-from-top-2">
                  <label className="block text-sm text-white/60 mb-1">
                    {form.direction === 'given' ? 'Pay From Account' : 'Deposit To Account'}
                  </label>
                  <select
                    required value={form.account_id}
                    onChange={e => setForm({ ...form, account_id: e.target.value })}
                    className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-cyan-500/50"
                  >
                    <option value="">Select an account...</option>
                    {accounts.map(a => <option key={a.id} value={a.id}>{a.name} ({a.currency}{a.current_balance})</option>)}
                  </select>
                  <p className="text-xs text-white/40 mt-1">
                    {form.direction === 'given'
                      ? 'The amount will be deducted from this account.'
                      : 'The amount will be added to this account.'}
                  </p>
                </div>
              ) : (
                <p className="text-xs text-white/40 animate-in fade-in slide-in-from-top-2">
                  Ledger entry only — no account balance will change. Use this for dena-paona from before you started using the app.
                </p>
              )}
            </div>

            <div className="sm:col-span-2">
              <label className="block text-sm text-white/60 mb-1">Notes</label>
              <textarea
                value={form.notes} rows={2}
                onChange={e => setForm({ ...form, notes: e.target.value })}
                className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-cyan-500/50"
                placeholder="e.g. for house rent, will return after Eid"
              />
            </div>
            <div className="sm:col-span-2 flex justify-end gap-3 mt-2">
              <button type="button" onClick={() => setIsAdding(false)} className="px-5 py-2.5 rounded-xl text-white/60 hover:text-white hover:bg-white/5 transition-colors">Cancel</button>
              <button type="submit" disabled={submitting} className="bg-cyan-500 hover:bg-cyan-600 disabled:opacity-50 text-white px-6 py-2.5 rounded-xl shadow-lg shadow-cyan-500/20 transition-all font-medium">
                {submitting ? 'Saving...' : 'Save Loan'}
              </button>
            </div>
          </form>
        </div>
      )}

      {/* Settle modal */}
      {settlingLoan && (
        <div className="fixed inset-0 bg-black/60 backdrop-blur-sm z-50 flex items-center justify-center p-4">
          <div className="bg-[#1a1a2e] border border-white/10 rounded-2xl p-6 w-full max-w-md shadow-2xl max-h-[90vh] overflow-y-auto">
            <h2 className="text-xl font-semibold text-white mb-2">
              {settlingLoan.type === 'loan_given' ? 'Receive Money' : 'Repay Money'}
            </h2>
            <p className="text-sm text-white/50 mb-6">
              {settlingLoan.type === 'loan_given' ? 'From' : 'To'}: <strong className="text-white">{settlingLoan.counterparty || settlingLoan.name}</strong>
              <span className="ml-2 text-white/40">(remaining {fmt(settlingLoan.remaining_balance)})</span>
            </p>
            <form onSubmit={handleSettle} className="space-y-4">
              <div>
                <label className="block text-sm text-white/60 mb-1">
                  {settlingLoan.type === 'loan_given' ? 'Deposit To Account' : 'Pay From Account'}
                </label>
                <select
                  required value={settleForm.account_id}
                  onChange={e => setSettleForm({ ...settleForm, account_id: e.target.value })}
                  className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-emerald-500/50"
                >
                  <option value="">Select an account...</option>
                  {accounts.map(a => <option key={a.id} value={a.id}>{a.name} ({a.currency}{a.current_balance})</option>)}
                </select>
              </div>
              <div>
                <label className="block text-sm text-white/60 mb-1">Amount</label>
                <input
                  required type="number" step="0.01" min="0.01" max={settlingLoan.remaining_balance}
                  value={settleForm.amount}
                  onChange={e => setSettleForm({ ...settleForm, amount: e.target.value })}
                  className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-emerald-500/50"
                  placeholder="0.00"
                />
              </div>
              <div>
                <label className="block text-sm text-white/60 mb-1">Date</label>
                <input
                  required type="date" value={settleForm.date}
                  onChange={e => setSettleForm({ ...settleForm, date: e.target.value })}
                  className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-emerald-500/50"
                />
              </div>
              <div>
                <label className="block text-sm text-white/60 mb-1">Notes</label>
                <input
                  type="text" value={settleForm.notes}
                  onChange={e => setSettleForm({ ...settleForm, notes: e.target.value })}
                  className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-emerald-500/50"
                />
              </div>
              <div className="flex justify-end gap-3 mt-6">
                <button type="button" onClick={() => setSettlingLoan(null)} className="px-5 py-2.5 rounded-xl text-white/60 hover:text-white hover:bg-white/5 transition-colors">Cancel</button>
                <button type="submit" disabled={submitting} className="bg-emerald-500 hover:bg-emerald-600 disabled:opacity-50 text-white px-6 py-2.5 rounded-xl shadow-lg shadow-emerald-500/20 transition-all font-medium">
                  {submitting ? 'Processing...' : 'Confirm'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Person ledger cards */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
        {visiblePeople.map(person => {
          const isExpanded = expandedPerson === person.key;
          const activeLoans = person.loans.filter(l => l.remaining_balance > 0);
          const settledLoans = person.loans.filter(l => l.remaining_balance <= 0);
          const shownLoans = showSettled ? person.loans : activeLoans;
          return (
            <div key={person.key} className="bg-[#1a1a2e] border border-white/10 rounded-2xl p-5 hover:border-white/20 transition-all">
              <div className="flex justify-between items-start mb-4">
                <div className="flex items-center gap-3">
                  <div className="w-12 h-12 rounded-full bg-gradient-to-br from-cyan-500/30 to-purple-600/30 flex items-center justify-center text-white font-bold text-lg">
                    {person.name[0]?.toUpperCase()}
                  </div>
                  <div>
                    <h3 className="text-white font-medium">{person.name}</h3>
                    {person.phone && (
                      <a href={`tel:${person.phone}`} className="flex items-center gap-1 text-xs text-cyan-400/80 hover:text-cyan-400 mt-0.5">
                        <Phone size={11} /> {person.phone}
                      </a>
                    )}
                  </div>
                </div>
                <div className="text-right">
                  {person.net !== 0 ? (
                    <>
                      <p className={`font-semibold ${person.net > 0 ? 'text-emerald-400' : 'text-red-400'}`}>
                        {fmt(Math.abs(person.net))}
                      </p>
                      <p className="text-xs text-white/40">{person.net > 0 ? 'you will receive' : 'you owe'}</p>
                    </>
                  ) : (
                    <span className="px-2 py-0.5 rounded text-[10px] font-bold bg-emerald-500/20 text-emerald-400 border border-emerald-500/30">✓ SETTLED</span>
                  )}
                </div>
              </div>

              <div className="space-y-2">
                {shownLoans.map(loan => {
                  const isPaid = loan.remaining_balance <= 0;
                  const isGiven = loan.type === 'loan_given';
                  const overdue = !isPaid && loan.due_date && loan.due_date < today();
                  return (
                    <div key={loan.id} className={`flex items-center gap-3 rounded-xl px-3 py-2.5 border ${isPaid ? 'bg-emerald-500/5 border-emerald-500/10' : 'bg-[#12122a] border-white/5'}`}>
                      {isGiven
                        ? <ArrowUpRight size={16} className="text-emerald-400 shrink-0" />
                        : <ArrowDownLeft size={16} className="text-red-400 shrink-0" />}
                      <div className="flex-1 min-w-0">
                        <p className="text-sm text-white/80">
                          {isGiven ? 'Gave' : 'Took'} {fmt(loan.principal)}
                          {!isPaid && Number(loan.remaining_balance) !== Number(loan.principal) && (
                            <span className="text-white/40"> · {fmt(loan.remaining_balance)} left</span>
                          )}
                        </p>
                        <p className="text-xs text-white/35 truncate">
                          {new Date(loan.created_at).toLocaleDateString()}
                          {loan.due_date && (
                            <span className={overdue ? 'text-red-400 font-medium' : ''}>
                              {' '}· <CalendarClock size={10} className="inline -mt-0.5" /> return {new Date(loan.due_date).toLocaleDateString()}{overdue ? ' (overdue!)' : ''}
                            </span>
                          )}
                          {loan.notes && ` · ${loan.notes}`}
                        </p>
                      </div>
                      {isPaid ? (
                        <span className="text-[10px] font-bold text-emerald-400">PAID</span>
                      ) : (
                        <button
                          onClick={() => {
                            setSettlingLoan(loan);
                            setSettleForm({ account_id: '', amount: loan.remaining_balance, date: today(), notes: '' });
                          }}
                          className={`text-xs px-3 py-1.5 rounded-lg font-medium text-white transition-all ${isGiven ? 'bg-emerald-500 hover:bg-emerald-600' : 'bg-red-500 hover:bg-red-600'}`}
                        >
                          {isGiven ? 'Receive' : 'Repay'}
                        </button>
                      )}
                      <button
                        onClick={() => {
                          if (confirm(`Delete this loan of ${fmt(loan.principal)}? Its repayment history will also be removed. Account balances will NOT be reversed.`))
                            deleteLoan(loan.id).catch(err => alert('Cannot delete: ' + err.message));
                        }}
                        className="text-white/30 hover:text-red-400 p-1 rounded-lg hover:bg-red-500/10"
                      >
                        <Trash2 size={14} />
                      </button>
                    </div>
                  );
                })}
                {!showSettled && settledLoans.length > 0 && (
                  <p className="text-xs text-white/30 px-1">+ {settledLoans.length} settled loan{settledLoans.length > 1 ? 's' : ''} hidden</p>
                )}
              </div>

              <div className="flex items-center justify-between mt-4 pt-3 border-t border-white/5">
                <button
                  onClick={() => openAdd({ person: person.name, phone: person.phone || '' })}
                  className="text-xs text-cyan-400/80 hover:text-cyan-400 font-medium flex items-center gap-1"
                >
                  <Plus size={13} /> New loan with {person.name.split(' ')[0]}
                </button>
                {person.repayments.length > 0 && (
                  <button
                    onClick={() => setExpandedPerson(isExpanded ? null : person.key)}
                    className="text-xs text-white/40 hover:text-white flex items-center gap-1"
                  >
                    History ({person.repayments.length}) {isExpanded ? <ChevronUp size={13} /> : <ChevronDown size={13} />}
                  </button>
                )}
              </div>

              {isExpanded && (
                <div className="mt-3 space-y-1.5 animate-in fade-in slide-in-from-top-2">
                  {person.repayments.map(rep => (
                    <div key={rep.id} className="flex items-center justify-between text-xs bg-[#12122a] rounded-lg px-3 py-2">
                      <span className="text-white/50">
                        {new Date(rep.date).toLocaleDateString()} · {rep.loan_type === 'loan_given' ? 'received' : 'paid'} via {rep.accounts?.name || 'account'}
                        {rep.notes && <span className="text-white/30"> · {rep.notes}</span>}
                      </span>
                      <span className={rep.loan_type === 'loan_given' ? 'text-emerald-400 font-medium' : 'text-red-400 font-medium'}>
                        {fmt(rep.amount)}
                      </span>
                    </div>
                  ))}
                </div>
              )}
            </div>
          );
        })}
      </div>

      {visiblePeople.length === 0 && !isAdding && (
        <div className="text-center py-12 border border-white/5 rounded-2xl bg-white/[0.02]">
          <HandCoins className="mx-auto text-white/20 mb-4" size={48} />
          <h3 className="text-white/60 font-medium">No dena-paona recorded</h3>
          <p className="text-white/40 text-sm mt-1">Track money you lent to or borrowed from people — with due dates and full history.</p>
        </div>
      )}
    </div>
  );
}

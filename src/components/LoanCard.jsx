import { Pencil, Trash2, ArrowUpRight, ArrowDownLeft } from 'lucide-react';

export default function LoanCard({ loan, onEdit, onDelete }) {
  const percentage = loan.amount > 0 ? Math.min((loan.paid_amount / loan.amount) * 100, 100) : 0;
  const isGiven = loan.type === 'given';
  const statusColors = {
    active: 'bg-amber-500/10 text-amber-400 border-amber-500/20',
    partially_paid: 'bg-blue-500/10 text-blue-400 border-blue-500/20',
    paid: 'bg-emerald-500/10 text-emerald-400 border-emerald-500/20'
  };

  return (
    <div className="p-5 rounded-2xl bg-white/5 backdrop-blur-xl border border-white/10 hover:border-white/15 transition-all group">
      <div className="flex items-start justify-between mb-3">
        <div className="flex items-center gap-3">
          <div className={`w-10 h-10 rounded-xl flex items-center justify-center ${
            isGiven ? 'bg-orange-500/10' : 'bg-blue-500/10'
          }`}>
            {isGiven ? <ArrowUpRight className="w-5 h-5 text-orange-400" /> : <ArrowDownLeft className="w-5 h-5 text-blue-400" />}
          </div>
          <div>
            <p className="text-sm font-medium text-white">{loan.person_name}</p>
            <p className="text-xs text-white/30">{isGiven ? 'Loan Given' : 'Loan Taken'}</p>
          </div>
        </div>
        <span className={`text-xs px-2.5 py-1 rounded-full border ${statusColors[loan.status]}`}>
          {loan.status.replace('_', ' ')}
        </span>
      </div>

      <div className="mb-3">
        <p className="text-lg font-bold text-white">৳{loan.amount?.toLocaleString()}</p>
        <p className="text-xs text-white/30 mt-0.5">
          Paid: ৳{loan.paid_amount?.toLocaleString() || 0} • Due: {loan.due_date ? new Date(loan.due_date).toLocaleDateString() : 'N/A'}
        </p>
      </div>

      {loan.status !== 'paid' && (
        <div className="w-full h-1.5 bg-white/5 rounded-full overflow-hidden mb-3">
          <div
            className="h-full rounded-full bg-gradient-to-r from-cyan-500 to-purple-500 transition-all duration-500"
            style={{ width: `${percentage}%` }}
          />
        </div>
      )}

      {loan.notes && <p className="text-xs text-white/20 mb-3 italic">{loan.notes}</p>}

      <div className="flex gap-1 justify-end opacity-0 group-hover:opacity-100 transition-opacity">
        <button onClick={() => onEdit(loan)} className="p-2 rounded-lg text-white/30 hover:text-cyan-400 hover:bg-cyan-500/10 transition-all">
          <Pencil className="w-4 h-4" />
        </button>
        <button onClick={() => onDelete(loan.id)} className="p-2 rounded-lg text-white/30 hover:text-red-400 hover:bg-red-500/10 transition-all">
          <Trash2 className="w-4 h-4" />
        </button>
      </div>
    </div>
  );
}

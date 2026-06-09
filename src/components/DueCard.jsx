import { Pencil, Trash2, CheckCircle2, AlertCircle, Clock } from 'lucide-react';

export default function DueCard({ due, onEdit, onDelete, onMarkPaid }) {
  const isOverdue = new Date(due.due_date) < new Date() && due.status !== 'paid';
  const statusConfig = {
    pending: { icon: Clock, color: 'text-amber-400', bg: 'bg-amber-500/10', border: 'border-amber-500/20' },
    overdue: { icon: AlertCircle, color: 'text-red-400', bg: 'bg-red-500/10', border: 'border-red-500/20' },
    paid: { icon: CheckCircle2, color: 'text-emerald-400', bg: 'bg-emerald-500/10', border: 'border-emerald-500/20' },
  };
  const actualStatus = isOverdue ? 'overdue' : due.status;
  const config = statusConfig[actualStatus] || statusConfig.pending;
  const StatusIcon = config.icon;

  const daysUntil = Math.ceil((new Date(due.due_date) - new Date()) / (1000 * 60 * 60 * 24));

  return (
    <div className={`p-5 rounded-2xl bg-white/5 backdrop-blur-xl border transition-all group ${
      isOverdue ? 'border-red-500/20 hover:border-red-500/30' : 'border-white/10 hover:border-white/15'
    }`}>
      <div className="flex items-start justify-between mb-2">
        <div>
          <p className="text-sm font-medium text-white">{due.title}</p>
          <p className="text-xs text-white/30 mt-0.5">
            {due.category || 'General'} {due.is_recurring && `• 🔄 ${due.recurrence_period}`}
          </p>
        </div>
        <span className={`flex items-center gap-1 text-xs px-2.5 py-1 rounded-full border ${config.bg} ${config.color} ${config.border}`}>
          <StatusIcon className="w-3 h-3" />
          {actualStatus}
        </span>
      </div>

      <div className="flex items-end justify-between mt-3">
        <div>
          <p className="text-lg font-bold text-white">৳{due.amount?.toLocaleString()}</p>
          <p className="text-xs text-white/30 mt-0.5">
            Due: {new Date(due.due_date).toLocaleDateString()} 
            {due.status !== 'paid' && (
              <span className={daysUntil < 0 ? 'text-red-400' : daysUntil <= 3 ? 'text-amber-400' : 'text-white/30'}>
                {' '}({daysUntil < 0 ? `${Math.abs(daysUntil)} days overdue` : daysUntil === 0 ? 'Due today!' : `${daysUntil} days left`})
              </span>
            )}
          </p>
        </div>

        <div className="flex gap-1 opacity-0 group-hover:opacity-100 transition-opacity">
          {due.status !== 'paid' && (
            <button onClick={() => onMarkPaid(due.id)} className="p-2 rounded-lg text-white/30 hover:text-emerald-400 hover:bg-emerald-500/10 transition-all" title="Mark as paid">
              <CheckCircle2 className="w-4 h-4" />
            </button>
          )}
          <button onClick={() => onEdit(due)} className="p-2 rounded-lg text-white/30 hover:text-cyan-400 hover:bg-cyan-500/10 transition-all">
            <Pencil className="w-4 h-4" />
          </button>
          <button onClick={() => onDelete(due.id)} className="p-2 rounded-lg text-white/30 hover:text-red-400 hover:bg-red-500/10 transition-all">
            <Trash2 className="w-4 h-4" />
          </button>
        </div>
      </div>
    </div>
  );
}

import { Pencil, Trash2 } from 'lucide-react';

export default function TransactionList({ transactions, onEdit, onDelete, showActions = true }) {
  if (transactions.length === 0) {
    return (
      <div className="text-center py-12 text-white/30">
        <p className="text-4xl mb-3">📭</p>
        <p className="text-sm">No transactions yet</p>
      </div>
    );
  }

  return (
    <div className="space-y-2">
      {transactions.map(t => (
        <div
          key={t.id}
          className="flex items-center gap-3 p-3 sm:p-4 rounded-xl bg-white/[0.02] hover:bg-white/5 border border-white/5 hover:border-white/10 transition-all group"
        >
          <div
            className="w-10 h-10 rounded-xl flex items-center justify-center text-lg shrink-0"
            style={{ backgroundColor: (t.categories?.color || '#6366f1') + '15' }}
          >
            {t.categories?.icon || '💰'}
          </div>
          <div className="flex-1 min-w-0">
            <p className="text-sm text-white font-medium truncate">
              {t.description || t.categories?.name || 'Transaction'}
            </p>
            <p className="text-xs text-white/30 mt-0.5 truncate">
              {t.categories?.name} • {new Date(t.date).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })}
            </p>
          </div>
          <div className="text-right shrink-0">
            <p className={`text-sm font-bold ${
              t.type === 'income' ? 'text-emerald-400' : 'text-red-400'
            }`}>
              {t.type === 'income' ? '+' : '-'}৳{t.amount?.toLocaleString()}
            </p>
          </div>
          {showActions && (
            <div className="flex gap-0.5 shrink-0 sm:gap-1 opacity-100 sm:opacity-0 sm:group-hover:opacity-100 transition-opacity">
              <button
                onClick={() => onEdit(t)}
                className="p-2 rounded-lg text-white/30 hover:text-cyan-400 hover:bg-cyan-500/10 transition-all"
              >
                <Pencil className="w-4 h-4" />
              </button>
              <button
                onClick={() => onDelete(t.id)}
                className="p-2 rounded-lg text-white/30 hover:text-red-400 hover:bg-red-500/10 transition-all"
              >
                <Trash2 className="w-4 h-4" />
              </button>
            </div>
          )}
        </div>
      ))}
    </div>
  );
}

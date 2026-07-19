import { Plus, X } from 'lucide-react';

// Itemized "ki ki kinlam" list editor: rows of {name, amount}.
// `items` is an array; amount is optional per item (name-only rows are fine).
export default function ItemListEditor({ items, onChange }) {
  const rows = items.length > 0 ? items : [];

  const update = (i, patch) => {
    const next = rows.map((it, idx) => (idx === i ? { ...it, ...patch } : it));
    onChange(next);
  };

  const addRow = () => onChange([...rows, { name: '', amount: '' }]);
  const removeRow = (i) => onChange(rows.filter((_, idx) => idx !== i));

  const itemsTotal = rows.reduce((s, it) => s + (Number(it.amount) || 0), 0);

  return (
    <div className="space-y-2">
      {rows.map((it, i) => (
        <div key={i} className="flex gap-2 items-center">
          <input
            type="text"
            value={it.name}
            onChange={e => update(i, { name: e.target.value })}
            placeholder={`Item ${i + 1}, e.g. Rice 5kg`}
            className="flex-1 bg-muted border border-foreground/10 rounded-xl px-3 py-2 text-foreground text-sm focus:outline-none focus:border-cyan-500/50"
          />
          <input
            type="number"
            min="0"
            step="0.01"
            value={it.amount}
            onChange={e => update(i, { amount: e.target.value })}
            placeholder="৳"
            className="w-24 bg-muted border border-foreground/10 rounded-xl px-3 py-2 text-foreground text-sm text-right focus:outline-none focus:border-cyan-500/50"
          />
          <button
            type="button"
            onClick={() => removeRow(i)}
            className="p-2 rounded-lg text-white/40 hover:text-red-400 hover:bg-red-500/10"
          >
            <X size={14} />
          </button>
        </div>
      ))}
      <div className="flex items-center justify-between">
        <button
          type="button"
          onClick={addRow}
          className="flex items-center gap-1.5 text-xs px-3 py-1.5 rounded-lg bg-foreground/5 border border-foreground/10 text-foreground/60 hover:text-cyan-400"
        >
          <Plus size={13} /> Add item
        </button>
        {itemsTotal > 0 && (
          <span className="text-foreground/40 text-xs">Items total: ৳{itemsTotal.toLocaleString()}</span>
        )}
      </div>
    </div>
  );
}

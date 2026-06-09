import { Pencil, Trash2, Bike, Monitor, Smartphone, Car, Package } from 'lucide-react';

const TYPE_ICONS = {
  Vehicle: Car,
  Bike: Bike,
  Electronics: Monitor,
  Mobile: Smartphone,
  Other: Package
};

export default function AssetCard({ asset, totalExpense, onEdit, onDelete }) {
  const Icon = TYPE_ICONS[asset.type] || Package;

  return (
    <div className="p-5 rounded-2xl bg-white/5 backdrop-blur-xl border border-white/10 hover:border-white/15 transition-all group">
      <div className="flex items-start justify-between mb-4">
        <div className="flex items-center gap-3">
          <div className="w-12 h-12 rounded-xl flex items-center justify-center bg-cyan-500/10">
            <Icon className="w-6 h-6 text-cyan-400" />
          </div>
          <div>
            <p className="text-sm font-medium text-white">{asset.name}</p>
            <p className="text-xs text-white/40">{asset.type}</p>
          </div>
        </div>
        <div className="text-right">
          <p className="text-sm font-bold text-white">৳{asset.value?.toLocaleString()}</p>
          <p className="text-xs text-white/30 mt-0.5">Value</p>
        </div>
      </div>

      <div className="bg-white/[0.02] rounded-xl p-3 border border-white/5 mb-4">
        <div className="flex justify-between items-center mb-1">
          <span className="text-xs text-white/50">Total Expenses Linked</span>
          <span className="text-sm font-semibold text-red-400">৳{totalExpense?.toLocaleString()}</span>
        </div>
      </div>

      <div className="flex items-end justify-between">
        <p className="text-xs text-white/30">
          Purchased: {new Date(asset.purchase_date).toLocaleDateString()}
        </p>
        <div className="flex gap-1 opacity-0 group-hover:opacity-100 transition-opacity">
          <button onClick={() => onEdit(asset)} className="p-2 rounded-lg text-white/30 hover:text-cyan-400 hover:bg-cyan-500/10 transition-all">
            <Pencil className="w-4 h-4" />
          </button>
          <button onClick={() => onDelete(asset.id)} className="p-2 rounded-lg text-white/30 hover:text-red-400 hover:bg-red-500/10 transition-all">
            <Trash2 className="w-4 h-4" />
          </button>
        </div>
      </div>
    </div>
  );
}

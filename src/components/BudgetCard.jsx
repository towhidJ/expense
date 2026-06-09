import { Card, CardContent } from "@/components/ui/card";

export default function BudgetCard({ budget, spent }) {
  const percentage = budget.amount > 0 ? Math.min((spent / budget.amount) * 100, 100) : 0;
  const remaining = budget.amount - spent;
  const isOver = spent > budget.amount;
  const barColor = percentage > 90 ? '#ef4444' : percentage > 70 ? '#f59e0b' : 'var(--primary)';

  return (
    <Card className="hover:shadow-md transition-all bg-card border-border">
      <CardContent className="p-5">
        <div className="flex items-center justify-between mb-3">
          <div className="flex items-center gap-3">
            <span className="text-xl">{budget.categories?.icon || '📁'}</span>
            <div>
              <p className="text-sm font-medium">{budget.categories?.name || 'Category'}</p>
              <p className="text-xs text-muted-foreground">Monthly Budget</p>
            </div>
          </div>
          <div className="text-right">
            <p className={`text-sm font-bold ${isOver ? 'text-destructive' : ''}`}>
              ৳{spent.toLocaleString()} <span className="text-muted-foreground font-normal">/ ৳{budget.amount.toLocaleString()}</span>
            </p>
          </div>
        </div>
        <div className="w-full h-2 bg-secondary rounded-full overflow-hidden">
          <div
            className="h-full rounded-full transition-all duration-500 ease-out"
            style={{ width: `${percentage}%`, backgroundColor: barColor }}
          />
        </div>
        <div className="flex justify-between mt-2">
          <p className="text-xs text-muted-foreground">{percentage.toFixed(0)}% used</p>
          <p className={`text-xs ${isOver ? 'text-destructive' : 'text-emerald-500'}`}>
            {isOver ? `Over by ৳${Math.abs(remaining).toLocaleString()}` : `৳${remaining.toLocaleString()} remaining`}
          </p>
        </div>
      </CardContent>
    </Card>
  );
}

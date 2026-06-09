import { Card, CardContent } from "@/components/ui/card";

export default function StatCard({ title, value, icon: Icon, trend, trendUp, gradient, iconBg }) {
  return (
    <Card className="group relative overflow-hidden transition-all duration-300 hover:shadow-lg hover:-translate-y-0.5 border-border bg-card">
      <div className="absolute inset-0 bg-gradient-to-br opacity-0 group-hover:opacity-100 transition-opacity duration-300" style={{ backgroundImage: gradient ? `linear-gradient(to bottom right, ${gradient[0]}10, ${gradient[1]}10)` : 'none' }} />
      <CardContent className="p-6 relative flex items-start justify-between pb-6">
        <div>
          <p className="text-sm text-muted-foreground mb-1">{title}</p>
          <p className="text-2xl font-bold tracking-tight">{value}</p>
          {trend !== undefined && (
            <p className={`text-xs mt-2 flex items-center gap-1 ${trendUp ? 'text-emerald-400' : 'text-destructive'}`}>
              <span>{trendUp ? '↑' : '↓'}</span>
              <span>{Math.abs(trend)}% vs last month</span>
            </p>
          )}
        </div>
        <div className={`w-12 h-12 rounded-xl flex items-center justify-center ${iconBg || 'bg-cyan-500/10'}`}>
          {Icon && <Icon className="w-6 h-6" style={{ color: gradient?.[0] || 'var(--primary)' }} />}
        </div>
      </CardContent>
    </Card>
  );
}

import { NavLink, useNavigate } from 'react-router';
import { useMeal } from '../../context/MealContext';
import {
  UtensilsCrossed, LayoutDashboard, CalendarDays, PiggyBank, ShoppingBasket,
  ClipboardList, Users, Settings, ChevronLeft, ChevronRight, X, ArrowLeftRight,
  CalendarClock, Megaphone, ListTodo, Receipt, CalendarRange, Bell, TrendingUp, Package
} from 'lucide-react';

const MONTHS = ['January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December'];

const navItems = [
  { to: '/meals', end: true, icon: LayoutDashboard, label: 'Summary' },
  { to: '/meals/daily', icon: CalendarDays, label: 'Daily Meals' },
  { to: '/meals/calendar', icon: CalendarRange, label: 'Meal Calendar' },
  { to: '/meals/requests', icon: CalendarClock, label: 'Meal Requests' },
  { to: '/meals/shopping', icon: ListTodo, label: 'Shopping List' },
  { to: '/meals/expenses', icon: ShoppingBasket, label: 'Expenses' },
  { to: '/meals/bills', icon: Receipt, label: 'Shared Bills' },
  { to: '/meals/deposits', icon: PiggyBank, label: 'Deposits & Advance' },
  { to: '/meals/notices', icon: Megaphone, label: 'Notice Board' },
  { to: '/meals/notifications', icon: Bell, label: 'Notifications' },
  { to: '/meals/duty', icon: ClipboardList, label: 'Duty Roster' },
  { to: '/meals/stock', icon: Package, label: 'Stock' },
  { to: '/meals/reports', icon: TrendingUp, label: 'Reports' },
  { to: '/meals/members', icon: Users, label: 'Members' },
  { to: '/meals/settings', icon: Settings, label: 'Settings' }
];

// The meal workspace's own sidebar: mess switcher, month picker, meal nav,
// and a link back to the expense tracker workspace.
export default function MealSidebar({ isOpen, onClose }) {
  const { approved, activeMembership, switchGroup, year, month, shiftMonth, data, isManager } = useMeal();
  const navigate = useNavigate();
  const pendingCount = data.members.filter(m => m.status === 'pending').length;
  const pendingRequests = (data.requests || []).filter(r => r.status === 'pending').length;
  const unreadNotifications = (data.notifications || []).filter(n => !n.is_read).length;
  const group = data.group || activeMembership?.meal_groups;

  const handleGroupChange = (e) => {
    if (e.target.value === '__groups__') {
      navigate('/meals/groups');
      onClose();
      return;
    }
    switchGroup(e.target.value);
  };

  return (
    <>
      {isOpen && (
        <div className="fixed inset-0 bg-black/50 backdrop-blur-sm z-40 lg:hidden" onClick={onClose} />
      )}
      <aside
        className={`fixed top-0 left-0 h-full w-[280px] bg-foreground/5 backdrop-blur-2xl border-r border-foreground/10 z-50 flex flex-col transition-transform duration-300 lg:translate-x-0 ${
          isOpen ? 'translate-x-0' : '-translate-x-full'
        }`}
      >
        <div className="flex items-center justify-between p-6 border-b border-foreground/10">
          <div className="flex items-center gap-3 min-w-0">
            <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-emerald-500 to-cyan-600 flex items-center justify-center shadow-lg shadow-emerald-500/25 shrink-0">
              <UtensilsCrossed className="w-5 h-5 text-foreground" />
            </div>
            <div className="min-w-0">
              <h1 className="text-lg font-bold text-foreground tracking-tight truncate">{group?.name || 'Meal Manager'}</h1>
              <p className="text-xs text-foreground/40">Mess Workspace{isManager ? ' · Manager' : ''}</p>
            </div>
          </div>
          <button onClick={onClose} className="lg:hidden text-foreground/40 hover:text-foreground transition-colors shrink-0">
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Mess switcher */}
        <div className="px-4 pt-4">
          <label className="flex items-center gap-1.5 text-[11px] uppercase tracking-wider text-foreground/30 mb-1.5 px-1">
            <UtensilsCrossed className="w-3 h-3" /> Mess
          </label>
          <select
            value={activeMembership?.group_id || ''}
            onChange={handleGroupChange}
            className="w-full bg-foreground/5 border border-foreground/10 rounded-xl px-3 py-2 text-foreground text-sm focus:outline-none focus:border-emerald-500/50 appearance-none cursor-pointer"
          >
            {approved.map(m => (
              <option key={m.group_id} value={m.group_id} className="bg-muted">
                {m.meal_groups?.name || 'Mess'}
              </option>
            ))}
            <option value="__groups__" className="bg-muted">＋ Create / Join mess...</option>
          </select>
        </div>

        {/* Month picker */}
        <div className="px-4 pt-3">
          <div className="flex items-center justify-between bg-foreground/5 border border-foreground/10 rounded-xl px-2 py-1.5">
            <button onClick={() => shiftMonth(-1)} className="p-1.5 rounded-lg text-foreground/50 hover:text-foreground hover:bg-foreground/5">
              <ChevronLeft size={16} />
            </button>
            <span className="text-foreground text-sm font-medium">{MONTHS[month - 1]} {year}</span>
            <button onClick={() => shiftMonth(1)} className="p-1.5 rounded-lg text-foreground/50 hover:text-foreground hover:bg-foreground/5">
              <ChevronRight size={16} />
            </button>
          </div>
        </div>

        <nav className="flex-1 p-4 space-y-1 overflow-y-auto">
          {navItems.map(({ to, end, icon: Icon, label }) => (
            <NavLink
              key={to}
              to={to}
              end={end}
              onClick={onClose}
              className={({ isActive }) =>
                `flex items-center gap-3 px-4 py-3 rounded-xl text-sm font-medium transition-all duration-200 ${
                  isActive
                    ? 'bg-gradient-to-r from-emerald-500/20 to-cyan-600/20 text-emerald-400 border border-emerald-500/20 shadow-lg shadow-emerald-500/5'
                    : 'text-foreground/50 hover:text-foreground hover:bg-foreground/5 border border-transparent'
                }`
              }
            >
              <Icon className="w-[18px] h-[18px] shrink-0" />
              <span className="flex-1">{label}</span>
              {label === 'Members' && isManager && pendingCount > 0 && (
                <span className="w-5 h-5 rounded-full bg-orange-500 text-white text-[11px] flex items-center justify-center">
                  {pendingCount}
                </span>
              )}
              {label === 'Meal Requests' && isManager && pendingRequests > 0 && (
                <span className="w-5 h-5 rounded-full bg-orange-500 text-white text-[11px] flex items-center justify-center">
                  {pendingRequests}
                </span>
              )}
              {label === 'Notifications' && unreadNotifications > 0 && (
                <span className="w-5 h-5 rounded-full bg-cyan-500 text-white text-[11px] flex items-center justify-center">
                  {unreadNotifications}
                </span>
              )}
            </NavLink>
          ))}
        </nav>

        <div className="p-4 border-t border-foreground/10">
          <NavLink
            to="/"
            className="flex items-center gap-3 px-4 py-3 rounded-xl text-sm font-medium text-foreground/50 hover:text-cyan-400 hover:bg-foreground/5 transition-all"
          >
            <ArrowLeftRight className="w-[18px] h-[18px]" />
            TakaKhata
          </NavLink>
        </div>
      </aside>
    </>
  );
}

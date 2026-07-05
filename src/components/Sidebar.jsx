import { NavLink, useNavigate } from 'react-router';
import { useAuth } from '../context/AuthContext';
import { useEntity } from '../context/EntityContext';
import {
  LayoutDashboard, ArrowLeftRight, PieChart, Wallet,
  LogOut, X, DollarSign, Bike, Landmark, Target, Shield, TrendingUp, Users, Repeat, Tags, Briefcase, PiggyBank
} from 'lucide-react';

const navItems = [
  { to: '/', icon: LayoutDashboard, label: 'Dashboard' },
  { to: '/accounts', icon: Landmark, label: 'Accounts' },
  { to: '/transactions', icon: ArrowLeftRight, label: 'Transactions' },
  { to: '/recurring', icon: Repeat, label: 'Recurring' },
  { to: '/categories', icon: Tags, label: 'Categories' },
  { to: '/transfers', icon: ArrowLeftRight, label: 'Transfers' },
  { to: '/reports', icon: PieChart, label: 'Reports' },
  { to: '/budgets', icon: Wallet, label: 'Budgets' },
  { to: '/goals', icon: Target, label: 'Goals' },
  { to: '/savings', icon: PiggyBank, label: 'Savings' },
  { to: '/family', icon: Users, label: 'Family' },
  { to: '/assets', icon: Bike, label: 'Assets' },
  { to: '/liabilities', icon: Shield, label: 'Liabilities' },
  { to: '/investments', icon: TrendingUp, label: 'Investments' }
];

export default function Sidebar({ isOpen, onClose }) {
  const { signOut, user } = useAuth();
  const { entities, currentEntity, switchEntity, addEntity } = useEntity();
  const navigate = useNavigate();

  const handleSignOut = async () => {
    await signOut();
    navigate('/login');
  };

  const handleEntityChange = async (e) => {
    if (e.target.value === '__new__') {
      const name = window.prompt('New workspace name (e.g. Family, Business):');
      if (!name?.trim()) return;
      let type = (window.prompt('Type: personal / family / business', 'personal') || 'personal').toLowerCase().trim();
      if (!['personal', 'family', 'business'].includes(type)) type = 'personal';
      try {
        const created = await addEntity({ name: name.trim(), type });
        switchEntity(created.id);
      } catch (err) {
        alert('Error creating workspace: ' + err.message);
      }
    } else {
      switchEntity(e.target.value);
    }
  };

  return (
    <>
      {isOpen && (
        <div
          className="fixed inset-0 bg-black/50 backdrop-blur-sm z-40 lg:hidden"
          onClick={onClose}
        />
      )}
      <aside
        className={`fixed top-0 left-0 h-full w-[280px] bg-white/5 backdrop-blur-2xl border-r border-white/10 z-50 flex flex-col transition-transform duration-300 lg:translate-x-0 ${
          isOpen ? 'translate-x-0' : '-translate-x-full'
        }`}
      >
        <div className="flex items-center justify-between p-6 border-b border-white/10">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-cyan-500 to-purple-600 flex items-center justify-center shadow-lg shadow-cyan-500/25">
              <DollarSign className="w-5 h-5 text-white" />
            </div>
            <div>
              <h1 className="text-lg font-bold text-white tracking-tight">ExpenseTracker</h1>
              <p className="text-xs text-white/40">Finance Manager</p>
            </div>
          </div>
          <button onClick={onClose} className="lg:hidden text-white/40 hover:text-white transition-colors">
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Workspace switcher */}
        <div className="px-4 pt-4">
          <label className="flex items-center gap-1.5 text-[11px] uppercase tracking-wider text-white/30 mb-1.5 px-1">
            <Briefcase className="w-3 h-3" /> Workspace
          </label>
          <select
            value={currentEntity?.id || ''}
            onChange={handleEntityChange}
            className="w-full bg-white/5 border border-white/10 rounded-xl px-3 py-2 text-white text-sm focus:outline-none focus:border-cyan-500/50 appearance-none cursor-pointer"
          >
            {entities.map(e => (
              <option key={e.id} value={e.id} className="bg-[#12122a] capitalize">
                {e.name} ({e.type})
              </option>
            ))}
            <option value="__new__" className="bg-[#12122a]">＋ New workspace...</option>
          </select>
        </div>

        <nav className="flex-1 p-4 space-y-1 overflow-y-auto">
          {navItems.map(({ to, icon: Icon, label }) => (
            <NavLink
              key={to}
              to={to}
              onClick={onClose}
              className={({ isActive }) =>
                `flex items-center gap-3 px-4 py-3 rounded-xl text-sm font-medium transition-all duration-200 group ${
                  isActive
                    ? 'bg-gradient-to-r from-cyan-500/20 to-purple-600/20 text-cyan-400 border border-cyan-500/20 shadow-lg shadow-cyan-500/5'
                    : 'text-white/50 hover:text-white hover:bg-white/5'
                }`
              }
            >
              <Icon className="w-5 h-5 transition-transform group-hover:scale-110" />
              {label}
            </NavLink>
          ))}
        </nav>

        <div className="p-4 border-t border-white/10">
          <div className="flex items-center gap-3 px-4 py-3 mb-2">
            <div className="w-8 h-8 rounded-full bg-gradient-to-br from-cyan-500 to-purple-600 flex items-center justify-center text-white text-xs font-bold">
              {user?.email?.[0]?.toUpperCase() || 'U'}
            </div>
            <div className="flex-1 min-w-0">
              <p className="text-sm text-white/80 truncate">{user?.user_metadata?.full_name || 'User'}</p>
              <p className="text-xs text-white/30 truncate">{user?.email}</p>
            </div>
          </div>
          <button
            onClick={handleSignOut}
            className="flex items-center gap-3 px-4 py-3 rounded-xl text-sm font-medium text-red-400/70 hover:text-red-400 hover:bg-red-500/10 transition-all w-full"
          >
            <LogOut className="w-5 h-5" />
            Sign Out
          </button>
        </div>
      </aside>
    </>
  );
}

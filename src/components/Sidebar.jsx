import { useState } from 'react';
import { NavLink, useNavigate } from 'react-router';
import { useAuth } from '../context/AuthContext';
import { useEntity } from '../context/EntityContext';
import { useIsAdmin } from '../hooks/useIsAdmin';
import {
  LayoutDashboard, ArrowLeftRight, PieChart, Wallet,
  LogOut, X, DollarSign, Bike, Landmark, Target, Shield, TrendingUp, Users, Repeat, Tags, Briefcase, PiggyBank, KeyRound, ShoppingBasket, ShieldCheck, UtensilsCrossed
} from 'lucide-react';

const navItems = [
  { to: '/', icon: LayoutDashboard, label: 'Dashboard' },
  { to: '/accounts', icon: Landmark, label: 'Accounts' },
  { to: '/transactions', icon: ArrowLeftRight, label: 'Transactions' },
  { to: '/bazar', icon: ShoppingBasket, label: 'Bazar' },
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
  const { signOut, user, changePassword } = useAuth();
  const { isAdmin } = useIsAdmin();
  const { entities, currentEntity, switchEntity, addEntity } = useEntity();
  const navigate = useNavigate();
  const [showPasswordModal, setShowPasswordModal] = useState(false);
  const [pwForm, setPwForm] = useState({ current: '', next: '', confirm: '' });
  const [pwSubmitting, setPwSubmitting] = useState(false);

  const handleSignOut = async () => {
    await signOut();
    navigate('/login');
  };

  const handleChangePassword = async (e) => {
    e.preventDefault();
    if (pwForm.next.length < 6) {
      alert('New password must be at least 6 characters.');
      return;
    }
    if (pwForm.next !== pwForm.confirm) {
      alert('New password and confirmation do not match.');
      return;
    }
    setPwSubmitting(true);
    try {
      await changePassword(pwForm.current, pwForm.next);
      setShowPasswordModal(false);
      setPwForm({ current: '', next: '', confirm: '' });
      alert('Password changed successfully!');
    } catch (err) {
      alert(err.message);
    }
    setPwSubmitting(false);
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
          {[...navItems, ...(isAdmin ? [{ to: '/admin', icon: ShieldCheck, label: 'Admin' }] : [])].map(({ to, icon: Icon, label }) => (
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
          {/* Meal workspace: a separate section of the app with its own layout */}
          <NavLink
            to="/meals"
            onClick={onClose}
            className="flex items-center gap-3 px-4 py-3 mb-2 rounded-xl text-sm font-medium bg-gradient-to-r from-emerald-500/15 to-cyan-600/15 border border-emerald-500/20 text-emerald-300 hover:from-emerald-500/25 hover:to-cyan-600/25 transition-all"
          >
            <UtensilsCrossed className="w-5 h-5" />
            <span className="flex-1">Meal Manager</span>
            <span className="text-[10px] uppercase tracking-wider text-emerald-400/60">Workspace</span>
          </NavLink>
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
            onClick={() => { setPwForm({ current: '', next: '', confirm: '' }); setShowPasswordModal(true); }}
            className="flex items-center gap-3 px-4 py-3 rounded-xl text-sm font-medium text-white/50 hover:text-white hover:bg-white/5 transition-all w-full"
          >
            <KeyRound className="w-5 h-5" />
            Change Password
          </button>
          <button
            onClick={handleSignOut}
            className="flex items-center gap-3 px-4 py-3 rounded-xl text-sm font-medium text-red-400/70 hover:text-red-400 hover:bg-red-500/10 transition-all w-full"
          >
            <LogOut className="w-5 h-5" />
            Sign Out
          </button>
        </div>
      </aside>

      {/* Change Password Modal */}
      {showPasswordModal && (
        <div className="fixed inset-0 bg-black/60 backdrop-blur-sm z-[60] flex items-center justify-center p-4" onClick={() => setShowPasswordModal(false)}>
          <div className="bg-[#12122a] border border-white/10 rounded-2xl w-full max-w-sm shadow-2xl" onClick={e => e.stopPropagation()}>
            <div className="flex items-center justify-between p-6 border-b border-white/10">
              <h2 className="text-lg font-semibold text-white">Change Password</h2>
              <button onClick={() => setShowPasswordModal(false)} className="text-white/40 hover:text-white transition-colors">
                <X className="w-5 h-5" />
              </button>
            </div>
            <form onSubmit={handleChangePassword} className="p-6 space-y-4">
              <div>
                <label className="block text-sm text-white/50 mb-1.5">Current Password</label>
                <input
                  type="password"
                  required
                  autoComplete="current-password"
                  value={pwForm.current}
                  onChange={e => setPwForm(f => ({ ...f, current: e.target.value }))}
                  className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-2.5 text-white text-sm focus:outline-none focus:border-cyan-500/50"
                  autoFocus
                />
              </div>
              <div>
                <label className="block text-sm text-white/50 mb-1.5">New Password</label>
                <input
                  type="password"
                  required
                  minLength={6}
                  autoComplete="new-password"
                  value={pwForm.next}
                  onChange={e => setPwForm(f => ({ ...f, next: e.target.value }))}
                  className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-2.5 text-white text-sm focus:outline-none focus:border-cyan-500/50"
                />
                <p className="text-xs text-white/30 mt-1">At least 6 characters</p>
              </div>
              <div>
                <label className="block text-sm text-white/50 mb-1.5">Confirm New Password</label>
                <input
                  type="password"
                  required
                  minLength={6}
                  autoComplete="new-password"
                  value={pwForm.confirm}
                  onChange={e => setPwForm(f => ({ ...f, confirm: e.target.value }))}
                  className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-2.5 text-white text-sm focus:outline-none focus:border-cyan-500/50"
                />
              </div>
              <button
                type="submit"
                disabled={pwSubmitting}
                className="w-full py-3 rounded-xl bg-gradient-to-r from-cyan-500 to-purple-600 text-white font-semibold text-sm hover:shadow-lg hover:shadow-cyan-500/25 transition-all disabled:opacity-50"
              >
                {pwSubmitting ? 'Updating...' : 'Update Password'}
              </button>
            </form>
          </div>
        </div>
      )}
    </>
  );
}

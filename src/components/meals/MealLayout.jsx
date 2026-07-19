import { useState } from 'react';
import { Outlet, useLocation } from 'react-router';
import { useMeal } from '../../context/MealContext';
import MealSidebar from './MealSidebar';
import Onboarding from './Onboarding';
import { Menu } from 'lucide-react';

// The meal workspace shell: its own sidebar + pages, separate from the
// expense tracker's Layout. Without an approved mess it shows onboarding.
export default function MealLayout() {
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const { loading, activeMembership } = useMeal();
  const location = useLocation();

  if (loading && !activeMembership) {
    return (
      <div className="min-h-screen bg-background text-foreground flex items-center justify-center">
        <p className="text-foreground/50">Loading meal workspace...</p>
      </div>
    );
  }

  // No approved mess yet: full-page create/join (except nothing else to show)
  if (!activeMembership) {
    return (
      <div className="min-h-screen bg-background text-foreground">
        <main className="p-4 md:p-6 lg:p-8 max-w-5xl mx-auto">
          <Onboarding />
        </main>
      </div>
    );
  }

  // /meals/groups renders inside the shell too (create/join another mess)
  return (
    <div className="min-h-screen bg-background text-foreground">
      <MealSidebar isOpen={sidebarOpen} onClose={() => setSidebarOpen(false)} />

      <div className="lg:ml-[280px]">
        <header className="sticky top-0 z-30 flex items-center h-16 px-6 bg-background/80 backdrop-blur-xl border-b border-border lg:hidden">
          <button
            onClick={() => setSidebarOpen(true)}
            className="p-2 text-muted-foreground hover:text-foreground transition-colors rounded-lg hover:bg-foreground/5"
          >
            <Menu className="w-6 h-6" />
          </button>
          <span className="ml-4 text-foreground font-semibold">Meal Manager</span>
        </header>

        <main className="p-4 md:p-6 lg:p-8" key={location.pathname}>
          <Outlet />
        </main>
      </div>
    </div>
  );
}

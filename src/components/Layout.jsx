import { useEffect, useState } from 'react';
import { Outlet } from 'react-router';
import Sidebar from './Sidebar';
import { supabase } from '../lib/supabase';
import { Menu, Smartphone } from 'lucide-react';

export default function Layout() {
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const [apk, setApk] = useState(null); // latest release { apk_url, version_name }

  useEffect(() => {
    supabase
      .from('app_versions')
      .select('apk_url, version_name')
      .order('version_code', { ascending: false })
      .limit(1)
      .maybeSingle()
      .then(({ data }) => setApk(data || null));
  }, []);

  return (
    <div className="min-h-screen bg-background text-foreground">
      <Sidebar isOpen={sidebarOpen} onClose={() => setSidebarOpen(false)} />

      <div className="lg:ml-[280px]">
        <header className="sticky top-0 z-30 flex items-center h-16 px-6 bg-background/80 backdrop-blur-xl border-b border-border lg:hidden">
          <button
            onClick={() => setSidebarOpen(true)}
            className="p-2 text-muted-foreground hover:text-foreground transition-colors rounded-lg hover:bg-white/5"
          >
            <Menu className="w-6 h-6" />
          </button>
          <img src="/logo.png" alt="" className="ml-4 w-7 h-7 rounded-lg" />
          <span className="ml-2 text-foreground font-semibold">TakaKhata</span>
        </header>

        <main className="p-4 md:p-6 lg:p-8">
          <Outlet />
        </main>

        <footer className="flex flex-col sm:flex-row items-center gap-2 sm:justify-between px-6 py-4 border-t border-white/5 text-xs text-muted-foreground/60">
          {apk ? (
            <a
              href={apk.apk_url}
              download
              className="flex items-center gap-2 text-cyan-400/80 hover:text-cyan-300 transition-colors font-medium"
            >
              <Smartphone className="w-3.5 h-3.5" />
              Download Android App (v{apk.version_name})
            </a>
          ) : <span />}
          <span className="flex items-center gap-2">
            <img src="/logo.png" alt="" className="w-4 h-4 rounded" />
            TakaKhata — Developed by Towhidul Islam
          </span>
        </footer>
      </div>
    </div>
  );
}

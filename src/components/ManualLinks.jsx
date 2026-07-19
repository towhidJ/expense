import { useEffect, useState } from 'react';
import { supabase } from '../lib/supabase';
import { BookOpen } from 'lucide-react';

// Public list of user-manual PDFs (v45 app_manuals table, readable by anon).
// Used in the app footer (Layout) and the login page — no session required.
export default function ManualLinks({ className = '', linkClassName = '' }) {
  const [manuals, setManuals] = useState([]);

  useEffect(() => {
    supabase
      .from('app_manuals')
      .select('id, title, file_url')
      .order('sort_order', { ascending: true })
      .order('created_at', { ascending: false })
      .then(({ data }) => setManuals(data || []));
  }, []);

  if (manuals.length === 0) return null;

  return (
    <div className={`flex flex-wrap items-center gap-x-4 gap-y-1 ${className}`}>
      {manuals.map(m => (
        <a
          key={m.id}
          href={m.file_url}
          target="_blank"
          rel="noreferrer"
          className={`flex items-center gap-1.5 transition-colors ${linkClassName || 'text-cyan-400/80 hover:text-cyan-300 font-medium'}`}
        >
          <BookOpen className="w-3.5 h-3.5" />
          {m.title}
        </a>
      ))}
    </div>
  );
}

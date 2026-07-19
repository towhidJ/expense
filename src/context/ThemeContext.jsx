import { createContext, useContext, useEffect, useState } from 'react';

// index.html applies the initial 'dark' class synchronously (before React
// mounts) to avoid a flash of the wrong theme; this just keeps state in sync
// with localStorage after that.
const ThemeContext = createContext({});

export const useTheme = () => useContext(ThemeContext);

function getInitialTheme() {
  return localStorage.getItem('theme') === 'light' ? 'light' : 'dark';
}

export function ThemeProvider({ children }) {
  const [theme, setTheme] = useState(getInitialTheme);

  useEffect(() => {
    document.documentElement.classList.toggle('dark', theme === 'dark');
    localStorage.setItem('theme', theme);
  }, [theme]);

  const toggleTheme = () => setTheme((t) => (t === 'dark' ? 'light' : 'dark'));

  return (
    <ThemeContext.Provider value={{ theme, toggleTheme, setTheme }}>
      {children}
    </ThemeContext.Provider>
  );
}

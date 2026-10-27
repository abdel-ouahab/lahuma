import React, { useEffect, useState } from 'react';
import { useLocation } from 'react-router-dom';
import { Sun, Moon, Menu } from 'lucide-react';
import { useTheme } from '../context/ThemeContext';
import { checkBackendHealth } from '../services/api';
import { NAV_ITEMS } from './nav';

interface NavbarProps {
  onMenu: () => void;
}

export const Navbar: React.FC<NavbarProps> = ({ onMenu }) => {
  const { theme, toggleTheme } = useTheme();
  const { pathname } = useLocation();
  const [apiOnline, setApiOnline] = useState<boolean | null>(null);
  const [healthMsg, setHealthMsg] = useState<string>('Checking backend…');

  useEffect(() => {
    let isMounted = true;
    checkBackendHealth().then((res) => {
      if (isMounted) {
        setApiOnline(res.online);
        setHealthMsg(res.message);
      }
    });
    return () => {
      isMounted = false;
    };
  }, []);

  const current = NAV_ITEMS.find((n) => (n.path === '/' ? pathname === '/' : pathname.startsWith(n.path)));
  const statusClass = apiOnline === null ? '' : apiOnline ? 'online' : 'degraded';
  const statusText = apiOnline === null ? 'Checking' : apiOnline ? 'API online' : 'API offline';

  return (
    <header className="topbar">
      <div className="topbar-left">
        <button type="button" className="btn-icon menu-btn" onClick={onMenu} aria-label="Open menu">
          <Menu size={19} />
        </button>
        <h2 className="crumb">{current?.title ?? 'Lahuma Admin'}</h2>
      </div>

      <div className="topbar-right">
        <div className="status-pill" title={healthMsg} role="status">
          <span className={`pulse-dot ${statusClass}`} aria-hidden="true" />
          <span className="status-text">{statusText}</span>
        </div>

        <button
          type="button"
          onClick={toggleTheme}
          className="btn-icon"
          aria-label={`Switch to ${theme === 'light' ? 'dark' : 'light'} mode`}
          title={`Switch to ${theme === 'light' ? 'dark' : 'light'} mode`}
        >
          {theme === 'light' ? <Moon size={18} /> : <Sun size={18} />}
        </button>
      </div>
    </header>
  );
};

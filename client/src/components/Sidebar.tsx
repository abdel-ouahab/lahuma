import React from 'react';
import { NavLink } from 'react-router-dom';
import { LogOut, PanelLeftClose, PanelLeftOpen, X } from 'lucide-react';
import { useAuth } from '../context/AuthContext';
import { NAV_ITEMS } from './nav';

interface SidebarProps {
  collapsed: boolean;
  onToggle: () => void;
  mobileOpen: boolean;
  onClose: () => void;
}

export const Sidebar: React.FC<SidebarProps> = ({ collapsed, onToggle, mobileOpen, onClose }) => {
  const { user, logout } = useAuth();
  const displayName = user?.name || 'Admin';

  return (
    <>
      <div className={`sidebar-scrim ${mobileOpen ? 'open' : ''}`} onClick={onClose} aria-hidden="true" />
      <aside
        className={`sidebar ${collapsed ? 'collapsed' : ''} ${mobileOpen ? 'open' : ''}`}
        aria-label="Primary"
      >
        <div className="sidebar-head">
          <div className="brand">
            <div className="brand-mark" aria-hidden="true">ل</div>
            <div className="brand-text">
              <div className="brand-name">Lahuma</div>
              <span className="brand-tag">Admin</span>
            </div>
          </div>

          <button
            type="button"
            className="btn-icon collapse-btn"
            onClick={onToggle}
            aria-label={collapsed ? 'Expand sidebar' : 'Collapse sidebar'}
            title={collapsed ? 'Expand sidebar' : 'Collapse sidebar'}
          >
            {collapsed ? <PanelLeftOpen size={18} /> : <PanelLeftClose size={18} />}
          </button>
          <button type="button" className="btn-icon menu-btn" onClick={onClose} aria-label="Close menu">
            <X size={18} />
          </button>
        </div>

        <nav className="sidebar-nav">
          {NAV_ITEMS.map(({ name, path, icon: Icon }) => (
            <NavLink
              key={path}
              to={path}
              end={path === '/'}
              className={({ isActive }) => `nav-link ${isActive ? 'active' : ''}`}
              title={collapsed ? name : undefined}
              aria-label={name}
              onClick={onClose}
            >
              <Icon size={17} />
              <span className="nav-label">{name}</span>
            </NavLink>
          ))}
        </nav>

        <div className="sidebar-foot">
          <div className="user-chip">
            <div className="avatar" aria-hidden="true">{displayName.charAt(0)}</div>
            <div className="user-meta">
              <div className="user-name">{displayName}</div>
              <div className="user-email">{user?.email || 'admin@lahuma.app'}</div>
            </div>
          </div>
          <button type="button" className="btn-icon" onClick={logout} aria-label="Sign out" title="Sign out">
            <LogOut size={17} />
          </button>
        </div>
      </aside>
    </>
  );
};

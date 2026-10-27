import React from 'react';
import type { LucideIcon } from 'lucide-react';

interface EmptyStateProps {
  icon: LucideIcon;
  title: string;
  message?: string;
  children?: React.ReactNode;
}

export const EmptyState: React.FC<EmptyStateProps> = ({ icon: Icon, title, message, children }) => (
  <div className="empty">
    <Icon size={28} aria-hidden="true" />
    <div className="empty-title">{title}</div>
    {message && <div>{message}</div>}
    {children}
  </div>
);

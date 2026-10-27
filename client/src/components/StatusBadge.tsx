import React from 'react';
import type { UserRole, UserStatus } from '../types';

interface StatusBadgeProps {
  type: 'role' | 'status' | 'api';
  value: UserRole | UserStatus | 'healthy' | 'degraded' | 'offline';
}

const TONES: Record<string, string> = {
  ADMIN: 'badge-brand',
  MODERATOR: 'badge-info',
  USER: '',
  ACTIVE: 'badge-success',
  INACTIVE: 'badge-warning',
  SUSPENDED: 'badge-danger',
  healthy: 'badge-success',
  degraded: 'badge-warning',
  offline: 'badge-danger',
};

const label = (v: string) => v.charAt(0).toUpperCase() + v.slice(1).toLowerCase();

export const StatusBadge: React.FC<StatusBadgeProps> = ({ type, value }) => (
  <span className={`badge ${TONES[value] ?? ''}`}>
    {type !== 'role' && <span className="badge-dot" aria-hidden="true" />}
    {label(value)}
  </span>
);

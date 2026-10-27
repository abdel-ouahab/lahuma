import React from 'react';
import type { LucideIcon } from 'lucide-react';
import { CardShell, type CardColor } from './ui/course-design-cards';

interface StatCardProps {
  title: string;
  value: string | number | null;
  icon: LucideIcon;
  subtitle?: string;
  color?: CardColor;
}

export const StatCard: React.FC<StatCardProps> = ({ title, value, icon: Icon, subtitle, color = 'green' }) => (
  <CardShell
    color={color}
    eyebrow={<><Icon size={15} aria-hidden="true" /><span>{title}</span></>}
    footer={subtitle ? <span>{subtitle}</span> : undefined}
  >
    {value === null ? (
      <span className="skeleton" style={{ height: 32, width: '45%' }} aria-label="Loading" />
    ) : (
      <span className="cdc-value">{value}</span>
    )}
  </CardShell>
);

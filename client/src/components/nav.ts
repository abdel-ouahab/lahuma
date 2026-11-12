import { LayoutDashboard, Users, BookOpen, Mic2, Settings } from 'lucide-react';
import type { LucideIcon } from 'lucide-react';

export interface NavItem {
  name: string;
  title: string;
  path: string;
  icon: LucideIcon;
}

export const NAV_ITEMS: NavItem[] = [
  { name: 'Dashboard', title: 'Dashboard', path: '/', icon: LayoutDashboard },
  { name: 'Users', title: 'Users', path: '/users', icon: Users },
  { name: 'Quran', title: 'Quran content', path: '/quran', icon: BookOpen },
  { name: 'Reciters', title: 'Reciters', path: '/reciters', icon: Mic2 },
  { name: 'Settings', title: 'Settings', path: '/settings', icon: Settings },
];

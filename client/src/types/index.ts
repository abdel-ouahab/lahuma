export type UserRole = 'ADMIN' | 'MODERATOR' | 'USER';
export type UserStatus = 'ACTIVE' | 'INACTIVE' | 'SUSPENDED';

export interface User {
  id: string;
  email: string;
  name: string;
  role: UserRole;
  status: UserStatus;
  createdAt: string;
  lastLoginAt?: string;
}

export interface Surah {
  number: number;
  name: string;
  englishName: string;
  englishNameTranslation: string;
  numberOfAyahs: number;
  revelationType: 'Meccan' | 'Medinan';
}

export interface DashboardMetrics {
  totalUsers: number;
  totalAdmins: number;
  totalReciters: number;
  uploadedSurahs: number;
  apiStatus: 'healthy' | 'offline';
}

export interface AuthState {
  user: User | null;
  token: string | null;
  isAuthenticated: boolean;
  isLoading: boolean;
}

export interface ReciterSurah {
  surahNumber: number;
  audioUrl: string | null;
}

export interface Reciter {
  id: string;
  name: string;
  nameAr: string | null;
  slug: string;
  createdAt: string;
  uploadedCount: number;
  surahs: ReciterSurah[];
}

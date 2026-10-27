import type { User, Surah, DashboardMetrics, ActivityLog, Reciter } from '../types';

// Relative path — Vite dev proxy forwards /api → http://localhost:4000/api
// In production, set VITE_API_URL and update accordingly.
const API_BASE_URL = '/api';
const HEALTH_URL = '/health';


// Mock datasets for offline / fallback demonstration
const MOCK_USERS: User[] = [
  {
    id: 'usr_1',
    name: 'Ahmed Al-Mansoor',
    email: 'admin@lahuma.app',
    role: 'ADMIN',
    status: 'ACTIVE',
    createdAt: '2026-01-15T10:00:00Z',
    lastLoginAt: '2026-08-17T14:30:00Z',
  },
  {
    id: 'usr_2',
    name: 'Fatima Zahra',
    email: 'fatima@example.com',
    role: 'MODERATOR',
    status: 'ACTIVE',
    createdAt: '2026-02-01T12:00:00Z',
    lastLoginAt: '2026-08-16T18:45:00Z',
  },
  {
    id: 'usr_3',
    name: 'Omar Farooq',
    email: 'omar@example.com',
    role: 'USER',
    status: 'ACTIVE',
    createdAt: '2026-03-10T09:15:00Z',
    lastLoginAt: '2026-08-15T11:20:00Z',
  },
  {
    id: 'usr_4',
    name: 'Aisha Siddiqua',
    email: 'aisha@example.com',
    role: 'USER',
    status: 'INACTIVE',
    createdAt: '2026-04-05T16:20:00Z',
    lastLoginAt: '2026-07-20T08:10:00Z',
  },
  {
    id: 'usr_5',
    name: 'Youssef Hassan',
    email: 'youssef@example.com',
    role: 'USER',
    status: 'SUSPENDED',
    createdAt: '2026-05-12T14:00:00Z',
    lastLoginAt: '2026-06-01T19:30:00Z',
  },
];

const MOCK_SURAHS: Surah[] = [
  { number: 1, name: 'الفاتحة', englishName: 'Al-Fatihah', englishNameTranslation: 'The Opening', numberOfAyahs: 7, revelationType: 'Meccan' },
  { number: 2, name: 'البقرة', englishName: 'Al-Baqarah', englishNameTranslation: 'The Cow', numberOfAyahs: 286, revelationType: 'Medinan' },
  { number: 3, name: 'آل عمران', englishName: 'Ali \'Imran', englishNameTranslation: 'Family of Imran', numberOfAyahs: 200, revelationType: 'Medinan' },
  { number: 4, name: 'النساء', englishName: 'An-Nisa', englishNameTranslation: 'The Women', numberOfAyahs: 176, revelationType: 'Medinan' },
  { number: 5, name: 'المائدة', englishName: 'Al-Ma\'idah', englishNameTranslation: 'The Table Spread', numberOfAyahs: 120, revelationType: 'Medinan' },
  { number: 6, name: 'الأنعام', englishName: 'Al-An\'am', englishNameTranslation: 'The Cattle', numberOfAyahs: 165, revelationType: 'Meccan' },
  { number: 7, name: 'الأعراف', englishName: 'Al-A\'raf', englishNameTranslation: 'The Heights', numberOfAyahs: 206, revelationType: 'Meccan' },
  { number: 36, name: 'يس', englishName: 'Ya-Sin', englishNameTranslation: 'Ya-Sin', numberOfAyahs: 83, revelationType: 'Meccan' },
  { number: 67, name: 'الملك', englishName: 'Al-Mulk', englishNameTranslation: 'The Sovereignty', numberOfAyahs: 30, revelationType: 'Meccan' },
  { number: 112, name: 'الإخلاص', englishName: 'Al-Ikhlas', englishNameTranslation: 'Sincerity', numberOfAyahs: 4, revelationType: 'Meccan' },
  { number: 113, name: 'الفلق', englishName: 'Al-Falaq', englishNameTranslation: 'The Daybreak', numberOfAyahs: 5, revelationType: 'Meccan' },
  { number: 114, name: 'الناس', englishName: 'An-Nas', englishNameTranslation: 'Mankind', numberOfAyahs: 6, revelationType: 'Meccan' },
];

const MOCK_ACTIVITY_LOGS: ActivityLog[] = [
  { id: 'log_1', user: 'Ahmed Al-Mansoor', action: 'System maintenance & database check executed', type: 'info', timestamp: '10 mins ago' },
  { id: 'log_2', user: 'Fatima Zahra', action: 'Created new user account (fatima@example.com)', type: 'success', timestamp: '1 hour ago' },
  { id: 'log_3', user: 'System Sentinel', action: 'API Rate limit triggered on /api/auth/login', type: 'warning', timestamp: '3 hours ago' },
  { id: 'log_4', user: 'Omar Farooq', action: 'Exported Quran reading analytics CSV', type: 'info', timestamp: '5 hours ago' },
];

export async function checkBackendHealth(): Promise<{ online: boolean; message: string }> {
  try {
    const res = await fetch(HEALTH_URL, { method: 'GET' });
    if (res.ok) {
      const data = await res.json();
      return { online: true, message: data.message || 'Backend is operational' };
    }
  } catch (err) {
    // ignore
  }
  return { online: false, message: 'Running in Standalone Demo Mode (Backend Offline)' };
}

export async function getDashboardMetrics(): Promise<DashboardMetrics> {
  const health = await checkBackendHealth();
  return {
    totalUsers: MOCK_USERS.length,
    activeToday: 42,
    totalBookmarks: 1284,
    totalSurahs: 114,
    apiStatus: health.online ? 'healthy' : 'degraded',
    dbLatencyMs: health.online ? 14 : 0,
    uptimeSeconds: 86420,
  };
}

export async function getUsers(): Promise<User[]> {
  try {
    const token = localStorage.getItem('lahuma_admin_token');
    const res = await fetch(`${API_BASE_URL}/users`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    if (res.ok) {
      const data = await res.json();
      if (Array.isArray(data.users)) return data.users;
    }
  } catch (err) {
    // fallback
  }
  return MOCK_USERS;
}

export async function createUser(userData: { email: string; name: string; role?: string }): Promise<User> {
  try {
    const token = localStorage.getItem('lahuma_admin_token');
    const res = await fetch(`${API_BASE_URL}/users`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${token}`,
      },
      body: JSON.stringify(userData),
    });
    if (res.ok) {
      const data = await res.json();
      if (data.user) return data.user;
    }
  } catch (err) {
    // fallback
  }
  return {
    id: `usr_${Date.now()}`,
    email: userData.email,
    name: userData.name,
    role: (userData.role as any) || 'USER',
    status: 'ACTIVE',
    createdAt: new Date().toISOString(),
  };
}


export async function getSurahs(): Promise<Surah[]> {
  try {
    const res = await fetch(`${API_BASE_URL}/quran/surahs`);
    if (res.ok) {
      const data = await res.json();
      // Backend returns a plain array; handle both array and { surahs: [] } shapes
      if (Array.isArray(data)) return data as Surah[];
      if (Array.isArray(data.surahs)) return data.surahs as Surah[];
    }
  } catch (err) {
    // fallback to mock
  }
  return MOCK_SURAHS;
}

export async function getActivityLogs(): Promise<ActivityLog[]> {
  return MOCK_ACTIVITY_LOGS;
}

// ---- Reciters (no mock fallback: these must reflect the real database) ----

function authHeaders(): Record<string, string> {
  return { Authorization: `Bearer ${localStorage.getItem('lahuma_admin_token')}` };
}

async function parseReciterResponse(res: Response): Promise<any> {
  if (res.status === 204) return null;
  const data = await res.json().catch(() => ({}));
  if (res.status === 401) {
    // Stale or demo-mode token: force a fresh sign-in against the real backend.
    localStorage.removeItem('lahuma_admin_token');
    localStorage.removeItem('lahuma_admin_user');
    window.location.assign('/login');
  }
  if (!res.ok) throw new Error(data.error || 'Request failed.');
  return data;
}

export async function getReciters(): Promise<Reciter[]> {
  const res = await fetch(`${API_BASE_URL}/reciters`);
  return (await parseReciterResponse(res)).reciters;
}

export async function createReciter(input: { name: string; nameAr?: string }): Promise<Reciter> {
  const res = await fetch(`${API_BASE_URL}/reciters`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', ...authHeaders() },
    body: JSON.stringify(input),
  });
  return (await parseReciterResponse(res)).reciter;
}

export async function uploadReciterAudio(reciterId: string, surahNumber: number, file: File): Promise<Reciter> {
  const body = new FormData();
  body.append('audio', file);
  const res = await fetch(`${API_BASE_URL}/reciters/${reciterId}/surahs/${surahNumber}/audio`, {
    method: 'PUT',
    headers: authHeaders(),
    body,
  });
  return (await parseReciterResponse(res)).reciter;
}

export async function deleteReciter(reciterId: string): Promise<void> {
  const res = await fetch(`${API_BASE_URL}/reciters/${reciterId}`, {
    method: 'DELETE',
    headers: authHeaders(),
  });
  await parseReciterResponse(res);
}

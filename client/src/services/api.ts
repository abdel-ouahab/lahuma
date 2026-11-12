import type { User, Surah, DashboardMetrics, Reciter } from '../types';

// Same origin: the Vite dev proxy (vite.config.ts) and Caddy in production
// (deploy/Caddyfile) both forward /api and /health to the backend.
const API_BASE_URL = '/api';
const HEALTH_URL = '/health';


// Static fallback for the Quran catalogue page only (public metadata).
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

export async function checkBackendHealth(): Promise<{ online: boolean; message: string }> {
  try {
    const res = await fetch(HEALTH_URL, { method: 'GET' });
    if (res.ok) return { online: true, message: 'Backend is operational' };
  } catch {
    // unreachable
  }
  return { online: false, message: 'Backend is unreachable' };
}

/** Real figures only: users and reciters from the API, plus its health. */
export async function getDashboardMetrics(): Promise<DashboardMetrics> {
  const [health, users, reciters] = await Promise.all([checkBackendHealth(), getUsers(), getReciters()]);
  return {
    totalUsers: users.length,
    totalAdmins: users.filter((u) => u.role === 'ADMIN').length,
    totalReciters: reciters.length,
    uploadedSurahs: reciters.reduce((sum, r) => sum + r.uploadedCount, 0),
    apiStatus: health.online ? 'healthy' : 'offline',
  };
}

/** A 401 means the token expired or was revoked: sign in again. */
function handleUnauthorized(res: Response) {
  if (res.status === 401) {
    localStorage.removeItem('lahuma_admin_token');
    localStorage.removeItem('lahuma_admin_user');
    window.location.assign('/login');
  }
}

async function parseJson(res: Response): Promise<any> {
  const data = await res.json().catch(() => ({}));
  handleUnauthorized(res);
  if (!res.ok) throw new Error(data.error || `Request failed (${res.status}).`);
  return data;
}

export async function getUsers(): Promise<User[]> {
  const res = await fetch(`${API_BASE_URL}/users`, { headers: authHeaders() });
  const data = await parseJson(res);
  if (!Array.isArray(data.users)) throw new Error('Unexpected response from the server.');
  return data.users;
}

export async function createUser(userData: {
  email: string;
  name: string;
  password: string;
  role?: string;
}): Promise<User> {
  const res = await fetch(`${API_BASE_URL}/users`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', ...authHeaders() },
    body: JSON.stringify(userData),
  });
  return (await parseJson(res)).user;
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
  } catch {
    // fall back to the static list
  }
  return MOCK_SURAHS;
}

// ---- Reciters (no mock fallback: these must reflect the real database) ----

function authHeaders(): Record<string, string> {
  return { Authorization: `Bearer ${localStorage.getItem('lahuma_admin_token')}` };
}

async function parseReciterResponse(res: Response): Promise<any> {
  if (res.status === 204) return null;
  return parseJson(res);
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

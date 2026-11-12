// Thin optional proxy to an external Quran API (api.alquran.cloud).
// The mobile app talks to this provider directly in the MVP; this
// backend module exists so future features (caching, offline bundles,
// per-user last-read sync) have a natural home without UI changes.
import { AppError } from "../../utils/AppError";

const BASE_URL = "https://api.alquran.cloud/v1";
// A slow upstream must not hold API requests (and their sockets) open.
const TIMEOUT_MS = 10_000;

async function get(url: string, failure: string) {
  try {
    return await fetch(url, { signal: AbortSignal.timeout(TIMEOUT_MS) });
  } catch {
    throw new AppError(failure, 502);
  }
}

interface QuranApiResponse<T> {
  data: T;
}

export async function fetchSurahList() {
  const failure = "Unable to load Surah list right now.";
  const res = await get(`${BASE_URL}/surah`, failure);
  if (!res.ok) throw new AppError(failure, 502);
  const body = (await res.json()) as QuranApiResponse<unknown>;
  return body.data;
}

export async function fetchSurah(surahNumber: number) {
  const failure = "Unable to load this Surah right now.";
  const res = await get(`${BASE_URL}/surah/${surahNumber}/quran-uthmani`, failure);
  if (!res.ok) throw new AppError(failure, 502);
  const body = (await res.json()) as QuranApiResponse<unknown>;
  return body.data;
}

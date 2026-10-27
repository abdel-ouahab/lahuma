// Thin optional proxy to an external Quran API (api.alquran.cloud).
// The mobile app talks to this provider directly in the MVP; this
// backend module exists so future features (caching, offline bundles,
// per-user last-read sync) have a natural home without UI changes.
import { AppError } from "../../utils/AppError";

const BASE_URL = "https://api.alquran.cloud/v1";

interface QuranApiResponse<T> {
  data: T;
}

export async function fetchSurahList() {
  const res = await fetch(`${BASE_URL}/surah`);
  if (!res.ok) throw new AppError("Unable to load Surah list right now.", 502);
  const body = (await res.json()) as QuranApiResponse<unknown>;
  return body.data;
}

export async function fetchSurah(surahNumber: number) {
  const res = await fetch(`${BASE_URL}/surah/${surahNumber}/quran-uthmani`);
  if (!res.ok) throw new AppError("Unable to load this Surah right now.", 502);
  const body = (await res.json()) as QuranApiResponse<unknown>;
  return body.data;
}

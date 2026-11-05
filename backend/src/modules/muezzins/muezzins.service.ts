import { prisma } from "../../config/prisma";
import { env } from "../../config/env";

type MuezzinRow = {
  id: string;
  nameAr: string;
  nameFr: string;
  country: string;
  regularUrl: string;
  fajrUrl: string;
  regularShortUrl: string;
  fajrShortUrl: string;
  sortOrder: number;
  version: number;
};

/** A stored URL as the app should fetch it: absolute URLs pass through,
 *  "/adhan/…" is prefixed with [base]: MEDIA_BASE_URL, or the request's own
 *  origin when that is empty (see muezzins.controller.ts). */
export function resolveMediaUrl(url: string, base = env.mediaBaseUrl): string {
  if (!url.startsWith("/")) return url;
  return base.replace(/\/+$/, "") + url;
}

export function toDto(m: MuezzinRow, base = env.mediaBaseUrl) {
  return {
    id: m.id,
    nameAr: m.nameAr,
    nameFr: m.nameFr,
    country: m.country,
    regularUrl: resolveMediaUrl(m.regularUrl, base),
    fajrUrl: resolveMediaUrl(m.fajrUrl, base),
    regularShortUrl: resolveMediaUrl(m.regularShortUrl, base),
    fajrShortUrl: resolveMediaUrl(m.fajrShortUrl, base),
    sortOrder: m.sortOrder,
    version: m.version,
  };
}

export async function listActiveMuezzins(base = env.mediaBaseUrl) {
  const rows = await prisma.muezzin.findMany({
    where: { isActive: true },
    orderBy: [{ sortOrder: "asc" }, { createdAt: "asc" }],
  });
  return rows.map((m) => toDto(m, base));
}

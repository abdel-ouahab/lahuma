import fs from "fs";
import path from "path";

// prisma/data/muezzins.json: the muezzins and their source files, filled in
// by `npm run adhan:import` and read by the seed.

export const MANIFEST_PATH = path.join(__dirname, "../../../prisma/data/muezzins.json");

export type SourceKind = "regular" | "fajr";
export type OutputKind = "regular" | "fajr" | "regularShort" | "fajrShort";

export const OUTPUT_FILES: Record<OutputKind, string> = {
  regular: "regular.mp3",
  fajr: "fajr.mp3",
  regularShort: "regular_short.caf",
  fajrShort: "fajr_short.caf",
};

export type SourceInfo = {
  file: string;
  sha256: string;
  bytes: number;
  durationSec: number;
  bitRate: number;
  sampleRate: number;
  channels: number;
  codec: string;
};
export type OutputInfo = { path: string; sha256: string; bytes: number; durationSec: number };

export type ManifestRow = {
  slug: string;
  id: string;
  nameAr: string;
  nameFr: string;
  country: string;
  sortOrder: number;
  version: number;
  isActive: boolean;
  allowShort?: boolean;
  source: { repo: string; commit: string; regularFile: string; fajrFile: string };
  // Written by the import script:
  status?: "ok" | "short" | "failed";
  warnings?: string[];
  pipeline?: string;
  sources?: Partial<Record<SourceKind, SourceInfo>>;
  outputs?: Partial<Record<OutputKind, OutputInfo>>;
};

export type Manifest = { $comment?: string; muezzins: ManifestRow[] };

export function loadManifest(file = MANIFEST_PATH): Manifest {
  return JSON.parse(fs.readFileSync(file, "utf8"));
}

/** Whether the import produced every file and the checks passed. */
export function isPublishable(row: ManifestRow): boolean {
  const complete = (Object.keys(OUTPUT_FILES) as OutputKind[]).every((k) => row.outputs?.[k]?.path);
  return row.status === "ok" && complete;
}

/** The Muezzin rows the seed upserts. Paths stay relative ("/adhan/…");
 *  the API prefixes them with MEDIA_BASE_URL. A row that failed the import
 *  is kept but inactive, so an app that selected it keeps a valid id. */
export function seedRows(manifest: Manifest) {
  return manifest.muezzins.map((m) => {
    const url = (k: OutputKind) =>
      m.outputs?.[k]?.path ?? `/adhan/${m.slug}/v${m.version}/${OUTPUT_FILES[k]}`;
    return {
      id: m.id,
      data: {
        nameAr: m.nameAr,
        nameFr: m.nameFr,
        country: m.country,
        regularUrl: url("regular"),
        fajrUrl: url("fajr"),
        regularShortUrl: url("regularShort"),
        fajrShortUrl: url("fajrShort"),
        isActive: m.isActive && isPublishable(m),
        sortOrder: m.sortOrder,
        version: m.version,
      },
    };
  });
}

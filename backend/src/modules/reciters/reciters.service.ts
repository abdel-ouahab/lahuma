import fs from "fs";
import path from "path";
import { prisma } from "../../config/prisma";
import { AppError } from "../../utils/AppError";

export const AUDIO_ROOT = path.join(__dirname, "../../../public/audio");
export const RECITERS_DIR = "Quran reciters";

export function slugify(name: string): string {
  return name
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");
}

export function surahFileName(surahNumber: number, ext: string): string {
  return `${String(surahNumber).padStart(3, "0")}${ext}`;
}

const include = { surahs: { select: { surahNumber: true, audioPath: true } } };

type ReciterRow = {
  id: string;
  name: string;
  nameAr: string | null;
  slug: string;
  createdAt: Date;
  surahs: { surahNumber: number; audioPath: string | null }[];
};

function toDto(r: ReciterRow) {
  const surahs = [...r.surahs]
    .sort((a, b) => a.surahNumber - b.surahNumber)
    .map((s) => ({
      surahNumber: s.surahNumber,
      audioUrl: s.audioPath
        ? "/audio/" + s.audioPath.split("/").map(encodeURIComponent).join("/")
        : null,
    }));
  return {
    id: r.id,
    name: r.name,
    nameAr: r.nameAr,
    slug: r.slug,
    createdAt: r.createdAt.toISOString(),
    uploadedCount: surahs.filter((s) => s.audioUrl).length,
    surahs,
  };
}

export async function listReciters() {
  const rows = await prisma.reciter.findMany({ orderBy: { createdAt: "desc" }, include });
  return rows.map(toDto);
}

export async function getReciter(id: string) {
  const row = await prisma.reciter.findUnique({ where: { id }, include });
  if (!row) throw new AppError("Reciter not found.", 404);
  return toDto(row);
}

export async function createReciter(name: string, nameAr?: string) {
  const slug = slugify(name);
  if (!slug) throw new AppError("Reciter name must contain latin letters or digits.", 400);
  if (await prisma.reciter.findUnique({ where: { slug } })) {
    throw new AppError("A reciter with this name already exists.", 409);
  }
  const row = await prisma.reciter.create({
    data: {
      name,
      nameAr: nameAr || null,
      slug,
      surahs: {
        create: Array.from({ length: 114 }, (_, i) => ({ surahNumber: i + 1 })),
      },
    },
    include,
  });
  return toDto(row);
}

export async function deleteReciter(id: string) {
  const row = await prisma.reciter.findUnique({ where: { id } });
  if (!row) throw new AppError("Reciter not found.", 404);
  await prisma.reciter.delete({ where: { id } });
  await fs.promises.rm(path.join(AUDIO_ROOT, RECITERS_DIR, row.slug), {
    recursive: true,
    force: true,
  });
}

export async function attachAudio(reciterId: string, surahNumber: number, audioPath: string) {
  await prisma.reciterSurah.update({
    where: { reciterId_surahNumber: { reciterId, surahNumber } },
    data: { audioPath },
  });
}

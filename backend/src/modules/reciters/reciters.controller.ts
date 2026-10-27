import { NextFunction, Request, Response } from "express";
import fs from "fs";
import path from "path";
import multer from "multer";
import { z } from "zod";
import { prisma } from "../../config/prisma";
import { AppError } from "../../utils/AppError";
import * as service from "./reciters.service";

const ALLOWED_EXT = new Set([".mp3", ".wav", ".m4a", ".ogg"]);

const createSchema = z.object({
  name: z.string().trim().min(2).max(100),
  nameAr: z.string().trim().max(100).optional(),
});

function parseSurah(value: string): number {
  const n = Number(value);
  if (!Number.isInteger(n) || n < 1 || n > 114) throw new AppError("Invalid Surah number.", 400);
  return n;
}

export async function list(_req: Request, res: Response, next: NextFunction) {
  try {
    res.json({ reciters: await service.listReciters() });
  } catch (err) {
    next(err);
  }
}

export async function get(req: Request, res: Response, next: NextFunction) {
  try {
    res.json({ reciter: await service.getReciter(req.params.id) });
  } catch (err) {
    next(err);
  }
}

export async function create(req: Request, res: Response, next: NextFunction) {
  try {
    const parsed = createSchema.safeParse(req.body);
    if (!parsed.success) throw new AppError("Name is required (2-100 characters).", 400);
    res.status(201).json({ reciter: await service.createReciter(parsed.data.name, parsed.data.nameAr) });
  } catch (err) {
    next(err);
  }
}

export async function remove(req: Request, res: Response, next: NextFunction) {
  try {
    await service.deleteReciter(req.params.id);
    res.status(204).end();
  } catch (err) {
    next(err);
  }
}

// Uploads land under a temp name and are moved to <slug>/NNN.ext once the
// reciter and Surah number have been validated.
const upload = multer({
  dest: path.join(service.AUDIO_ROOT, ".tmp"),
  limits: { fileSize: 300 * 1024 * 1024, files: 1 },
}).single("audio");

export function uploadAudio(req: Request, res: Response, next: NextFunction) {
  upload(req, res, async (uploadErr) => {
    const file = req.file;
    try {
      if (uploadErr) {
        throw new AppError(
          uploadErr instanceof multer.MulterError && uploadErr.code === "LIMIT_FILE_SIZE"
            ? "File is too large (max 300MB)."
            : "Upload failed.",
          400
        );
      }
      if (!file) throw new AppError("Audio file is required.", 400);

      const surahNumber = parseSurah(req.params.number);
      const ext = path.extname(file.originalname).toLowerCase();
      if (!ALLOWED_EXT.has(ext)) throw new AppError("Unsupported audio format.", 400);

      const reciter = await prisma.reciter.findUnique({ where: { id: req.params.id } });
      if (!reciter) throw new AppError("Reciter not found.", 404);

      const dir = path.join(service.AUDIO_ROOT, service.RECITERS_DIR, reciter.slug);
      await fs.promises.mkdir(dir, { recursive: true });

      // Remove any previous recording for this Surah (extension may differ).
      const prefix = service.surahFileName(surahNumber, "");
      for (const existing of await fs.promises.readdir(dir)) {
        if (path.parse(existing).name === prefix) await fs.promises.rm(path.join(dir, existing));
      }

      const fileName = service.surahFileName(surahNumber, ext);
      await fs.promises.rename(file.path, path.join(dir, fileName));
      await service.attachAudio(
        reciter.id,
        surahNumber,
        `${service.RECITERS_DIR}/${reciter.slug}/${fileName}`
      );

      res.json({ reciter: await service.getReciter(reciter.id) });
    } catch (err) {
      if (file) await fs.promises.rm(file.path, { force: true });
      next(err);
    }
  });
}

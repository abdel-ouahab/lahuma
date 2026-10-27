import { Request, Response, NextFunction } from "express";
import * as quranService from "./quran.service";
import { AppError } from "../../utils/AppError";

export async function listSurahs(_req: Request, res: Response, next: NextFunction) {
  try {
    res.json(await quranService.fetchSurahList());
  } catch (err) {
    next(err);
  }
}

export async function getSurah(req: Request, res: Response, next: NextFunction) {
  try {
    const surahNumber = Number(req.params.number);
    if (!Number.isInteger(surahNumber) || surahNumber < 1 || surahNumber > 114) {
      throw new AppError("Invalid Surah number.", 400);
    }
    res.json(await quranService.fetchSurah(surahNumber));
  } catch (err) {
    next(err);
  }
}

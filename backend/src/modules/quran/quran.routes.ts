import { Router } from "express";
import * as quranController from "./quran.controller";

// No auth required — Quran reading must work as a guest.
const router = Router();

router.get("/surahs", quranController.listSurahs);
router.get("/surahs/:number", quranController.getSurah);

export default router;

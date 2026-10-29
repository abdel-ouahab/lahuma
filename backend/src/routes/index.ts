import { Router } from "express";
import authRoutes from "../modules/auth/auth.routes";
import muezzinsRoutes from "../modules/muezzins/muezzins.routes";
import quranRoutes from "../modules/quran/quran.routes";
import recitersRoutes from "../modules/reciters/reciters.routes";
import usersRoutes from "../modules/users/users.routes";

const router = Router();

router.use("/auth", authRoutes);
router.use("/muezzins", muezzinsRoutes);
router.use("/quran", quranRoutes);
router.use("/reciters", recitersRoutes);
router.use("/users", usersRoutes);

export default router;

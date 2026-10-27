import { Router } from "express";
import * as authController from "./auth.controller";
import { requireAuth } from "../../middleware/auth";
import { authRateLimiter } from "../../middleware/rateLimiter";

const router = Router();

router.post("/register", authRateLimiter, authController.register);
router.post("/login", authRateLimiter, authController.login);
router.get("/me", requireAuth, authController.me);

export default router;

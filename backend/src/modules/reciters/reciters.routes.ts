import { Router } from "express";
import { requireAdmin, requireAuth } from "../../middleware/auth";
import * as controller from "./reciters.controller";

const router = Router();

// Public: the mobile app lists reciters and plays their audio as a guest.
router.get("/", controller.list);
router.get("/:id", controller.get);

// Admin only.
router.post("/", requireAuth, requireAdmin, controller.create);
router.delete("/:id", requireAuth, requireAdmin, controller.remove);
router.put("/:id/surahs/:number/audio", requireAuth, requireAdmin, controller.uploadAudio);

export default router;

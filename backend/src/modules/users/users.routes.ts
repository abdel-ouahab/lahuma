import { Router } from "express";
import { requireAdmin, requireAuth } from "../../middleware/auth";
import * as usersController from "./users.controller";

// User management is for admins only.
const router = Router();

router.get("/", requireAuth, requireAdmin, usersController.listUsers);
router.post("/", requireAuth, requireAdmin, usersController.createUser);

export default router;


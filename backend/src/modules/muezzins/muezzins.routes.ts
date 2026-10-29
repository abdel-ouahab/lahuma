import { Router } from "express";
import * as controller from "./muezzins.controller";

const router = Router();

// Public: the mobile app lists muezzins as a guest and caches the result.
router.get("/", controller.list);

export default router;

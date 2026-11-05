import { NextFunction, Request, Response } from "express";
import { env } from "../../config/env";
import * as service from "./muezzins.service";

export async function list(req: Request, res: Response, next: NextFunction) {
  try {
    // Without MEDIA_BASE_URL the files are this server's own /adhan route,
    // at the origin the app reached it on (10.0.2.2, a LAN IP, …).
    const base = env.mediaBaseUrl || `${req.protocol}://${req.get("host")}`;
    res.json({ muezzins: await service.listActiveMuezzins(base) });
  } catch (err) {
    next(err);
  }
}

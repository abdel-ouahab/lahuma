import { NextFunction, Request, Response } from "express";
import * as service from "./muezzins.service";

export async function list(_req: Request, res: Response, next: NextFunction) {
  try {
    res.json({ muezzins: await service.listActiveMuezzins() });
  } catch (err) {
    next(err);
  }
}

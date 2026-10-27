import { NextFunction, Request, Response } from "express";
import jwt from "jsonwebtoken";
import { env } from "../config/env";
import { prisma } from "../config/prisma";
import { AppError } from "../utils/AppError";

export interface AuthedRequest extends Request {
  userId?: string;
}

// Quran browsing/reading never requires this middleware — it is only
// applied to routes that need an authenticated user (e.g. GET /auth/me).
export function requireAuth(req: AuthedRequest, _res: Response, next: NextFunction) {
  const header = req.headers.authorization;
  if (!header?.startsWith("Bearer ")) {
    return next(new AppError("Authentication required.", 401));
  }

  try {
    const token = header.slice("Bearer ".length);
    const payload = jwt.verify(token, env.jwtSecret) as { sub: string };
    req.userId = payload.sub;
    next();
  } catch {
    next(new AppError("Invalid or expired session.", 401));
  }
}

// Admin-panel routes only. Use after requireAuth. The role is read from the
// database on each request, so promoting or demoting a user takes effect
// without waiting for their token to expire.
export async function requireAdmin(req: AuthedRequest, _res: Response, next: NextFunction) {
  try {
    const user = req.userId
      ? await prisma.user.findUnique({ where: { id: req.userId }, select: { role: true } })
      : null;
    if (user?.role !== "ADMIN") {
      return next(new AppError("Admin access required.", 403));
    }
    next();
  } catch (err) {
    next(err);
  }
}

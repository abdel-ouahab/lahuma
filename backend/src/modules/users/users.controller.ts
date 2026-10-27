import { Response, NextFunction } from "express";
import { Role } from "@prisma/client";
import bcrypt from "bcryptjs";
import { AuthedRequest } from "../../middleware/auth";
import { prisma } from "../../config/prisma";
import { AppError } from "../../utils/AppError";

/**
 * GET /api/users
 * Returns all users from the database.
 * Protected by requireAuth + requireAdmin.
 */
export async function listUsers(
  _req: AuthedRequest,
  res: Response,
  next: NextFunction
) {
  try {
    const users = await prisma.user.findMany({
      orderBy: { createdAt: "desc" },
      select: {
        id: true,
        email: true,
        name: true,
        role: true,
        createdAt: true,
        updatedAt: true,
      },
    });

    // Map to the client-expected shape
    const mapped = users.map((u) => ({
      id: u.id,
      email: u.email,
      name: u.name,
      role: u.role,
      status: "ACTIVE" as const,
      createdAt: u.createdAt.toISOString(),
      lastLoginAt: u.updatedAt.toISOString(),
    }));

    res.json({ users: mapped });
  } catch (err) {
    next(err);
  }
}

/**
 * POST /api/users
 * Creates a new user in the database.
 * Protected by requireAuth + requireAdmin.
 */
export async function createUser(
  req: AuthedRequest,
  res: Response,
  next: NextFunction
) {
  try {
    const { email, name, password, role } = req.body;
    if (!email || !name) {
      throw new AppError("Email and name are required.", 400);
    }

    const existing = await prisma.user.findUnique({ where: { email } });
    if (existing) {
      throw new AppError("A user with this email address already exists.", 409);
    }

    if (role !== undefined && !Object.values(Role).includes(role)) {
      throw new AppError("Unknown role.", 400);
    }

    const passwordHash = await bcrypt.hash(password || "LahumaUser123!", 12);
    const user = await prisma.user.create({
      data: {
        email,
        name,
        passwordHash,
        role: role ?? Role.USER,
      },
    });

    res.status(201).json({
      user: {
        id: user.id,
        email: user.email,
        name: user.name,
        role: user.role,
        status: "ACTIVE",
        createdAt: user.createdAt.toISOString(),
        lastLoginAt: user.updatedAt.toISOString(),
      },
    });
  } catch (err) {
    next(err);
  }
}


import { Response, NextFunction } from "express";
import { registerSchema, loginSchema } from "./auth.schema";
import * as authService from "./auth.service";
import { AuthedRequest } from "../../middleware/auth";

export async function register(req: AuthedRequest, res: Response, next: NextFunction) {
  try {
    const input = registerSchema.parse(req.body);
    const result = await authService.registerUser(input);
    res.status(201).json(result);
  } catch (err) {
    next(err);
  }
}

export async function login(req: AuthedRequest, res: Response, next: NextFunction) {
  try {
    const input = loginSchema.parse(req.body);
    const result = await authService.loginUser(input);
    res.status(200).json(result);
  } catch (err) {
    next(err);
  }
}

export async function me(req: AuthedRequest, res: Response, next: NextFunction) {
  try {
    const user = await authService.getCurrentUser(req.userId as string);
    res.status(200).json({ user });
  } catch (err) {
    next(err);
  }
}

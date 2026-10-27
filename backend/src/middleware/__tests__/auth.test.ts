import jwt from "jsonwebtoken";
import { AppError } from "../../utils/AppError";

jest.mock("../../config/env", () => ({ env: { jwtSecret: "test-secret" } }));
jest.mock("../../config/prisma", () => ({
  prisma: { user: { findUnique: jest.fn() } },
}));

import { prisma } from "../../config/prisma";
import { AuthedRequest, requireAdmin, requireAuth } from "../auth";

const findUnique = prisma.user.findUnique as jest.Mock;

function run(
  middleware: (req: AuthedRequest, res: any, next: (err?: unknown) => void) => unknown,
  req: Partial<AuthedRequest>
): Promise<unknown> {
  return new Promise((resolve) => {
    middleware(req as AuthedRequest, {}, (err?: unknown) => resolve(err));
  });
}

describe("requireAuth", () => {
  it("rejects a request without a token", async () => {
    const err = await run(requireAuth, { headers: {} });
    expect(err).toBeInstanceOf(AppError);
    expect((err as AppError).statusCode).toBe(401);
  });

  it("accepts a valid token and sets the user id", async () => {
    const token = jwt.sign({ sub: "u1" }, "test-secret");
    const req: Partial<AuthedRequest> = { headers: { authorization: `Bearer ${token}` } };
    const err = await run(requireAuth, req);
    expect(err).toBeUndefined();
    expect(req.userId).toBe("u1");
  });
});

describe("requireAdmin", () => {
  beforeEach(() => findUnique.mockReset());

  it("lets an admin through", async () => {
    findUnique.mockResolvedValue({ role: "ADMIN" });
    expect(await run(requireAdmin, { userId: "u1" })).toBeUndefined();
    expect(findUnique).toHaveBeenCalledWith({ where: { id: "u1" }, select: { role: true } });
  });

  it.each(["USER", "MODERATOR"])("refuses a %s with 403", async (role) => {
    findUnique.mockResolvedValue({ role });
    const err = await run(requireAdmin, { userId: "u1" });
    expect((err as AppError).statusCode).toBe(403);
  });

  it("refuses a deleted account", async () => {
    findUnique.mockResolvedValue(null);
    const err = await run(requireAdmin, { userId: "gone" });
    expect((err as AppError).statusCode).toBe(403);
  });

  it("refuses when requireAuth did not run", async () => {
    const err = await run(requireAdmin, {});
    expect((err as AppError).statusCode).toBe(403);
    expect(findUnique).not.toHaveBeenCalled();
  });
});

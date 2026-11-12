import request from "supertest";

const mockUser = { findFirst: jest.fn(), findUnique: jest.fn(), create: jest.fn(), findMany: jest.fn() };
jest.mock("../../../config/prisma", () => ({ prisma: { user: mockUser } }));
jest.mock("../../../config/env", () => ({
  env: { mediaBaseUrl: "", corsOrigin: "*", jwtSecret: "test-secret", jwtExpiresIn: "1h", trustProxy: 0 },
}));

import jwt from "jsonwebtoken";
import { createApp } from "../../../app";

beforeEach(() => jest.resetAllMocks());

describe("POST /api/auth/register", () => {
  it("answers 400 with the problem for an invalid body, not 500", async () => {
    const res = await request(createApp())
      .post("/api/auth/register")
      .send({ email: "not-an-email", password: "longenough", name: "A" })
      .expect(400);
    expect(res.body.error).toMatch(/valid email/i);
  });

  it("names a missing field", async () => {
    const res = await request(createApp()).post("/api/auth/register").send({ email: "a@b.co", name: "A" }).expect(400);
    expect(res.body.error).toMatch(/password/i);
  });

  it("stores the email lower-cased", async () => {
    mockUser.findFirst.mockResolvedValue(null);
    mockUser.create.mockImplementation(({ data }) => ({ id: "u1", role: "USER", createdAt: new Date(), ...data }));
    const res = await request(createApp())
      .post("/api/auth/register")
      .send({ email: "  Parent@Example.COM ", password: "longenough", name: "Parent" })
      .expect(201);
    expect(mockUser.create.mock.calls[0][0].data.email).toBe("parent@example.com");
    expect(res.body.user).not.toHaveProperty("passwordHash");
  });
});

describe("POST /api/auth/login", () => {
  it("matches the account whatever the case of the email", async () => {
    mockUser.findFirst.mockResolvedValue(null);
    await request(createApp()).post("/api/auth/login").send({ email: "A@B.co", password: "x" }).expect(401);
    expect(mockUser.findFirst.mock.calls[0][0].where.email).toEqual({ equals: "a@b.co", mode: "insensitive" });
  });
});

describe("POST /api/users (admin)", () => {
  const adminToken = () => jwt.sign({ sub: "admin" }, "test-secret");

  it("refers a user without a password back instead of using a default one", async () => {
    mockUser.findUnique.mockResolvedValue({ role: "ADMIN" });
    const res = await request(createApp())
      .post("/api/users")
      .set("Authorization", `Bearer ${adminToken()}`)
      .send({ email: "new@example.com", name: "New" })
      .expect(400);
    expect(res.body.error).toMatch(/password/i);
    expect(mockUser.create).not.toHaveBeenCalled();
  });

  it("rejects an unknown role", async () => {
    mockUser.findUnique.mockResolvedValue({ role: "ADMIN" });
    await request(createApp())
      .post("/api/users")
      .set("Authorization", `Bearer ${adminToken()}`)
      .send({ email: "new@example.com", name: "New", password: "longenough", role: "OWNER" })
      .expect(400);
  });

  it("is closed to non-admins", async () => {
    mockUser.findUnique.mockResolvedValue({ role: "USER" });
    await request(createApp())
      .post("/api/users")
      .set("Authorization", `Bearer ${adminToken()}`)
      .send({ email: "new@example.com", name: "New", password: "longenough" })
      .expect(403);
  });
});

describe("error handling", () => {
  it("answers 400 to malformed JSON", async () => {
    const res = await request(createApp())
      .post("/api/auth/login")
      .set("Content-Type", "application/json")
      .send("{not json")
      .expect(400);
    expect(res.body.error).toBe("Malformed request body.");
  });

  it("does not advertise Express", async () => {
    const res = await request(createApp()).get("/health").expect(200);
    expect(res.headers["x-powered-by"]).toBeUndefined();
  });
});

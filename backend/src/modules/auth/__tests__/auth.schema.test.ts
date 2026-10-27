import { registerSchema, loginSchema } from "../auth.schema";

describe("auth schemas", () => {
  it("accepts a valid registration payload", () => {
    const result = registerSchema.safeParse({
      email: "parent@example.com",
      password: "strongpassword",
      name: "Parent",
    });
    expect(result.success).toBe(true);
  });

  it("rejects a short password", () => {
    const result = registerSchema.safeParse({
      email: "parent@example.com",
      password: "short",
      name: "Parent",
    });
    expect(result.success).toBe(false);
  });

  it("rejects an invalid email on login", () => {
    const result = loginSchema.safeParse({ email: "not-an-email", password: "x" });
    expect(result.success).toBe(false);
  });
});

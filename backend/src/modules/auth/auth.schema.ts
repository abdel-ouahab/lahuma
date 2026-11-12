import { z } from "zod";

// Emails are compared case-insensitively: "Parent@Example.com" at sign-up
// and "parent@example.com" at login are the same account.
export const emailSchema = z.string().trim().toLowerCase().email("Enter a valid email address.").max(254);

export const passwordSchema = z
  .string()
  .min(8, "Password must be at least 8 characters.")
  // bcrypt only uses the first 72 bytes.
  .max(72, "Password must be at most 72 characters.");

export const registerSchema = z.object({
  email: emailSchema,
  password: passwordSchema,
  name: z.string().trim().min(1, "Name is required.").max(100),
});

export const loginSchema = z.object({
  email: emailSchema,
  password: z.string().min(1, "Password is required.").max(200),
});

export type RegisterInput = z.infer<typeof registerSchema>;
export type LoginInput = z.infer<typeof loginSchema>;

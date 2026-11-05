import dotenv from "dotenv";
dotenv.config();

function required(name: string, fallback?: string): string {
  const value = process.env[name] ?? fallback;
  if (value === undefined) {
    throw new Error(`Missing required environment variable: ${name}`);
  }
  return value;
}

const nodeEnv = process.env.NODE_ENV ?? "development";
const jwtSecret = required("JWT_SECRET");

// A production server signing tokens with the example secret (or a short
// one) lets anyone forge an admin token, so refuse to start.
if (nodeEnv === "production" && (jwtSecret === "change-me-in-production" || jwtSecret.length < 32)) {
  throw new Error("JWT_SECRET must be a random string of at least 32 characters in production (openssl rand -hex 32).");
}

export const env = {
  port: Number(process.env.PORT ?? 4000),
  nodeEnv,
  databaseUrl: required("DATABASE_URL"),
  jwtSecret,
  // Reverse-proxy hops in front of the API (1 behind Caddy). Makes
  // req.ip (rate limiting) and req.protocol come from X-Forwarded-*.
  trustProxy: Number(process.env.TRUST_PROXY ?? 0),
  jwtExpiresIn: process.env.JWT_EXPIRES_IN ?? "7d",
  corsOrigin: process.env.CORS_ORIGIN ?? "*",
  // Public origin of the adhan audio; empty means this server's own origin.
  mediaBaseUrl: process.env.MEDIA_BASE_URL ?? "",
};

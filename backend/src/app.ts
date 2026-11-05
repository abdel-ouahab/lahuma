import express from "express";
import cors from "cors";
import path from "path";
import { env } from "./config/env";
import router from "./routes";
import { errorHandler } from "./middleware/errorHandler";

const PUBLIC_DIR = path.join(__dirname, "../public");

const ADHAN_TYPES: Record<string, string> = {
  ".mp3": "audio/mpeg",
  ".caf": "audio/x-caf",
  ".wav": "audio/wav",
};

export function createApp({ adhanDir = path.join(PUBLIC_DIR, "adhan") } = {}) {
  const app = express();
  if (env.trustProxy > 0) app.set("trust proxy", env.trustProxy);

  app.use(cors({ origin: env.corsOrigin }));
  app.use(express.json());

  // Serve public static assets (audio files, media, uploads)
  app.use("/public", express.static(PUBLIC_DIR));
  app.use("/audio", express.static(path.join(PUBLIC_DIR, "audio")));
  // Muezzin files from `npm run adhan:import`. Paths carry the version
  // (/adhan/<slug>/v<n>/…), so a file never changes under its URL.
  app.use(
    "/adhan",
    express.static(adhanDir, {
      maxAge: "30d",
      immutable: true,
      setHeaders: (res, file) => {
        const type = ADHAN_TYPES[path.extname(file).toLowerCase()];
        if (type) res.setHeader("Content-Type", type);
      },
    })
  );

  app.get("/health", (_req, res) => res.json({ status: "ok" }));
  app.use("/api", router);

  app.use(errorHandler);
  return app;
}

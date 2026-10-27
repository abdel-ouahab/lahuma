import express from "express";
import cors from "cors";
import path from "path";
import { env } from "./config/env";
import router from "./routes";
import { errorHandler } from "./middleware/errorHandler";

const app = express();

app.use(cors({ origin: env.corsOrigin }));
app.use(express.json());

// Serve public static assets (audio files, media, uploads)
app.use("/public", express.static(path.join(__dirname, "../public")));
app.use("/audio", express.static(path.join(__dirname, "../public/audio")));

app.get("/health", (_req, res) => res.json({ status: "ok" }));
app.use("/api", router);

app.use(errorHandler);

app.listen(env.port, () => {
  console.log(`Lahuma backend listening on port ${env.port}`);
});

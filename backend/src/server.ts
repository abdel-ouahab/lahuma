import { env } from "./config/env";
import { prisma } from "./config/prisma";
import { createApp } from "./app";

const server = createApp().listen(env.port, () => {
  console.log(`Lahuma backend listening on port ${env.port}`);
});

// `docker stop` sends SIGTERM. Node running as PID 1 has no default handler
// for it, so without this the container is killed after the 10 s timeout,
// cutting off requests in flight. Finish them, close the pool, then exit.
function shutdown(signal: string) {
  console.log(`${signal} received, shutting down`);
  server.close(async () => {
    await prisma.$disconnect().catch(() => undefined);
    process.exit(0);
  });
  // Keep-alive connections can hold close() open; don't wait forever.
  setTimeout(() => process.exit(0), 8000).unref();
}

process.on("SIGTERM", () => shutdown("SIGTERM"));
process.on("SIGINT", () => shutdown("SIGINT"));

import { env } from "./config/env";
import { createApp } from "./app";

createApp().listen(env.port, () => {
  console.log(`Lahuma backend listening on port ${env.port}`);
});

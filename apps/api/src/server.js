import Fastify from "fastify";

import { registerAuth } from "./auth.js";
import health from "./routes/health.js";
import profile from "./routes/profile.js";
import ai from "./routes/ai.js";
import { pool } from "./db.js";

// Custom REST backend (ADR-0022): single Fastify process, talks straight to
// Postgres, static API-key auth, no RLS. Runs behind Caddy in the compose
// stack (see infra/).
const app = Fastify({
  logger: { level: process.env.LOG_LEVEL ?? "info" },
  trustProxy: true, // behind Caddy
});

registerAuth(app);

await app.register(health);
await app.register(profile);
await app.register(ai);

const port = Number(process.env.PORT ?? 8080);

app.addHook("onClose", async () => {
  await pool.end();
});

try {
  await app.listen({ port, host: "0.0.0.0" });
} catch (err) {
  app.log.error(err);
  process.exit(1);
}

for (const sig of ["SIGINT", "SIGTERM"]) {
  process.on(sig, () => app.close().then(() => process.exit(0)));
}

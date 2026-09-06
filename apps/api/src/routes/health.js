import { ping } from "../db.js";

// Public — no API key. Used by the spike ("è raggiungibile?") and by any
// load balancer / uptime check.
export default async function health(app) {
  app.get("/health", { config: { public: true } }, async (_req, reply) => {
    let db = false;
    try {
      db = await ping();
    } catch (err) {
      app.log.error({ err }, "db ping failed");
    }
    return reply.code(db ? 200 : 503).send({ status: db ? "ok" : "degraded", db });
  });
}

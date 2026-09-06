// Static API-key auth (ADR-0022): one bearer token, configured once on every
// client. No sessions, no JWT — the app is single-user and the only thing to
// protect is public access to the API.

export function registerAuth(app) {
  const expected = process.env.API_KEY;
  if (!expected) {
    app.log.warn("API_KEY not set — every authed request will be rejected");
  }

  app.decorateRequest("authed", false);

  app.addHook("onRequest", async (req, reply) => {
    if (req.routeOptions?.config?.public) return;

    const header = req.headers.authorization ?? "";
    const token = header.startsWith("Bearer ") ? header.slice(7) : null;

    if (!expected || !token || !timingSafeEqual(token, expected)) {
      return reply.code(401).send({ error: "unauthorized" });
    }
    req.authed = true;
  });
}

// Constant-time compare to avoid leaking the key length/prefix via timing.
function timingSafeEqual(a, b) {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

import { pool } from "../db.js";

// Body Measurement (glossario, ADR-0012): peso opzionale + misure a nastro
// in un jsonb a chiavi libere. Foto rimandate (niente Storage, ADR-0022).
// Client-supplied UUID + upsert per l'outbox (ADR-0006).
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

async function profileId(c) {
  const f = await c.query("select id from profiles order by created_at asc limit 1");
  if (f.rows[0]) return f.rows[0].id;
  const i = await c.query("insert into profiles default values returning id");
  return i.rows[0].id;
}

export default async function measurements(app) {
  app.get("/v1/body-measurements", async (_req, reply) => {
    const { rows } = await pool.query(
      `select id, recorded_at, weight_kg, measurements
       from body_measurements order by recorded_at desc limit 200`,
    );
    return reply.send(rows);
  });

  app.post("/v1/body-measurements", async (req, reply) => {
    const b = req.body ?? {};
    if (!UUID_RE.test(String(b.id ?? ""))) {
      return reply.code(400).send({ error: "id deve essere un UUID" });
    }
    const weight = b.weightKg == null ? null : Number(b.weightKg);
    if (weight != null && (!Number.isFinite(weight) || weight <= 0 || weight > 500)) {
      return reply.code(400).send({ error: "weightKg ∈ (0,500]" });
    }
    // misure: solo numeri finiti > 0, chiavi non vuote
    const src = (b.measurements && typeof b.measurements === "object") ? b.measurements : {};
    const measurements = {};
    for (const [k, v] of Object.entries(src)) {
      const n = Number(v);
      if (k.trim() && Number.isFinite(n) && n > 0) measurements[k.trim()] = n;
    }
    if (weight == null && Object.keys(measurements).length === 0) {
      return reply.code(400).send({ error: "serve almeno il peso o una misura" });
    }
    const recordedAt = b.recordedAt ?? null;

    const c = await pool.connect();
    try {
      const uid = await profileId(c);
      const { rows } = await c.query(
        `insert into body_measurements (id, user_id, recorded_at, weight_kg, measurements)
         values ($1, $2, coalesce($3::timestamptz, now()), $4, $5)
         on conflict (id) do update
           set recorded_at = excluded.recorded_at,
               weight_kg = excluded.weight_kg,
               measurements = excluded.measurements
         returning id, recorded_at, weight_kg, measurements`,
        [b.id, uid, recordedAt, weight, JSON.stringify(measurements)],
      );
      return reply.code(201).send(rows[0]);
    } finally {
      c.release();
    }
  });

  app.delete("/v1/body-measurements/:id", async (req, reply) => {
    if (!UUID_RE.test(String(req.params.id))) {
      return reply.code(400).send({ error: "id non è un UUID" });
    }
    await pool.query("delete from body_measurements where id = $1", [req.params.id]);
    return reply.code(204).send();
  });
}

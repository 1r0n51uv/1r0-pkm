import { pool } from "../db.js";

// Tracker semplici (ADR-0017 slice 4): acqua, integratori + spunte
// giornaliere, caffeina. Tutti separati dal log pasti. Client-supplied UUID
// + upsert per l'outbox (ADR-0006).
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

async function profileId(c) {
  const f = await c.query("select id from profiles order by created_at asc limit 1");
  if (f.rows[0]) return f.rows[0].id;
  const i = await c.query("insert into profiles default values returning id");
  return i.rows[0].id;
}
const num = (v) => (Number.isFinite(Number(v)) ? Number(v) : null);

export default async function trackers(app) {
  // ---- acqua -------------------------------------------------------------
  app.get("/v1/water-logs", async (_req, reply) => {
    const { rows } = await pool.query(
      `select id, logged_at, amount_ml from water_logs
       order by logged_at desc limit 400`,
    );
    return reply.send(rows);
  });

  app.post("/v1/water-logs", async (req, reply) => {
    const b = req.body ?? {};
    if (!UUID_RE.test(String(b.id ?? ""))) {
      return reply.code(400).send({ error: "id deve essere un UUID" });
    }
    const ml = num(b.amountMl);
    if (ml == null || ml <= 0 || ml > 5000) {
      return reply.code(400).send({ error: "amountMl ∈ (0,5000]" });
    }
    const c = await pool.connect();
    try {
      const uid = await profileId(c);
      const { rows } = await c.query(
        `insert into water_logs (id, user_id, logged_at, amount_ml)
         values ($1, $2, coalesce($3::timestamptz, now()), $4)
         on conflict (id) do update set
           logged_at = excluded.logged_at, amount_ml = excluded.amount_ml
         returning id, logged_at, amount_ml`,
        [b.id, uid, b.loggedAt ?? null, ml],
      );
      return reply.code(201).send(rows[0]);
    } finally {
      c.release();
    }
  });

  // ---- integratori -----------------------------------------------------
  app.get("/v1/supplements", async (_req, reply) => {
    const { rows } = await pool.query(
      `select id, name, dose_text, schedule_text, active, created_at
       from supplements order by active desc, created_at asc limit 200`,
    );
    return reply.send(rows);
  });

  app.post("/v1/supplements", async (req, reply) => {
    const b = req.body ?? {};
    if (!UUID_RE.test(String(b.id ?? ""))) {
      return reply.code(400).send({ error: "id deve essere un UUID" });
    }
    const name = typeof b.name === "string" ? b.name.trim() : "";
    if (!name) return reply.code(400).send({ error: "name richiesto" });
    const str = (v) => (typeof v === "string" && v.trim() ? v.trim() : null);
    const c = await pool.connect();
    try {
      const uid = await profileId(c);
      const { rows } = await c.query(
        `insert into supplements (id, user_id, name, dose_text, schedule_text, active)
         values ($1, $2, $3, $4, $5, $6)
         on conflict (id) do update set
           name = excluded.name, dose_text = excluded.dose_text,
           schedule_text = excluded.schedule_text, active = excluded.active
         returning id, name, dose_text, schedule_text, active, created_at`,
        [b.id, uid, name, str(b.doseText), str(b.scheduleText), b.active !== false],
      );
      return reply.code(201).send(rows[0]);
    } finally {
      c.release();
    }
  });

  app.delete("/v1/supplements/:id", async (req, reply) => {
    if (!UUID_RE.test(String(req.params.id))) {
      return reply.code(400).send({ error: "id non è un UUID" });
    }
    await pool.query("delete from supplements where id = $1", [req.params.id]);
    return reply.code(204).send();
  });

  // ---- spunte integratore --------------------------------------------
  app.get("/v1/supplement-logs", async (_req, reply) => {
    const { rows } = await pool.query(
      `select id, supplement_id, logged_at, taken from supplement_logs
       order by logged_at desc limit 800`,
    );
    return reply.send(rows);
  });

  app.post("/v1/supplement-logs", async (req, reply) => {
    const b = req.body ?? {};
    if (!UUID_RE.test(String(b.id ?? "")) || !UUID_RE.test(String(b.supplementId ?? ""))) {
      return reply.code(400).send({ error: "id e supplementId devono essere UUID" });
    }
    const c = await pool.connect();
    try {
      const uid = await profileId(c);
      const { rows } = await c.query(
        `insert into supplement_logs (id, user_id, supplement_id, logged_at, taken)
         values ($1, $2, $3, coalesce($4::timestamptz, now()), $5)
         on conflict (id) do update set
           logged_at = excluded.logged_at, taken = excluded.taken
         returning id, supplement_id, logged_at, taken`,
        [b.id, uid, b.supplementId, b.loggedAt ?? null, b.taken !== false],
      );
      return reply.code(201).send(rows[0]);
    } catch (err) {
      if (err.code === "23503") return reply.code(409).send({ error: "integratore inesistente" });
      throw err;
    } finally {
      c.release();
    }
  });

  // ---- caffeina -----------------------------------------------------
  app.get("/v1/caffeine-logs", async (_req, reply) => {
    const { rows } = await pool.query(
      `select id, logged_at, source_name, caffeine_mg from caffeine_logs
       order by logged_at desc limit 400`,
    );
    return reply.send(rows);
  });

  app.post("/v1/caffeine-logs", async (req, reply) => {
    const b = req.body ?? {};
    if (!UUID_RE.test(String(b.id ?? ""))) {
      return reply.code(400).send({ error: "id deve essere un UUID" });
    }
    const mg = num(b.caffeineMg);
    if (mg == null || mg < 0 || mg > 2000) {
      return reply.code(400).send({ error: "caffeineMg ∈ [0,2000]" });
    }
    const src = typeof b.sourceName === "string" && b.sourceName.trim()
      ? b.sourceName.trim() : "caffè";
    const c = await pool.connect();
    try {
      const uid = await profileId(c);
      const { rows } = await c.query(
        `insert into caffeine_logs (id, user_id, logged_at, source_name, caffeine_mg)
         values ($1, $2, coalesce($3::timestamptz, now()), $4, $5)
         on conflict (id) do update set
           logged_at = excluded.logged_at, source_name = excluded.source_name,
           caffeine_mg = excluded.caffeine_mg
         returning id, logged_at, source_name, caffeine_mg`,
        [b.id, uid, b.loggedAt ?? null, src, mg],
      );
      return reply.code(201).send(rows[0]);
    } finally {
      c.release();
    }
  });
}

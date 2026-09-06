import { pool } from "../db.js";

// Workout Session (glossario). status: active | paused | completed | cancelled
// (migration 0003). Client-supplied UUID + upsert per l'outbox (ADR-0006);
// user_id dal profilo single-user.
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const STATUS = ["active", "paused", "completed", "cancelled"];

async function profileId(c) {
  const f = await c.query("select id from profiles order by created_at asc limit 1");
  if (f.rows[0]) return f.rows[0].id;
  const i = await c.query("insert into profiles default values returning id");
  return i.rows[0].id;
}

export default async function sessions(app) {
  app.get("/v1/workout-sessions", async (_req, reply) => {
    const { rows } = await pool.query(
      `select ws.id, ws.status, ws.source, ws.started_at, ws.ended_at, ws.notes,
              count(sl.id)::int as set_count
       from workout_sessions ws
       left join set_logs sl on sl.workout_session_id = ws.id
       group by ws.id
       order by ws.started_at desc limit 50`,
    );
    return reply.send(rows);
  });

  app.post("/v1/workout-sessions", async (req, reply) => {
    const b = req.body ?? {};
    if (b.id != null && !UUID_RE.test(String(b.id))) {
      return reply.code(400).send({ error: "id non è un UUID" });
    }
    const source = b.source === "watch" ? "watch" : "app";
    const notes = typeof b.notes === "string" && b.notes.trim() ? b.notes.trim() : null;

    const c = await pool.connect();
    try {
      const uid = await profileId(c);
      const { rows } = await c.query(
        `insert into workout_sessions (id, user_id, source, notes, status)
         values (coalesce($1, gen_random_uuid()), $2, $3, $4, 'active')
         on conflict (id) do update set notes = excluded.notes
         returning id, status, source, started_at, ended_at, notes`,
        [b.id ?? null, uid, source, notes],
      );
      return reply.code(201).send(rows[0]);
    } finally {
      c.release();
    }
  });

  app.patch("/v1/workout-sessions/:id", async (req, reply) => {
    const id = req.params.id;
    if (!UUID_RE.test(String(id))) {
      return reply.code(400).send({ error: "id non è un UUID" });
    }
    const b = req.body ?? {};
    if (b.status != null && !STATUS.includes(b.status)) {
      return reply.code(400).send({ error: `status ∉ ${STATUS.join("|")}` });
    }
    // terminale ⇒ ended_at ora, se non passato esplicitamente
    const endsNow = b.status === "completed" || b.status === "cancelled";
    const { rows } = await pool.query(
      `update workout_sessions
         set status   = coalesce($2, status),
             notes    = coalesce($3, notes),
             ended_at = coalesce($4::timestamptz, case when $5 then now() else ended_at end)
       where id = $1
       returning id, status, source, started_at, ended_at, notes`,
      [id, b.status ?? null, b.notes ?? null, b.endedAt ?? null, endsNow],
    );
    if (rows.length === 0) return reply.code(404).send({ error: "sessione non trovata" });
    return reply.send(rows[0]);
  });
}

import { pool } from "../db.js";

// Routine = una scheda (glossario). Qui solo l'header + la fase (ADR-0015);
// giorni/esercizi arrivano dopo. Client-supplied UUID + upsert per l'outbox
// (ADR-0006). user_id: profilo single-user get-or-create.
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const PHASES = ["bulk", "cut", "deload", "maintenance"];

async function profileId(c) {
  const f = await c.query("select id from profiles order by created_at asc limit 1");
  if (f.rows[0]) return f.rows[0].id;
  const i = await c.query("insert into profiles default values returning id");
  return i.rows[0].id;
}

export default async function routines(app) {
  app.get("/v1/routines", async (_req, reply) => {
    const { rows } = await pool.query(
      `select id, name, phase, notes, created_at, updated_at
       from routines order by created_at desc`,
    );
    return reply.send(rows);
  });

  app.post("/v1/routines", async (req, reply) => {
    const b = req.body ?? {};
    const name = typeof b.name === "string" ? b.name.trim() : "";
    if (!name) return reply.code(400).send({ error: "name richiesto" });
    if (b.id != null && !UUID_RE.test(String(b.id))) {
      return reply.code(400).send({ error: "id non è un UUID" });
    }
    const phase = PHASES.includes(b.phase) ? b.phase : null;
    const notes = typeof b.notes === "string" && b.notes.trim() ? b.notes.trim() : null;

    const c = await pool.connect();
    try {
      const uid = await profileId(c);
      const { rows } = await c.query(
        `insert into routines (id, user_id, name, phase, notes)
         values (coalesce($1, gen_random_uuid()), $2, $3, $4, $5)
         on conflict (id) do update
           set name = excluded.name, phase = excluded.phase,
               notes = excluded.notes, updated_at = now()
         returning id, name, phase, notes, created_at, updated_at`,
        [b.id ?? null, uid, name, phase, notes],
      );
      return reply.code(201).send(rows[0]);
    } finally {
      c.release();
    }
  });
}

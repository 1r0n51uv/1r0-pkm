import { pool } from "../db.js";

// Import CSV Liftin' (ADR-0027 step 3). Batch upsert per UUID client:
// idempotente, il client è la fonte di verità e qui si tiene solo il backup
// ("la nostra copia"). Nessun FK verso `exercises`: l'esercizio è un nome.
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

async function profileId(c) {
  const f = await c.query("select id from profiles order by created_at asc limit 1");
  if (f.rows[0]) return f.rows[0].id;
  const i = await c.query("insert into profiles default values returning id");
  return i.rows[0].id;
}

export default async function workoutImport(app) {
  app.post("/v1/workout-import", async (req, reply) => {
    const sessions = Array.isArray(req.body?.sessions) ? req.body.sessions : null;
    if (!sessions) return reply.code(400).send({ error: "sessions[] richiesto" });

    const c = await pool.connect();
    try {
      const uid = await profileId(c);
      await c.query("begin");
      let ns = 0;
      let nsl = 0;
      for (const s of sessions) {
        if (!UUID_RE.test(String(s?.id))) {
          throw { code: "BAD", msg: `session id non è un UUID: ${s?.id}` };
        }
        await c.query(
          `insert into workout_sessions
             (id, user_id, source, started_at, routine_label, duration_seconds)
           values ($1, $2, $3, $4, $5, $6)
           on conflict (id) do update set
             source           = excluded.source,
             started_at       = excluded.started_at,
             routine_label    = excluded.routine_label,
             duration_seconds = excluded.duration_seconds`,
          [
            s.id,
            uid,
            typeof s.source === "string" && s.source ? s.source : "liftin",
            s.startedAt || null,
            s.routineLabel ?? null,
            Number.isInteger(s.durationSeconds) ? s.durationSeconds : null,
          ],
        );
        ns++;

        for (const e of Array.isArray(s.sets) ? s.sets : []) {
          if (!UUID_RE.test(String(e?.id))) {
            throw { code: "BAD", msg: `set id non è un UUID: ${e?.id}` };
          }
          await c.query(
            `insert into set_logs
               (id, workout_session_id, exercise_id, exercise_name, set_index,
                weight_kg, reps, duration_seconds, is_warmup, rpe, completed_at)
             values ($1, $2, null, $3, $4, $5, $6, $7, $8, $9, $10)
             on conflict (id) do update set
               exercise_name    = excluded.exercise_name,
               set_index        = excluded.set_index,
               weight_kg        = excluded.weight_kg,
               reps             = excluded.reps,
               duration_seconds = excluded.duration_seconds,
               is_warmup        = excluded.is_warmup,
               rpe              = excluded.rpe,
               completed_at     = excluded.completed_at`,
            [
              e.id,
              s.id,
              typeof e.exerciseName === "string" ? e.exerciseName : "",
              Number.isInteger(e.setIndex) ? e.setIndex : 1,
              Number.isFinite(Number(e.weightKg)) ? Number(e.weightKg) : 0,
              Number.isInteger(e.reps) ? e.reps : null,
              Number.isInteger(e.durationSeconds) ? e.durationSeconds : null,
              !!e.isWarmup,
              Number.isFinite(Number(e.rpe)) ? Number(e.rpe) : null,
              e.completedAt || s.startedAt || null,
            ],
          );
          nsl++;
        }
      }
      await c.query("commit");
      return reply.code(201).send({ sessions: ns, sets: nsl });
    } catch (err) {
      await c.query("rollback").catch(() => {});
      if (err?.code === "BAD") return reply.code(400).send({ error: err.msg });
      app.log.error({ err }, "workout-import fallito");
      return reply.code(500).send({ error: "import fallito" });
    } finally {
      c.release();
    }
  });
}

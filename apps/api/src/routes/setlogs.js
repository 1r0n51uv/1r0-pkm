import { pool } from "../db.js";

// End-to-end spike (issue #6): the Watch logs a set, the iPhone POSTs it here,
// it lands in Postgres. The client sends only { weightKg, reps }; this route
// fills the FK chain (profile -> exercise -> open workout_session -> set_log)
// so the spike stays about the transport, not about session management.
async function getOrCreateProfile(c) {
  const found = await c.query("select id from profiles order by created_at asc limit 1");
  if (found.rows[0]) return found.rows[0].id;
  const ins = await c.query("insert into profiles default values returning id");
  return ins.rows[0].id;
}

async function getOrCreateSpikeExercise(c) {
  const name = "Spike set";
  const found = await c.query("select id from exercises where name = $1 limit 1", [name]);
  if (found.rows[0]) return found.rows[0].id;
  const ins = await c.query(
    "insert into exercises (name, source) values ($1, 'custom') returning id",
    [name],
  );
  return ins.rows[0].id;
}

async function getOrCreateOpenSession(c, userId) {
  const found = await c.query(
    "select id from workout_sessions where user_id = $1 and ended_at is null order by started_at desc limit 1",
    [userId],
  );
  if (found.rows[0]) return found.rows[0].id;
  const ins = await c.query(
    "insert into workout_sessions (user_id, source) values ($1, 'watch') returning id",
    [userId],
  );
  return ins.rows[0].id;
}

export default async function setlogs(app) {
  app.post("/v1/set-logs", async (req, reply) => {
    const { weightKg, reps } = req.body ?? {};
    const w = Number(weightKg);
    const r = Number.parseInt(reps, 10);
    if (!Number.isFinite(w) || w <= 0 || !Number.isInteger(r) || r <= 0) {
      return reply.code(400).send({ error: "weightKg > 0 e reps intero > 0 richiesti" });
    }

    const c = await pool.connect();
    try {
      await c.query("begin");
      const userId = await getOrCreateProfile(c);
      const exerciseId = await getOrCreateSpikeExercise(c);
      const sessionId = await getOrCreateOpenSession(c, userId);

      const nextIdx = await c.query(
        "select coalesce(max(set_index), 0) + 1 as idx from set_logs where workout_session_id = $1 and exercise_id = $2",
        [sessionId, exerciseId],
      );
      const inserted = await c.query(
        `insert into set_logs (workout_session_id, exercise_id, set_index, weight_kg, reps)
         values ($1, $2, $3, $4, $5)
         returning id, workout_session_id, set_index, weight_kg, reps, completed_at`,
        [sessionId, exerciseId, nextIdx.rows[0].idx, w, r],
      );
      await c.query("commit");
      return reply.code(201).send(inserted.rows[0]);
    } catch (err) {
      await c.query("rollback");
      app.log.error({ err }, "insert set_log fallito");
      return reply.code(500).send({ error: "insert fallito" });
    } finally {
      c.release();
    }
  });

  app.get("/v1/set-logs", async (_req, reply) => {
    const { rows } = await pool.query(
      `select s.id, s.set_index, s.weight_kg, s.reps, s.completed_at,
              e.name as exercise, s.workout_session_id
       from set_logs s join exercises e on e.id = s.exercise_id
       order by s.completed_at desc limit 20`,
    );
    return reply.send(rows);
  });
}

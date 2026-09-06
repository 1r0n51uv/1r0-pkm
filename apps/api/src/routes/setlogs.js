import { pool } from "../db.js";

// Set Log (glossario): una serie loggata dentro una Workout Session, sempre
// modificabile/cancellabile. Client-supplied UUID + upsert (ADR-0006);
// sessione ed esercizio devono esistere (creati offline, flushati prima
// via outbox FIFO).
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export default async function setlogs(app) {
  app.get("/v1/set-logs", async (req, reply) => {
    const sid = req.query?.sessionId;
    if (sid && !UUID_RE.test(String(sid))) {
      return reply.code(400).send({ error: "sessionId non è un UUID" });
    }
    const { rows } = await pool.query(
      `select sl.id, sl.workout_session_id, sl.exercise_id, sl.set_index,
              sl.weight_kg, sl.reps, sl.rpe, sl.completed_at, e.name as exercise
       from set_logs sl join exercises e on e.id = sl.exercise_id
       ${sid ? "where sl.workout_session_id = $1" : ""}
       order by sl.completed_at asc ${sid ? "" : "limit 50"}`,
      sid ? [sid] : [],
    );
    return reply.send(rows);
  });

  app.post("/v1/set-logs", async (req, reply) => {
    const b = req.body ?? {};
    for (const [k, v] of [["id", b.id], ["sessionId", b.sessionId], ["exerciseId", b.exerciseId]]) {
      if (!UUID_RE.test(String(v ?? ""))) {
        return reply.code(400).send({ error: `${k} deve essere un UUID` });
      }
    }
    const w = Number(b.weightKg);
    const r = Number.parseInt(b.reps, 10);
    const idx = Number.parseInt(b.setIndex, 10);
    if (!Number.isFinite(w) || w < 0) return reply.code(400).send({ error: "weightKg >= 0" });
    if (!Number.isInteger(r) || r <= 0) return reply.code(400).send({ error: "reps intero > 0" });
    if (!Number.isInteger(idx) || idx <= 0) return reply.code(400).send({ error: "setIndex intero > 0" });
    const rpe = b.rpe == null ? null : Number(b.rpe);
    if (rpe != null && (!Number.isFinite(rpe) || rpe < 1 || rpe > 10)) {
      return reply.code(400).send({ error: "rpe ∈ [1,10]" });
    }

    try {
      const { rows } = await pool.query(
        `insert into set_logs (id, workout_session_id, exercise_id, set_index, weight_kg, reps, rpe)
         values ($1, $2, $3, $4, $5, $6, $7)
         on conflict (id) do update
           set weight_kg = excluded.weight_kg, reps = excluded.reps,
               rpe = excluded.rpe, set_index = excluded.set_index, updated_at = now()
         returning id, workout_session_id, exercise_id, set_index, weight_kg, reps, rpe, completed_at`,
        [b.id, b.sessionId, b.exerciseId, idx, w, r, rpe],
      );
      return reply.code(201).send(rows[0]);
    } catch (err) {
      if (err.code === "23503") {
        return reply.code(409).send({ error: "sessione o esercizio inesistente" });
      }
      app.log.error({ err }, "insert set_log fallito");
      return reply.code(500).send({ error: "insert fallito" });
    }
  });

  app.delete("/v1/set-logs/:id", async (req, reply) => {
    if (!UUID_RE.test(String(req.params.id))) {
      return reply.code(400).send({ error: "id non è un UUID" });
    }
    await pool.query("delete from set_logs where id = $1", [req.params.id]);
    return reply.code(204).send();
  });
}

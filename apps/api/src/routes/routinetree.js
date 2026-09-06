import { pool } from "../db.js";

// Routine Day / Routine Exercise (glossario). Client-supplied UUID + upsert
// per l'outbox (ADR-0006). Il "peso target" non è nello schema: la double
// progression (ADR-0011) parte dal peso realmente usato nell'ultima sessione.
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export default async function routineTree(app) {
  // Albero completo di una scheda.
  app.get("/v1/routines/:id/tree", async (req, reply) => {
    const rid = req.params.id;
    if (!UUID_RE.test(String(rid))) return reply.code(400).send({ error: "id non è un UUID" });

    const r = await pool.query(
      "select id, name, phase, notes from routines where id = $1", [rid],
    );
    if (r.rows.length === 0) return reply.code(404).send({ error: "scheda non trovata" });

    const days = await pool.query(
      "select id, name, order_index from routine_days where routine_id = $1 order by order_index, name",
      [rid],
    );
    const exs = await pool.query(
      `select re.id, re.routine_day_id, re.exercise_id, re.order_index,
              re.superset_group, re.target_sets, re.target_reps, re.target_rest_seconds,
              e.name as exercise_name
       from routine_exercises re
       join exercises e on e.id = re.exercise_id
       where re.routine_day_id = any($1::uuid[])
       order by re.order_index, e.name`,
      [days.rows.map((d) => d.id)],
    );
    return reply.send({
      ...r.rows[0],
      days: days.rows.map((d) => ({
        ...d,
        exercises: exs.rows.filter((x) => x.routine_day_id === d.id),
      })),
    });
  });

  app.post("/v1/routine-days", async (req, reply) => {
    const b = req.body ?? {};
    if (!UUID_RE.test(String(b.id ?? "")) || !UUID_RE.test(String(b.routineId ?? ""))) {
      return reply.code(400).send({ error: "id e routineId devono essere UUID" });
    }
    const name = typeof b.name === "string" ? b.name.trim() : "";
    if (!name) return reply.code(400).send({ error: "name richiesto" });
    const order = Number.isInteger(b.orderIndex) ? b.orderIndex : 0;
    try {
      const { rows } = await pool.query(
        `insert into routine_days (id, routine_id, name, order_index)
         values ($1, $2, $3, $4)
         on conflict (id) do update set name = excluded.name, order_index = excluded.order_index
         returning id, routine_id, name, order_index`,
        [b.id, b.routineId, name, order],
      );
      return reply.code(201).send(rows[0]);
    } catch (err) {
      if (err.code === "23503") return reply.code(409).send({ error: "scheda inesistente" });
      throw err;
    }
  });

  app.post("/v1/routine-exercises", async (req, reply) => {
    const b = req.body ?? {};
    for (const k of ["id", "routineDayId", "exerciseId"]) {
      if (!UUID_RE.test(String(b[k] ?? ""))) {
        return reply.code(400).send({ error: `${k} deve essere un UUID` });
      }
    }
    const sets = Number.isInteger(b.targetSets) && b.targetSets > 0 ? b.targetSets : 3;
    const reps = typeof b.targetReps === "string" && b.targetReps.trim() ? b.targetReps.trim() : "8-12";
    const rest = Number.isInteger(b.targetRestSeconds) && b.targetRestSeconds >= 0 ? b.targetRestSeconds : 90;
    const order = Number.isInteger(b.orderIndex) ? b.orderIndex : 0;
    const superset = typeof b.supersetGroup === "string" && b.supersetGroup.trim() ? b.supersetGroup.trim() : null;
    try {
      const { rows } = await pool.query(
        `insert into routine_exercises
           (id, routine_day_id, exercise_id, order_index, superset_group,
            target_sets, target_reps, target_rest_seconds)
         values ($1,$2,$3,$4,$5,$6,$7,$8)
         on conflict (id) do update set
           order_index = excluded.order_index, superset_group = excluded.superset_group,
           target_sets = excluded.target_sets, target_reps = excluded.target_reps,
           target_rest_seconds = excluded.target_rest_seconds
         returning id, routine_day_id, exercise_id, order_index, superset_group,
                   target_sets, target_reps, target_rest_seconds`,
        [b.id, b.routineDayId, b.exerciseId, order, superset, sets, reps, rest],
      );
      return reply.code(201).send(rows[0]);
    } catch (err) {
      if (err.code === "23503") return reply.code(409).send({ error: "giorno o esercizio inesistente" });
      throw err;
    }
  });

  app.delete("/v1/routine-days/:id", async (req, reply) => {
    if (!UUID_RE.test(String(req.params.id))) return reply.code(400).send({ error: "id non è un UUID" });
    await pool.query("delete from routine_days where id = $1", [req.params.id]);
    return reply.code(204).send();
  });
  app.delete("/v1/routine-exercises/:id", async (req, reply) => {
    if (!UUID_RE.test(String(req.params.id))) return reply.code(400).send({ error: "id non è un UUID" });
    await pool.query("delete from routine_exercises where id = $1", [req.params.id]);
    return reply.code(204).send();
  });
}

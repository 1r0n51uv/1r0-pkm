import { pool } from "../db.js";

// Exercise catalog (ADR-0005). For now only `custom` exercises created in the
// app; wger / AI import come later. The client may supply its own UUID `id`
// so an offline-created row keeps identity and the POST is idempotent
// (outbox pattern, ADR-0006).
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export default async function exercises(app) {
  app.get("/v1/exercises", async (_req, reply) => {
    const { rows } = await pool.query(
      `select id, name, source, muscle_groups, equipment, instructions, created_at
       from exercises order by created_at desc`,
    );
    return reply.send(rows);
  });

  app.post("/v1/exercises", async (req, reply) => {
    const body = req.body ?? {};
    const name = typeof body.name === "string" ? body.name.trim() : "";
    if (name.length === 0) {
      return reply.code(400).send({ error: "name richiesto" });
    }
    if (body.id != null && !UUID_RE.test(String(body.id))) {
      return reply.code(400).send({ error: "id non è un UUID" });
    }
    const muscleGroups = Array.isArray(body.muscleGroups)
      ? body.muscleGroups.filter((m) => typeof m === "string")
      : [];
    const equipment =
      typeof body.equipment === "string" && body.equipment.trim().length > 0
        ? body.equipment.trim()
        : null;

    const { rows } = await pool.query(
      `insert into exercises (id, name, source, muscle_groups, equipment)
       values (coalesce($1, gen_random_uuid()), $2, 'custom', $3, $4)
       on conflict (id) do update
         set name = excluded.name,
             muscle_groups = excluded.muscle_groups,
             equipment = excluded.equipment
       returning id, name, source, muscle_groups, equipment, instructions, created_at`,
      [body.id ?? null, name, muscleGroups, equipment],
    );
    return reply.code(201).send(rows[0]);
  });
}

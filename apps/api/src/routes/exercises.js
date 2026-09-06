import { pool } from "../db.js";

// Exercise catalog (ADR-0005). Three sources:
//  - 'custom'  exercises created by hand in the app
//  - 'wger'    imported from the wger public DB (see routes/wger.js)
//  - 'ai'      proposed by Claude, confirmed by the user before saving
// The client may supply its own UUID `id` so an offline-created row keeps
// identity and the POST is idempotent (outbox pattern, ADR-0006).
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const SOURCES = new Set(["custom", "wger", "ai"]);

export default async function exercises(app) {
  app.get("/v1/exercises", async (_req, reply) => {
    const { rows } = await pool.query(
      `select id, name, source, external_id, muscle_groups, equipment,
              instructions, video_url, image_url, created_at
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
    const source = SOURCES.has(body.source) ? body.source : "custom";
    if (body.source != null && !SOURCES.has(body.source)) {
      return reply.code(400).send({ error: "source non valido" });
    }
    const muscleGroups = Array.isArray(body.muscleGroups)
      ? body.muscleGroups.filter((m) => typeof m === "string")
      : [];
    const str = (v) =>
      typeof v === "string" && v.trim().length > 0 ? v.trim() : null;
    const equipment = str(body.equipment);
    const instructions = str(body.instructions);
    const videoUrl = str(body.videoUrl);
    const imageUrl = str(body.imageUrl);
    const externalId = str(body.externalId);

    const { rows } = await pool.query(
      `insert into exercises
         (id, name, source, external_id, muscle_groups, equipment, instructions, video_url, image_url)
       values (coalesce($1, gen_random_uuid()), $2, $3, $4, $5, $6, $7, $8, $9)
       on conflict (id) do update
         set name = excluded.name,
             source = excluded.source,
             external_id = excluded.external_id,
             muscle_groups = excluded.muscle_groups,
             equipment = excluded.equipment,
             instructions = excluded.instructions,
             video_url = excluded.video_url,
             image_url = excluded.image_url
       returning id, name, source, external_id, muscle_groups, equipment,
                 instructions, video_url, image_url, created_at`,
      [
        body.id ?? null,
        name,
        source,
        externalId,
        muscleGroups,
        equipment,
        instructions,
        videoUrl,
        imageUrl,
      ],
    );
    return reply.code(201).send(rows[0]);
  });
}

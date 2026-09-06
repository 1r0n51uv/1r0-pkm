import { pool } from "../db.js";

// Plate Set Config (glossario, migration 0002): una riga per utente —
// bilanciere + dischi realmente disponibili. Serve solo a leggere/scrivere
// la config; il calcolo piastre è client-side (ADR-0013).
async function profileId(c) {
  const f = await c.query("select id from profiles order by created_at asc limit 1");
  if (f.rows[0]) return f.rows[0].id;
  const i = await c.query("insert into profiles default values returning id");
  return i.rows[0].id;
}

export default async function plateConfig(app) {
  app.get("/v1/plate-config", async (_req, reply) => {
    const c = await pool.connect();
    try {
      const uid = await profileId(c);
      let { rows } = await c.query(
        "select bar_weight_kg, available_plates_kg from plate_set_configs where user_id = $1",
        [uid],
      );
      if (rows.length === 0) {
        rows = (await c.query(
          "insert into plate_set_configs (user_id) values ($1) returning bar_weight_kg, available_plates_kg",
          [uid],
        )).rows;
      }
      return reply.send(rows[0]);
    } finally {
      c.release();
    }
  });

  app.put("/v1/plate-config", async (req, reply) => {
    const b = req.body ?? {};
    const bar = Number(b.barWeightKg);
    if (!Number.isFinite(bar) || bar <= 0) {
      return reply.code(400).send({ error: "barWeightKg > 0" });
    }
    const plates = Array.isArray(b.availablePlatesKg)
      ? [...new Set(b.availablePlatesKg.map(Number).filter((n) => Number.isFinite(n) && n > 0))].sort((x, y) => x - y)
      : null;
    if (!plates || plates.length === 0) {
      return reply.code(400).send({ error: "availablePlatesKg: array di numeri > 0" });
    }

    const c = await pool.connect();
    try {
      const uid = await profileId(c);
      const { rows } = await c.query(
        `insert into plate_set_configs (user_id, bar_weight_kg, available_plates_kg)
         values ($1, $2, $3)
         on conflict (user_id) do update
           set bar_weight_kg = excluded.bar_weight_kg,
               available_plates_kg = excluded.available_plates_kg
         returning bar_weight_kg, available_plates_kg`,
        [uid, bar, plates],
      );
      return reply.send(rows[0]);
    } finally {
      c.release();
    }
  });
}

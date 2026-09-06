import { pool } from "../db.js";

// Food catalog (glossario "Food", ADR-0017/0018). Slice 1: solo `custom`
// creati in app. OpenFoodFacts/USDA/barcode arrivano con ADR-0018.
// Client-supplied UUID + upsert idempotente per l'outbox (ADR-0006).
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const SOURCES = new Set(["openfoodfacts", "usda", "custom"]);

async function profileId(c) {
  const f = await c.query("select id from profiles order by created_at asc limit 1");
  if (f.rows[0]) return f.rows[0].id;
  const i = await c.query("insert into profiles default values returning id");
  return i.rows[0].id;
}

const COLS = `id, name, source, external_id, barcode, brand, serving_size_g,
              calories_per_100g, protein_g_per_100g, carbs_g_per_100g,
              fat_g_per_100g, caffeine_mg_per_100g`;

export default async function foods(app) {
  app.get("/v1/foods", async (req, reply) => {
    const q = typeof req.query?.q === "string" ? req.query.q.trim() : "";
    if (q.length > 0) {
      const { rows } = await pool.query(
        `select ${COLS} from foods
         where name ilike $1 order by name asc limit 100`,
        [`%${q}%`],
      );
      return reply.send(rows);
    }
    const { rows } = await pool.query(
      `select ${COLS} from foods order by created_at desc limit 500`,
    );
    return reply.send(rows);
  });

  app.post("/v1/foods", async (req, reply) => {
    const body = req.body ?? {};
    const name = typeof body.name === "string" ? body.name.trim() : "";
    if (name.length === 0) return reply.code(400).send({ error: "name richiesto" });
    if (body.id != null && !UUID_RE.test(String(body.id))) {
      return reply.code(400).send({ error: "id non è un UUID" });
    }
    if (body.source != null && !SOURCES.has(body.source)) {
      return reply.code(400).send({ error: "source non valido" });
    }
    const source = SOURCES.has(body.source) ? body.source : "custom";
    const num = (v) => (Number.isFinite(Number(v)) ? Number(v) : null);
    const str = (v) =>
      typeof v === "string" && v.trim().length > 0 ? v.trim() : null;
    const kcal = num(body.caloriesPer100g);
    if (kcal == null) return reply.code(400).send({ error: "caloriesPer100g richiesto" });

    const c = await pool.connect();
    try {
      const uid = await profileId(c);
      const { rows } = await c.query(
        `insert into foods
           (id, name, source, external_id, barcode, brand, serving_size_g,
            calories_per_100g, protein_g_per_100g, carbs_g_per_100g,
            fat_g_per_100g, caffeine_mg_per_100g, created_by)
         values (coalesce($1, gen_random_uuid()), $2, $3, $4, $5, $6, $7,
                 $8, $9, $10, $11, $12, $13)
         on conflict (id) do update set
           name = excluded.name,
           source = excluded.source,
           external_id = excluded.external_id,
           barcode = excluded.barcode,
           brand = excluded.brand,
           serving_size_g = excluded.serving_size_g,
           calories_per_100g = excluded.calories_per_100g,
           protein_g_per_100g = excluded.protein_g_per_100g,
           carbs_g_per_100g = excluded.carbs_g_per_100g,
           fat_g_per_100g = excluded.fat_g_per_100g,
           caffeine_mg_per_100g = excluded.caffeine_mg_per_100g
         returning ${COLS}, created_at`,
        [
          body.id ?? null, name, source, str(body.externalId), str(body.barcode),
          str(body.brand), num(body.servingSizeG), kcal,
          num(body.proteinGPer100g) ?? 0, num(body.carbsGPer100g) ?? 0,
          num(body.fatGPer100g) ?? 0, num(body.caffeineMgPer100g), uid,
        ],
      );
      return reply.code(201).send(rows[0]);
    } finally {
      c.release();
    }
  });
}

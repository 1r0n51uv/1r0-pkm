import { pool } from "../db.js";

// Meal Entry + items (glossario, ADR-0017). Gli item *snapshottano*
// calorie/macro (e il nome, migration 0006) al momento del log: restano
// storicamente accurati anche se il Food cambia dopo.
// Client-supplied UUID + upsert idempotente per l'outbox (ADR-0006).
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const SLOTS = new Set(["breakfast", "lunch", "dinner", "snack"]);

async function profileId(c) {
  const f = await c.query("select id from profiles order by created_at asc limit 1");
  if (f.rows[0]) return f.rows[0].id;
  const i = await c.query("insert into profiles default values returning id");
  return i.rows[0].id;
}

export default async function meals(app) {
  app.get("/v1/meal-entries", async (_req, reply) => {
    const { rows } = await pool.query(
      `select m.id, m.consumed_at, m.meal_slot, m.notes,
              coalesce(
                json_agg(
                  json_build_object(
                    'food_id', i.food_id, 'food_name', i.food_name,
                    'quantity_g', i.quantity_g, 'calories', i.calories,
                    'protein_g', i.protein_g, 'carbs_g', i.carbs_g,
                    'fat_g', i.fat_g, 'order_index', i.order_index
                  ) order by i.order_index
                ) filter (where i.id is not null),
                '[]'::json
              ) as items
       from meal_entries m
       left join meal_entry_items i on i.meal_entry_id = m.id
       group by m.id
       order by m.consumed_at desc
       limit 300`,
    );
    return reply.send(rows);
  });

  app.post("/v1/meal-entries", async (req, reply) => {
    const body = req.body ?? {};
    if (body.id != null && !UUID_RE.test(String(body.id))) {
      return reply.code(400).send({ error: "id non è un UUID" });
    }
    if (!SLOTS.has(body.mealSlot)) {
      return reply.code(400).send({ error: "mealSlot non valido" });
    }
    const items = Array.isArray(body.items) ? body.items : [];
    const num = (v) => (Number.isFinite(Number(v)) ? Number(v) : 0);

    const c = await pool.connect();
    try {
      const uid = await profileId(c);
      await c.query("begin");
      const { rows } = await c.query(
        `insert into meal_entries (id, user_id, consumed_at, meal_slot, notes)
         values (coalesce($1, gen_random_uuid()), $2, coalesce($3::timestamptz, now()), $4::meal_slot, $5)
         on conflict (id) do update set
           consumed_at = excluded.consumed_at,
           meal_slot = excluded.meal_slot,
           notes = excluded.notes
         returning id, consumed_at, meal_slot, notes`,
        [body.id ?? null, uid, body.consumedAt ?? null, body.mealSlot, body.notes ?? null],
      );
      const mealId = rows[0].id;
      await c.query("delete from meal_entry_items where meal_entry_id = $1", [mealId]);
      for (const [idx, it] of items.entries()) {
        const foodId =
          it.foodId != null && UUID_RE.test(String(it.foodId)) ? it.foodId : null;
        await c.query(
          `insert into meal_entry_items
             (meal_entry_id, food_id, food_name, quantity_g, calories,
              protein_g, carbs_g, fat_g, order_index)
           values ($1, $2, $3, $4, $5, $6, $7, $8, $9)`,
          [
            mealId, foodId, String(it.foodName ?? ""), num(it.quantityG),
            num(it.calories), num(it.proteinG), num(it.carbsG), num(it.fatG),
            it.orderIndex ?? idx,
          ],
        );
      }
      await c.query("commit");
      return reply.code(201).send({ id: mealId, ...rows[0] });
    } catch (err) {
      await c.query("rollback");
      app.log.error({ err }, "meal-entry insert fallito");
      return reply.code(500).send({ error: "insert fallito" });
    } finally {
      c.release();
    }
  });
}

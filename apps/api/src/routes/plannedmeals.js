import { pool } from "../db.js";

// Planned Meal + planned_meal_items (glossario "Planned Meal", ADR-0017
// slice 2). Un pasto pianificato per una data futura; confermarlo
// ("completed") crea un meal_entry collegato — quel meal_entry lo crea il
// client (logMeal) e passa qui il suo id in `mealEntryId`. Saltarlo lo mette
// "skipped". Nessuna rigenerazione automatica.
// Client-supplied UUID + upsert idempotente per l'outbox (ADR-0006).
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const SLOTS = new Set(["breakfast", "lunch", "dinner", "snack"]);
const STATUSES = new Set(["planned", "completed", "skipped"]);
const DATE_RE = /^\d{4}-\d{2}-\d{2}$/;

async function profileId(c) {
  const f = await c.query("select id from profiles order by created_at asc limit 1");
  if (f.rows[0]) return f.rows[0].id;
  const i = await c.query("insert into profiles default values returning id");
  return i.rows[0].id;
}

export default async function plannedMeals(app) {
  app.get("/v1/planned-meals", async (req, reply) => {
    const from = DATE_RE.test(String(req.query?.from ?? "")) ? req.query.from : null;
    const to = DATE_RE.test(String(req.query?.to ?? "")) ? req.query.to : null;
    const { rows } = await pool.query(
      `select p.id, p.planned_date, p.meal_slot, p.recipe_id, p.status,
              p.meal_entry_id, p.created_at,
              coalesce(
                json_agg(
                  json_build_object(
                    'food_id', i.food_id, 'food_name', i.food_name,
                    'quantity_g', i.quantity_g, 'order_index', i.order_index
                  ) order by i.order_index
                ) filter (where i.id is not null),
                '[]'::json
              ) as items
       from planned_meals p
       left join planned_meal_items i on i.planned_meal_id = p.id
       where ($1::date is null or p.planned_date >= $1::date)
         and ($2::date is null or p.planned_date <= $2::date)
       group by p.id
       order by p.planned_date asc, p.meal_slot asc
       limit 400`,
      [from, to],
    );
    return reply.send(rows);
  });

  app.post("/v1/planned-meals", async (req, reply) => {
    const b = req.body ?? {};
    if (b.id != null && !UUID_RE.test(String(b.id))) {
      return reply.code(400).send({ error: "id non è un UUID" });
    }
    if (!DATE_RE.test(String(b.plannedDate ?? ""))) {
      return reply.code(400).send({ error: "plannedDate (YYYY-MM-DD) richiesto" });
    }
    if (!SLOTS.has(b.mealSlot)) {
      return reply.code(400).send({ error: "mealSlot non valido" });
    }
    const status = STATUSES.has(b.status) ? b.status : "planned";
    const recipeId =
      b.recipeId != null && UUID_RE.test(String(b.recipeId)) ? b.recipeId : null;
    const mealEntryId =
      b.mealEntryId != null && UUID_RE.test(String(b.mealEntryId)) ? b.mealEntryId : null;
    const items = Array.isArray(b.items) ? b.items : [];
    const num = (v) => (Number.isFinite(Number(v)) ? Number(v) : 0);

    const c = await pool.connect();
    try {
      const uid = await profileId(c);
      await c.query("begin");
      const { rows } = await c.query(
        `insert into planned_meals
           (id, user_id, planned_date, meal_slot, recipe_id, status, meal_entry_id)
         values (coalesce($1, gen_random_uuid()), $2, $3::date, $4::meal_slot, $5, $6, $7)
         on conflict (id) do update set
           planned_date = excluded.planned_date,
           meal_slot = excluded.meal_slot,
           recipe_id = excluded.recipe_id,
           status = excluded.status,
           meal_entry_id = excluded.meal_entry_id
         returning id, planned_date, meal_slot, recipe_id, status, meal_entry_id, created_at`,
        [b.id ?? null, uid, b.plannedDate, b.mealSlot, recipeId, status, mealEntryId],
      );
      const pid = rows[0].id;
      await c.query("delete from planned_meal_items where planned_meal_id = $1", [pid]);
      for (const [idx, it] of items.entries()) {
        const foodId =
          it.foodId != null && UUID_RE.test(String(it.foodId)) ? it.foodId : null;
        await c.query(
          `insert into planned_meal_items
             (planned_meal_id, food_id, food_name, quantity_g, order_index)
           values ($1, $2, $3, $4, $5)`,
          [pid, foodId, String(it.foodName ?? ""), num(it.quantityG), it.orderIndex ?? idx],
        );
      }
      await c.query("commit");
      return reply.code(201).send({ id: pid, ...rows[0] });
    } catch (err) {
      await c.query("rollback");
      app.log.error({ err }, "planned-meal insert fallito");
      return reply.code(500).send({ error: "insert fallito" });
    } finally {
      c.release();
    }
  });

  app.delete("/v1/planned-meals/:id", async (req, reply) => {
    if (!UUID_RE.test(String(req.params.id))) {
      return reply.code(400).send({ error: "id non è un UUID" });
    }
    await pool.query("delete from planned_meals where id = $1", [req.params.id]);
    return reply.code(204).send();
  });
}

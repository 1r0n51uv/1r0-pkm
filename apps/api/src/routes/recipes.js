import { pool } from "../db.js";

// Recipe + recipe_items (glossario "Recipe", ADR-0017 slice 2). Pasto
// riutilizzabile: un elenco di alimenti con quantità, richiamabile quando si
// logga o si pianifica un pasto. Gli item *snapshottano* il nome
// (migration 0008) per la UI offline; `food_id` può essere null.
// Client-supplied UUID + upsert idempotente per l'outbox (ADR-0006).
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

async function profileId(c) {
  const f = await c.query("select id from profiles order by created_at asc limit 1");
  if (f.rows[0]) return f.rows[0].id;
  const i = await c.query("insert into profiles default values returning id");
  return i.rows[0].id;
}

export default async function recipes(app) {
  app.get("/v1/recipes", async (_req, reply) => {
    const { rows } = await pool.query(
      `select r.id, r.name, r.notes, r.created_at, r.updated_at,
              coalesce(
                json_agg(
                  json_build_object(
                    'food_id', i.food_id, 'food_name', i.food_name,
                    'quantity_g', i.quantity_g, 'order_index', i.order_index
                  ) order by i.order_index
                ) filter (where i.id is not null),
                '[]'::json
              ) as items
       from recipes r
       left join recipe_items i on i.recipe_id = r.id
       group by r.id
       order by r.updated_at desc
       limit 300`,
    );
    return reply.send(rows);
  });

  app.post("/v1/recipes", async (req, reply) => {
    const b = req.body ?? {};
    if (b.id != null && !UUID_RE.test(String(b.id))) {
      return reply.code(400).send({ error: "id non è un UUID" });
    }
    const name = typeof b.name === "string" ? b.name.trim() : "";
    if (!name) return reply.code(400).send({ error: "name richiesto" });
    const items = Array.isArray(b.items) ? b.items : [];
    const num = (v) => (Number.isFinite(Number(v)) ? Number(v) : 0);

    const c = await pool.connect();
    try {
      const uid = await profileId(c);
      await c.query("begin");
      const { rows } = await c.query(
        `insert into recipes (id, user_id, name, notes, updated_at)
         values (coalesce($1, gen_random_uuid()), $2, $3, $4, now())
         on conflict (id) do update set
           name = excluded.name, notes = excluded.notes, updated_at = now()
         returning id, name, notes, created_at, updated_at`,
        [b.id ?? null, uid, name, typeof b.notes === "string" ? b.notes : null],
      );
      const rid = rows[0].id;
      await c.query("delete from recipe_items where recipe_id = $1", [rid]);
      for (const [idx, it] of items.entries()) {
        const foodId =
          it.foodId != null && UUID_RE.test(String(it.foodId)) ? it.foodId : null;
        await c.query(
          `insert into recipe_items (recipe_id, food_id, food_name, quantity_g, order_index)
           values ($1, $2, $3, $4, $5)`,
          [rid, foodId, String(it.foodName ?? ""), num(it.quantityG), it.orderIndex ?? idx],
        );
      }
      await c.query("commit");
      return reply.code(201).send({ id: rid, ...rows[0] });
    } catch (err) {
      await c.query("rollback");
      app.log.error({ err }, "recipe insert fallito");
      return reply.code(500).send({ error: "insert fallito" });
    } finally {
      c.release();
    }
  });

  app.delete("/v1/recipes/:id", async (req, reply) => {
    if (!UUID_RE.test(String(req.params.id))) {
      return reply.code(400).send({ error: "id non è un UUID" });
    }
    await pool.query("delete from recipes where id = $1", [req.params.id]);
    return reply.code(204).send();
  });
}

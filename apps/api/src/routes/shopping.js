import { pool } from "../db.js";

// Shopping List Item (glossario, ADR-0017 slice 3): lista persistente e
// spuntabile. `source` = 'generated' (dai pasti pianificati) | 'manual'.
// La generazione la fa il client e *aggiunge* soltanto — nessuna
// rigenerazione/sovrascrittura qui. Client-supplied UUID + upsert (ADR-0006).
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const SOURCES = new Set(["generated", "manual"]);

async function profileId(c) {
  const f = await c.query("select id from profiles order by created_at asc limit 1");
  if (f.rows[0]) return f.rows[0].id;
  const i = await c.query("insert into profiles default values returning id");
  return i.rows[0].id;
}

const COLS = `id, food_id, custom_name, quantity_text, is_checked, source, created_at`;

export default async function shopping(app) {
  app.get("/v1/shopping-list", async (_req, reply) => {
    const { rows } = await pool.query(
      `select ${COLS} from shopping_list_items
       order by is_checked asc, created_at asc limit 500`,
    );
    return reply.send(rows);
  });

  app.post("/v1/shopping-list", async (req, reply) => {
    const b = req.body ?? {};
    if (!UUID_RE.test(String(b.id ?? ""))) {
      return reply.code(400).send({ error: "id deve essere un UUID" });
    }
    const name = typeof b.customName === "string" ? b.customName.trim() : "";
    const foodId = b.foodId != null && UUID_RE.test(String(b.foodId)) ? b.foodId : null;
    if (!name && !foodId) {
      return reply.code(400).send({ error: "serve customName o foodId" });
    }
    const source = SOURCES.has(b.source) ? b.source : "manual";
    const qty = typeof b.quantityText === "string" && b.quantityText.trim()
      ? b.quantityText.trim() : null;
    const checked = b.isChecked === true;

    const c = await pool.connect();
    try {
      const uid = await profileId(c);
      const { rows } = await c.query(
        `insert into shopping_list_items
           (id, user_id, food_id, custom_name, quantity_text, is_checked, source)
         values ($1, $2, $3, $4, $5, $6, $7)
         on conflict (id) do update set
           food_id = excluded.food_id,
           custom_name = excluded.custom_name,
           quantity_text = excluded.quantity_text,
           is_checked = excluded.is_checked,
           source = excluded.source
         returning ${COLS}`,
        [b.id, uid, foodId, name, qty, checked, source],
      );
      return reply.code(201).send(rows[0]);
    } finally {
      c.release();
    }
  });

  app.delete("/v1/shopping-list/:id", async (req, reply) => {
    if (!UUID_RE.test(String(req.params.id))) {
      return reply.code(400).send({ error: "id non è un UUID" });
    }
    await pool.query("delete from shopping_list_items where id = $1", [req.params.id]);
    return reply.code(204).send();
  });

  // svuota le voci spuntate (comodo per la UI)
  app.post("/v1/shopping-list/clear-checked", async (_req, reply) => {
    const { rowCount } = await pool.query(
      "delete from shopping_list_items where is_checked = true",
    );
    return reply.send({ deleted: rowCount });
  });
}

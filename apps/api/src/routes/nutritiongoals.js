import { pool } from "../db.js";

// Nutrition Goal (glossario, ADR-0019). Tabella *append-only*: ogni cambio
// obiettivo (anche solo di modalità) è una nuova riga con `effective_from`.
// L'obiettivo "corrente" (riga più recente con effective_from <= oggi) lo
// calcola il client. Il POST è idempotente sull'id del client (outbox,
// ADR-0006): re-inviare la stessa riga non fa nulla.
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const MODES = new Set(["manual", "phase_linked", "tdee"]);
const ACT = new Set(["sedentary", "moderate", "active"]);

async function profileId(c) {
  const f = await c.query("select id from profiles order by created_at asc limit 1");
  if (f.rows[0]) return f.rows[0].id;
  const i = await c.query("insert into profiles default values returning id");
  return i.rows[0].id;
}

const COLS = `id, mode, calories_target, protein_g_target, carbs_g_target,
              fat_g_target, water_ml_target, effective_from, activity_level,
              source_note, created_at`;

export default async function nutritionGoals(app) {
  app.get("/v1/nutrition-goals", async (_req, reply) => {
    const { rows } = await pool.query(
      `select ${COLS} from nutrition_goals
       order by effective_from desc, created_at desc limit 500`,
    );
    return reply.send(rows);
  });

  app.post("/v1/nutrition-goals", async (req, reply) => {
    const b = req.body ?? {};
    if (b.id != null && !UUID_RE.test(String(b.id))) {
      return reply.code(400).send({ error: "id non è un UUID" });
    }
    if (!MODES.has(b.mode)) return reply.code(400).send({ error: "mode non valido" });
    const num = (v) => (Number.isFinite(Number(v)) ? Number(v) : null);
    const kcal = num(b.caloriesTarget);
    if (kcal == null || kcal <= 0) {
      return reply.code(400).send({ error: "caloriesTarget richiesto" });
    }
    const act = ACT.has(b.activityLevel) ? b.activityLevel : null;
    const note =
      typeof b.sourceNote === "string" && b.sourceNote.trim() ? b.sourceNote.trim() : null;
    // effective_from: 'YYYY-MM-DD' dal client, default oggi
    const eff =
      typeof b.effectiveFrom === "string" && /^\d{4}-\d{2}-\d{2}/.test(b.effectiveFrom)
        ? b.effectiveFrom.slice(0, 10)
        : null;

    const c = await pool.connect();
    try {
      const uid = await profileId(c);
      const { rows } = await c.query(
        `insert into nutrition_goals
           (id, user_id, mode, calories_target, protein_g_target, carbs_g_target,
            fat_g_target, water_ml_target, effective_from, activity_level, source_note)
         values (coalesce($1, gen_random_uuid()), $2, $3, $4, $5, $6, $7, $8,
                 coalesce($9::date, current_date), $10, $11)
         on conflict (id) do nothing
         returning ${COLS}`,
        [
          b.id ?? null, uid, b.mode, kcal,
          num(b.proteinGTarget) ?? 0, num(b.carbsGTarget) ?? 0, num(b.fatGTarget) ?? 0,
          num(b.waterMlTarget), eff, act, note,
        ],
      );
      if (rows[0]) return reply.code(201).send(rows[0]);
      // già presente (re-invio idempotente): rispondi con la riga esistente
      const { rows: ex } = await c.query(
        `select ${COLS} from nutrition_goals where id = $1`, [b.id],
      );
      return reply.code(200).send(ex[0] ?? { id: b.id });
    } finally {
      c.release();
    }
  });
}

import { pool } from "../db.js";

// The spike's read/write-a-row check (issue #2): an authed client can read
// the single-user profile and create it if missing. `profiles` is the
// natural singleton table (see supabase/migrations/0001_1r0-gym_schema.sql).
export default async function profile(app) {
  app.get("/v1/profile", async (_req, reply) => {
    const { rows } = await pool.query(
      "select id, created_at from profiles order by created_at asc limit 1",
    );
    if (rows.length === 0) return reply.code(404).send({ error: "no profile" });
    return rows[0];
  });

  app.post("/v1/profile", async (_req, reply) => {
    const existing = await pool.query("select id, created_at from profiles limit 1");
    if (existing.rows.length > 0) return reply.code(200).send(existing.rows[0]);

    const { rows } = await pool.query(
      "insert into profiles default values returning id, created_at",
    );
    return reply.code(201).send(rows[0]);
  });
}

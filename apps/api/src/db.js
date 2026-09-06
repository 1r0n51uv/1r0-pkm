import pg from "pg";

// Single pool for the whole process. The Fastify service is the only client
// of Postgres (ADR-0022): no RLS, authorization lives in the routes.
const { Pool } = pg;

export const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  // Small pool — single-user app, one container.
  max: Number(process.env.PG_POOL_MAX ?? 5),
  idleTimeoutMillis: 30_000,
});

export async function ping() {
  const { rows } = await pool.query("select 1 as ok");
  return rows[0]?.ok === 1;
}

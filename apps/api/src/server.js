import Fastify from "fastify";

import { registerAuth } from "./auth.js";
import health from "./routes/health.js";
import profile from "./routes/profile.js";
import workoutImport from "./routes/workoutimport.js";
import measurements from "./routes/measurements.js";
import foods from "./routes/foods.js";
import meals from "./routes/meals.js";
import foodSearch from "./routes/foodsearch.js";
import nutritionGoals from "./routes/nutritiongoals.js";
import recipes from "./routes/recipes.js";
import plannedMeals from "./routes/plannedmeals.js";
import shopping from "./routes/shopping.js";
import trackers from "./routes/trackers.js";
import { pool } from "./db.js";

// ADR-0027: gym is now import + history. The catalog/routine-editor endpoints
// (exercises, routines, routine-tree, wger sync, ai import, plate-config) and
// the live-session endpoints (workout-sessions, set-logs) were removed with the
// client code that used them. `POST /v1/workout-import` (step 3) is the single
// batch sink for the Liftin' CSV — "our copy" / backup.
//
// Custom REST backend (ADR-0022): single Fastify process, talks straight to
// Postgres, static API-key auth, no RLS. Runs behind Caddy in the compose
// stack (see infra/).
const app = Fastify({
  logger: { level: process.env.LOG_LEVEL ?? "info" },
  trustProxy: true, // behind Caddy
});

registerAuth(app);

await app.register(health);
await app.register(profile);
await app.register(workoutImport);
await app.register(measurements);
await app.register(foods);
await app.register(meals);
await app.register(foodSearch);
await app.register(nutritionGoals);
await app.register(recipes);
await app.register(plannedMeals);
await app.register(shopping);
await app.register(trackers);

const port = Number(process.env.PORT ?? 8080);

app.addHook("onClose", async () => {
  await pool.end();
});

try {
  await app.listen({ port, host: "0.0.0.0" });
} catch (err) {
  app.log.error(err);
  process.exit(1);
}

for (const sig of ["SIGINT", "SIGTERM"]) {
  process.on(sig, () => app.close().then(() => process.exit(0)));
}

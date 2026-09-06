import Anthropic from "@anthropic-ai/sdk";

// The two former Supabase Edge Functions (ADR-0022) as Fastify routes:
//  - ai-import-exercise  -> POST /v1/exercises/ai-import   (ADR-0005)
//  - coaching-review     -> POST /v1/coaching/review       (ADR-0011)
// Both stay stateless: they proxy Claude and return structured JSON for the
// client to confirm before it writes anything to the DB.

// ANTHROPIC_API_KEY lives only in the service env, never on the iOS/Watch
// client. Kept as claude-sonnet-5 to match the previous Edge Function code;
// bump the model here if desired.
const MODEL = process.env.ANTHROPIC_MODEL ?? "claude-sonnet-5";

function client() {
  if (!process.env.ANTHROPIC_API_KEY) return null;
  return new Anthropic(); // reads ANTHROPIC_API_KEY from env
}

async function askForJson(anthropic, { maxTokens, prompt }) {
  const res = await anthropic.messages.create({
    model: MODEL,
    max_tokens: maxTokens,
    messages: [{ role: "user", content: prompt }],
  });
  const text = res.content.find((b) => b.type === "text")?.text ?? "{}";
  return JSON.parse(text);
}

export default async function ai(app) {
  app.post("/v1/exercises/ai-import", async (req, reply) => {
    const { query } = req.body ?? {};
    if (!query || String(query).trim().length === 0) {
      return reply.code(400).send({ error: "query mancante" });
    }
    const anthropic = client();
    if (!anthropic) {
      return reply.code(500).send({ error: "ANTHROPIC_API_KEY non configurata" });
    }

    try {
      const proposed = await askForJson(anthropic, {
        maxTokens: 512,
        prompt:
          `Trova/struttura l'esercizio da palestra "${query}". Rispondi ` +
          `SOLO con JSON: {"name": string, "muscleGroups": string[], ` +
          `"equipment": string | null, "instructions": string}.`,
      });
      return reply.send(proposed);
    } catch (err) {
      app.log.error({ err }, "ai-import fallita");
      return reply.code(502).send({ error: "chiamata a Claude fallita" });
    }
  });

  app.post("/v1/coaching/review", async (req, reply) => {
    const { routineId, userId, historySummary } = req.body ?? {};
    if (!routineId || !userId || !historySummary) {
      return reply.code(400).send({ error: "parametri mancanti" });
    }
    const anthropic = client();
    if (!anthropic) {
      return reply.code(500).send({ error: "ANTHROPIC_API_KEY non configurata" });
    }

    try {
      const proposed = await askForJson(anthropic, {
        maxTokens: 1024,
        prompt:
          `Sei un coach di powerlifting/bodybuilding. Storico allenamento ` +
          `(riassunto): ${historySummary}\n\n` +
          `Proponi eventuali modifiche alla scheda (nuovi target di ` +
          `serie/reps, sostituzione esercizi, o consiglio di deload). ` +
          `Rispondi SOLO con JSON: {"summary": string, "changes": object}.`,
      });
      // Caller (authed client) inserts the coaching_suggestions row with
      // status 'pending' — this route never writes to the DB.
      return reply.send({ routineId, userId, ...proposed });
    } catch (err) {
      app.log.error({ err }, "coaching-review fallita");
      return reply.code(502).send({ error: "chiamata a Claude fallita" });
    }
  });
}

import { pool } from "../db.js";

// Ricerca alimenti da fonti esterne (ADR-0018): OpenFoodFacts primario
// (prodotti confezionati EU/IT, ottimo barcode), USDA FoodData Central come
// fallback per alimenti generici/freschi. I risultati sono *candidati*
// transitori: non vengono scritti in `foods` finché l'utente non ne logga
// uno (allora l'app fa POST /v1/foods, ADR-0017).
//
// Euristica: barcode -> sempre OpenFoodFacts; ricerca testuale -> entrambe,
// OFF prima (specie i risultati che hanno anche il barcode).

const OFF_BASE = process.env.OFF_BASE ?? "https://world.openfoodfacts.org";
const USDA_BASE = process.env.USDA_BASE ?? "https://api.nal.usda.gov/fdc/v1";
const USDA_KEY = process.env.USDA_API_KEY ?? "DEMO_KEY";
const UA = "1r0-pkm/1.0 (github.com/1r0n51uv/1r0-pkm)";

async function fetchJSON(url, { timeoutMs = 8000, headers = {} } = {}) {
  const ac = new AbortController();
  const t = setTimeout(() => ac.abort(), timeoutMs);
  try {
    const res = await fetch(url, {
      signal: ac.signal,
      headers: { "User-Agent": UA, Accept: "application/json", ...headers },
    });
    if (!res.ok) return null;
    return await res.json();
  } catch {
    return null;
  } finally {
    clearTimeout(t);
  }
}

const round1 = (n) => (Number.isFinite(n) ? Math.round(n * 10) / 10 : null);
const posNum = (v) => {
  const n = Number(v);
  return Number.isFinite(n) && n >= 0 ? n : null;
};

/** OpenFoodFacts product -> shape candidato, o null se senza kcal. */
function fromOFF(p) {
  const n = p?.nutriments ?? {};
  let kcal = posNum(n["energy-kcal_100g"]);
  if (kcal == null && posNum(n["energy_100g"]) != null) {
    kcal = posNum(n["energy_100g"]) / 4.184; // kJ -> kcal
  }
  const name = (p?.product_name || p?.generic_name || "").trim();
  if (!name || kcal == null) return null;
  const brand = (p?.brands || "").split(",")[0]?.trim() || null;
  return {
    name: brand && !name.toLowerCase().includes(brand.toLowerCase())
      ? `${name} (${brand})`
      : name,
    source: "openfoodfacts",
    externalId: p?.code ?? null,
    barcode: p?.code ?? null,
    brand,
    servingSizeG: posNum(p?.serving_quantity),
    caloriesPer100g: round1(kcal),
    proteinGPer100g: round1(posNum(n["proteins_100g"]) ?? 0),
    carbsGPer100g: round1(posNum(n["carbohydrates_100g"]) ?? 0),
    fatGPer100g: round1(posNum(n["fat_100g"]) ?? 0),
    caffeineMgPer100g:
      posNum(n["caffeine_100g"]) != null ? round1(posNum(n["caffeine_100g"]) * 1000) : null,
  };
}

const USDA_NUTRIENT = {
  Energy: "kcal",
  Protein: "protein",
  "Carbohydrate, by difference": "carbs",
  "Total lipid (fat)": "fat",
};

/** USDA FoodData Central item -> shape candidato (valori per 100 g). */
function fromUSDA(f) {
  const name = (f?.description || "").trim();
  if (!name) return null;
  const out = { kcal: null, protein: 0, carbs: 0, fat: 0 };
  for (const fn of f?.foodNutrients ?? []) {
    const key = USDA_NUTRIENT[fn?.nutrientName];
    if (!key) continue;
    const val = posNum(fn?.value);
    if (val == null) continue;
    if (key === "kcal") {
      // preferisci kcal; alcune righe Energy sono in kJ
      if (fn?.unitName === "KJ" || fn?.unitName === "kJ") out.kcal = out.kcal ?? val / 4.184;
      else out.kcal = val;
    } else out[key] = val;
  }
  if (out.kcal == null) return null;
  return {
    name: name.charAt(0).toUpperCase() + name.slice(1).toLowerCase(),
    source: "usda",
    externalId: f?.fdcId != null ? String(f.fdcId) : null,
    barcode: null,
    brand: (f?.brandOwner || f?.brandName || "").trim() || null,
    servingSizeG: null,
    caloriesPer100g: round1(out.kcal),
    proteinGPer100g: round1(out.protein),
    carbsGPer100g: round1(out.carbs),
    fatGPer100g: round1(out.fat),
    caffeineMgPer100g: null,
  };
}

// ADR-0036: filtro paese opzionale — il sottodominio nazionale di OFF
// (es. it.openfoodfacts.org) restringe ai prodotti taggati per quel paese
// e preferisce nomi/marchi locali, invece della ricerca globale che pesca
// prodotti di qualunque paese (molti risultati francesi/spagnoli/tedeschi
// anche per query in italiano, es. "pane"/"bread").
const OFF_COUNTRY_HOSTS = { it: "https://it.openfoodfacts.org" };

async function searchOFF(q, limit, country) {
  const base = (country && OFF_COUNTRY_HOSTS[country]) || OFF_BASE;
  const url =
    `${base}/cgi/search.pl?search_terms=${encodeURIComponent(q)}` +
    `&search_simple=1&action=process&json=1&page_size=${limit}` +
    `&fields=code,product_name,generic_name,brands,serving_quantity,nutriments`;
  const j = await fetchJSON(url);
  return (j?.products ?? []).map(fromOFF).filter(Boolean);
}

async function searchUSDA(q, limit) {
  const url =
    `${USDA_BASE}/foods/search?api_key=${encodeURIComponent(USDA_KEY)}` +
    `&query=${encodeURIComponent(q)}&pageSize=${limit}` +
    `&dataType=${encodeURIComponent("Foundation,SR Legacy,Survey (FNDDS)")}`;
  const j = await fetchJSON(url);
  return (j?.foods ?? []).map(fromUSDA).filter(Boolean);
}

export default async function foodSearch(app) {
  // Ricerca testuale — OFF + USDA, deduplicata per nome, OFF prima.
  app.get("/v1/foods/search", async (req, reply) => {
    const q = typeof req.query?.q === "string" ? req.query.q.trim() : "";
    if (q.length < 2) return reply.send([]);
    const limit = Math.min(Math.max(Number(req.query?.limit) || 20, 1), 40);
    const country = typeof req.query?.country === "string"
      ? req.query.country.trim().toLowerCase() : "";

    const [off, usda] = await Promise.all([
      searchOFF(q, limit, country),
      searchUSDA(q, Math.ceil(limit / 2)),
    ]);

    const seen = new Set();
    const merged = [];
    for (const c of [...off, ...usda]) {
      const key = c.name.toLowerCase().replace(/\s+/g, " ").trim();
      if (seen.has(key)) continue;
      seen.add(key);
      merged.push(c);
      if (merged.length >= limit) break;
    }
    return reply.send(merged);
  });

  // Barcode — prima la cache locale (`foods`), poi OpenFoodFacts.
  app.get("/v1/foods/barcode/:code", async (req, reply) => {
    const code = String(req.params.code ?? "").replace(/[^0-9]/g, "");
    if (code.length < 6) return reply.code(400).send({ error: "barcode non valido" });

    const { rows } = await pool.query(
      `select name, source, external_id, barcode, brand, serving_size_g,
              calories_per_100g, protein_g_per_100g, carbs_g_per_100g,
              fat_g_per_100g, caffeine_mg_per_100g
       from foods where barcode = $1 limit 1`,
      [code],
    );
    if (rows[0]) {
      const r = rows[0];
      // stessa forma "candidato" del ramo OFF (camelCase, numeri)
      return reply.send({
        name: r.name,
        source: r.source,
        externalId: r.external_id,
        barcode: r.barcode,
        brand: r.brand,
        servingSizeG: posNum(r.serving_size_g),
        caloriesPer100g: posNum(r.calories_per_100g),
        proteinGPer100g: posNum(r.protein_g_per_100g) ?? 0,
        carbsGPer100g: posNum(r.carbs_g_per_100g) ?? 0,
        fatGPer100g: posNum(r.fat_g_per_100g) ?? 0,
        caffeineMgPer100g: posNum(r.caffeine_mg_per_100g),
        cached: true,
      });
    }

    const j = await fetchJSON(
      `${OFF_BASE}/api/v2/product/${code}.json` +
        `?fields=code,product_name,generic_name,brands,serving_quantity,nutriments`,
    );
    const cand = j?.product ? fromOFF(j.product) : null;
    if (!cand) return reply.code(404).send({ error: "alimento non trovato" });
    return reply.send(cand);
  });
}

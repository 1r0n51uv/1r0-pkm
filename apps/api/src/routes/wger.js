import { pool } from "../db.js";

// wger catalog import (ADR-0005). One-shot(ish) admin action: pull the public
// wger exercise database (English) and upsert it into `exercises` with
// `source = 'wger'`. Idempotent — the wger `uuid` is used verbatim as our
// row `id` and `external_id`, so re-running only refreshes existing rows.
//
// wger.de has no stable search endpoint anymore, so we page the full
// `exerciseinfo` list. The client then searches our own catalog.

const WGER_BASE = process.env.WGER_BASE ?? "https://wger.de/api/v2";
const PAGE = 100;

function stripHtml(s) {
  if (typeof s !== "string") return null;
  const text = s
    .replace(/<[^>]+>/g, " ")
    .replace(/&nbsp;/g, " ")
    .replace(/&amp;/g, "&")
    .replace(/\s+/g, " ")
    .trim();
  return text.length > 0 ? text : null;
}

function muscleNames(list) {
  return (Array.isArray(list) ? list : [])
    .map((m) => (m?.name_en && m.name_en.trim()) || (m?.name && m.name.trim()) || null)
    .filter(Boolean);
}

/** wger `exerciseinfo` object -> our row shape, or null if unusable. */
function normalize(info) {
  const t =
    (info.translations ?? []).find((x) => x.language === 2) ??
    (info.translations ?? [])[0];
  const name = t?.name?.trim();
  if (!info.uuid || !name) return null;

  const groups = [
    ...muscleNames(info.muscles),
    ...muscleNames(info.muscles_secondary),
  ];
  const equipment = (info.equipment ?? [])
    .map((e) => e?.name?.trim())
    .filter(Boolean)
    .join(", ");
  const image =
    (info.images ?? []).find((im) => im.is_main)?.image ??
    (info.images ?? [])[0]?.image ??
    null;
  const video = (info.videos ?? [])[0]?.video ?? null;

  return {
    id: info.uuid,
    externalId: info.uuid,
    name,
    muscleGroups: [...new Set(groups)],
    equipment: equipment.length > 0 ? equipment : null,
    instructions: stripHtml(t?.description) ?? null,
    imageUrl: image,
    videoUrl: video,
  };
}

async function fetchPage(offset, signal) {
  const url = `${WGER_BASE}/exerciseinfo/?format=json&language=2&limit=${PAGE}&offset=${offset}`;
  const res = await fetch(url, { signal, headers: { Accept: "application/json" } });
  if (!res.ok) throw new Error(`wger ${res.status} @ offset ${offset}`);
  return res.json();
}

async function upsert(row) {
  const { rows } = await pool.query(
    `insert into exercises
       (id, name, source, external_id, muscle_groups, equipment, instructions, image_url, video_url)
     values ($1, $2, 'wger', $3, $4, $5, $6, $7, $8)
     on conflict (id) do update set
       name = excluded.name,
       source = 'wger',
       external_id = excluded.external_id,
       muscle_groups = excluded.muscle_groups,
       equipment = excluded.equipment,
       instructions = excluded.instructions,
       image_url = excluded.image_url,
       video_url = excluded.video_url
     returning (xmax::text::bigint = 0) as inserted`,
    [
      row.id,
      row.name,
      row.externalId,
      row.muscleGroups,
      row.equipment,
      row.instructions,
      row.imageUrl,
      row.videoUrl,
    ],
  );
  return rows[0]?.inserted === true;
}

export default async function wger(app) {
  app.post("/v1/exercises/wger-sync", async (req, reply) => {
    const max = Math.min(
      Math.max(Number(req.body?.max ?? 1000) || 1000, 1),
      2000,
    );

    const ac = new AbortController();
    const timeout = setTimeout(() => ac.abort(), 60_000);

    let fetched = 0;
    let inserted = 0;
    let updated = 0;
    let skipped = 0;
    let pages = 0;

    try {
      for (let offset = 0; offset < max; offset += PAGE) {
        const data = await fetchPage(offset, ac.signal);
        pages += 1;
        const results = data.results ?? [];
        if (results.length === 0) break;

        for (const info of results) {
          fetched += 1;
          const row = normalize(info);
          if (!row) {
            skipped += 1;
            continue;
          }
          const wasInsert = await upsert(row);
          if (wasInsert) inserted += 1;
          else updated += 1;
        }
        if (!data.next) break;
      }
    } catch (err) {
      app.log.error({ err }, "wger-sync fallita");
      return reply.code(502).send({
        error: "sync wger fallita",
        detail: String(err?.message ?? err),
        partial: { pages, fetched, inserted, updated, skipped },
      });
    } finally {
      clearTimeout(timeout);
    }

    return reply.send({ pages, fetched, inserted, updated, skipped });
  });
}

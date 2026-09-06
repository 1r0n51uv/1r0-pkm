-- Catalogo esercizi da wger (ADR-0005). Le colonne `external_id`,
-- `instructions`, `video_url`, `image_url` esistono già dallo schema 0001;
-- qui si aggiunge solo l'unicità di `external_id` per evitare doppioni se
-- lo stesso esercizio wger venisse importato con due `id` diversi.
--
-- L'import vero e proprio è la route POST /v1/exercises/wger-sync
-- (apps/api/src/routes/wger.js): usa lo `uuid` wger come `id` della riga,
-- quindi è idempotente anche senza questo indice.

create unique index if not exists exercises_external_id_key
  on exercises (external_id)
  where external_id is not null;

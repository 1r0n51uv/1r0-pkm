import pg from "pg";
import { AsyncLocalStorage } from "node:async_hooks";

// ADR-0034: due pool — uno per database (prod = DATABASE_URL, dev/test =
// DATABASE_URL_DEV, ADR-0033 li ha separati). Il target per la richiesta
// corrente si legge dall'header `X-Db-Target` (impostato lato client da un
// interruttore in Impostazioni) via AsyncLocalStorage, non una variabile
// globale mutabile: ogni richiesta ha il proprio contesto async, niente
// race fra richieste concorrenti che scelgono target diversi.
//
// Le route continuano a fare `pool.query(...)`/`pool.connect()` esattamente
// come prima di questo ADR — `pool` è un Proxy che inoltra al pool giusto
// per la richiesta corrente, così non serve toccare nessuna delle route
// esistenti.
const { Pool } = pg;
const dbTarget = new AsyncLocalStorage();

function makePool(url) {
  return new Pool({
    connectionString: url,
    // Small pool — single-user app, one container.
    max: Number(process.env.PG_POOL_MAX ?? 5),
    idleTimeoutMillis: 30_000,
  });
}

const poolProd = makePool(process.env.DATABASE_URL);
// Se DATABASE_URL_DEV non è impostata, il target "dev" ricade su prod
// invece di far crashare l'avvio — comodo in locale/CI dove un solo
// database esiste.
const poolDev = process.env.DATABASE_URL_DEV
  ? makePool(process.env.DATABASE_URL_DEV)
  : poolProd;

function currentPool() {
  return dbTarget.getStore() === "dev" ? poolDev : poolProd;
}

export const pool = new Proxy(
  {},
  {
    get(_target, prop) {
      const p = currentPool();
      const v = p[prop];
      return typeof v === "function" ? v.bind(p) : v;
    },
  },
);

/// Chiamata dall'hook `onRequest` in server.js con l'header della richiesta
/// corrente. `enterWith` vale per il resto della catena async di questa
/// richiesta (handler compreso), senza dover avvolgere ogni route.
export function setDbTarget(headerValue) {
  dbTarget.enterWith(headerValue === "dev" ? "dev" : "prod");
}

export async function ping() {
  const { rows } = await pool.query("select 1 as ok");
  return rows[0]?.ok === 1;
}

export async function closeAll() {
  await poolProd.end();
  if (poolDev !== poolProd) await poolDev.end();
}

// telegram-bot — boot loader for the Orbit bot (@OrbitFABOT).
//
// The bot's real source lives in the _bot_code table (gzip -> base64, split
// across rows); this file assembles it, inflates it and runs it.
//
// It used to do that at module top level with no error handling, which is how
// the bot died: one bad blob threw before any handler existed, so every single
// update got a bare 500, Telegram had nowhere to deliver, and nothing reported
// it. The bot stayed dead until a human happened to notice.
//
// Now nothing in the boot path can take the webhook down:
//   * this file owns the socket and always answers, even with no bot loaded
//   * a corrupt _bot_code falls back to _bot_code_good, the last blob that
//     actually ran
//   * updates that arrive while the bot is down are queued and replayed, not
//     dropped
//   * a failed load is retried on later traffic, so a bad isolate heals itself
//     instead of staying dead until a redeploy

import { createClient } from "npm:@supabase/supabase-js@2";
import * as xlsx from "npm:xlsx@0.18.5";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

// The bot source expects its dependencies here rather than importing them.
(globalThis as any).__ORBIT_DEPS = { createClient, xlsx };

const sb = createClient(SUPABASE_URL, SERVICE_ROLE, { auth: { persistSession: false } });

type Handler = (req: Request) => Response | Promise<Response>;

let handler: Handler | null = null;
let loadError: string | null = null;
let loadedFrom: string | null = null;
let loading: Promise<void> | null = null;
let lastAttempt = 0;

const RETRY_MS = 15_000; // don't hammer the DB when the blob is genuinely bad

// ── blob -> source ───────────────────────────────────────────────────────

async function readBlob(table: string): Promise<string | null> {
  const { data, error } = await sb.from(table).select("part,content").order("part");
  if (error || !data?.length) return null;
  let b64 = "";
  for (const row of data) b64 += (row as any).content;
  b64 = b64.replace(/[^A-Za-z0-9+/=]/g, "");
  return b64 || null;
}

async function inflate(b64: string): Promise<string> {
  const gz = Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));
  return await new Response(
    new Blob([gz]).stream().pipeThrough(new DecompressionStream("gzip")),
  ).text();
}

/**
 * Import the bot source and take its request handler.
 *
 * The source calls Deno.serve itself. If it did that for real, it would own the
 * socket and this file could no longer guarantee an answer when the bot is
 * broken — so Deno.serve is stubbed for the duration of the import and the
 * handler is captured instead.
 */
async function importAndCapture(src: string): Promise<Handler> {
  const real = Deno.serve;
  let captured: Handler | null = null;

  (Deno as any).serve = (a: any, b?: any): any => {
    const h = typeof a === "function" ? a : typeof b === "function" ? b : a?.handler;
    if (typeof h === "function") captured = h as Handler;
    return {
      finished: Promise.resolve(),
      shutdown: async () => {},
      ref() {},
      unref() {},
      addr: { transport: "tcp", hostname: "0.0.0.0", port: 0 },
    };
  };

  try {
    // The trailing comment makes each attempt a distinct module URL; without it
    // the import cache would hand back the previously failed module forever.
    const url = "data:application/javascript;charset=utf-8," +
      encodeURIComponent(src + "\n//" + Date.now() + "\n");
    await import(url);
  } finally {
    (Deno as any).serve = real;
  }

  if (!captured) throw new Error("bot source registered no handler");
  return captured;
}

/** Remember the blob that just worked, so a later bad write can't strand us. */
async function saveKnownGood(b64: string): Promise<void> {
  const existing = await readBlob("_bot_code_good");
  if (existing === b64) return; // already current

  const CHUNK = 4000;
  const rows: { part: number; content: string }[] = [];
  for (let i = 0, part = 1; i < b64.length; i += CHUNK, part++) {
    rows.push({ part, content: b64.slice(i, i + CHUNK) });
  }
  await sb.from("_bot_code_good").delete().gte("part", 0);
  await sb.from("_bot_code_good").insert(rows);
}

async function loadOnce(): Promise<void> {
  lastAttempt = Date.now();

  const primary = await readBlob("_bot_code");
  if (primary) {
    try {
      const h = await importAndCapture(await inflate(primary));
      handler = h;
      loadError = null;
      loadedFrom = "_bot_code";
      await saveKnownGood(primary).catch((e) => console.error("saveKnownGood:", e));
      console.log("bot loaded from _bot_code");
      return;
    } catch (e) {
      // Fall through to the backup. This is the exact case that used to be
      // fatal: a blob that is present but unusable.
      console.error("_bot_code unusable:", e instanceof Error ? e.message : String(e));
    }
  } else {
    console.error("_bot_code is empty or unreadable");
  }

  const backup = await readBlob("_bot_code_good");
  if (backup) {
    try {
      handler = await importAndCapture(await inflate(backup));
      loadError = null;
      loadedFrom = "_bot_code_good";
      console.warn("bot loaded from _bot_code_good (primary is broken)");
      return;
    } catch (e) {
      console.error("_bot_code_good unusable:", e instanceof Error ? e.message : String(e));
    }
  }

  loadError = "no usable bot source in _bot_code or _bot_code_good";
  console.error(loadError);
}

/** Single-flight, so concurrent updates don't each start their own import. */
function load(): Promise<void> {
  if (!loading) {
    loading = loadOnce().finally(() => { loading = null; });
  }
  return loading;
}

// ── queued updates ─────────────────────────────────────────────────────

async function enqueue(req: Request): Promise<void> {
  const body = await req.text().catch(() => "");
  if (!body) return;
  await sb.from("_bot_update_queue").insert({
    body,
    secret_header: req.headers.get("x-telegram-bot-api-secret-token"),
  });
}

/** Replay what came in while the bot was down, oldest first. */
async function drain(): Promise<void> {
  if (!handler) return;
  const { data } = await sb
    .from("_bot_update_queue")
    .select("id,body,secret_header")
    .is("replayed_at", null)
    .order("id")
    .limit(25);
  if (!data?.length) return;

  for (const row of data as any[]) {
    try {
      const headers: Record<string, string> = { "content-type": "application/json" };
      if (row.secret_header) headers["x-telegram-bot-api-secret-token"] = row.secret_header;
      await handler(new Request("https://replay.local/", { method: "POST", headers, body: row.body }));
    } catch (e) {
      console.error("replay failed for", row.id, e);
    }
    await sb.from("_bot_update_queue")
      .update({ replayed_at: new Date().toISOString() })
      .eq("id", row.id);
  }
  console.log(`replayed ${data.length} queued update(s)`);
}

// ── server ──────────────────────────────────────────────────────────

// Boot eagerly, but never let a failure escape: the server below must come up
// no matter what state the blob is in.
await load().catch((e) => console.error("initial load:", e));

Deno.serve(async (req) => {
  // A health view that says which source is live and why, so "is the bot up?"
  // never again requires reading logs.
  if (new URL(req.url).searchParams.get("health")) {
    return new Response(
      JSON.stringify({
        ok: !!handler,
        loaded_from: loadedFrom,
        load_error: loadError,
        queued: (await sb.from("_bot_update_queue").select("id", { count: "exact", head: true })
          .is("replayed_at", null)).count ?? null,
      }, null, 2),
      { headers: { "Content-Type": "application/json" } },
    );
  }

  // Retry a failed load on live traffic so a broken isolate recovers by itself.
  if (!handler && Date.now() - lastAttempt > RETRY_MS) await load();

  if (handler) {
    let res: Response;
    try {
      res = await handler(req);
    } catch (e) {
      // A throw inside the bot must not become a dead webhook.
      console.error("bot handler threw:", e);
      res = new Response("ok");
    }
    // Opportunistically flush anything that queued up while we were down.
    try {
      // @ts-ignore EdgeRuntime is provided by Supabase
      if (typeof EdgeRuntime !== "undefined" && EdgeRuntime.waitUntil) EdgeRuntime.waitUntil(drain());
      else drain().catch(() => {});
    } catch { /* never let housekeeping affect the response */ }
    return res;
  }

  // Still no bot: keep the update rather than lose it, and answer 200 so
  // Telegram neither backs off nor disables the webhook.
  try {
    await enqueue(req);
  } catch (e) {
    console.error("enqueue failed:", e);
  }
  return new Response("ok");
});

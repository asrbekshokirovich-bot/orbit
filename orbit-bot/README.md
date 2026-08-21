# Orbit bot (@OrbitFABOT) — source backup

The running bot had no copy anywhere outside its own database. This directory is
that copy.

## Where the bot actually lives

| Piece | Location |
|---|---|
| Supabase project | **Orbit** — `zqpglkxbtpkvyraxquao` |
| Edge Function | `telegram-bot` (`verify_jwt = false`, Telegram webhook) |
| Bot source | rows in the **`_bot_code`** table — gzip, base64, split into 4000-char parts |
| Last known-good source | **`_bot_code_good`**, written by the loader after a successful boot |
| Updates that arrived while down | **`_bot_update_queue`**, replayed on recovery |

`telegram-bot` is only a loader: it concatenates `_bot_code`, gunzips it, imports
it as a data: URL and captures the handler the source registers. So the file
Supabase shows you for `telegram-bot` is *not* the bot — the bot is a row set in
a table, which is why it appears in no repository and has no history.

Related, and easy to confuse:

- **@Orbit_CC_Bot** is a *different* bot, served by `orbit-telegram-webhook` in
  the **Hanguk** project (`lysjdtyanhdfphqyijsr`) with its own `orbit.*` schema.
  That one has been idle since June and its source is in the
  `orbit-command-center` repo. Do not point @OrbitFABOT's token at it.

## Contents

| Path | What it is |
|---|---|
| `bot-source.ts` | Exact bytes of `_bot_code` as of 2026-08-05, inflated. Bundled/minified — this is the deployed artifact, not hand-written source. sha256 `c4e37a86…` |
| `functions/telegram-bot/index.ts` | The loader, verbatim from deployed version 21 |
| `migrations/20260805_allow_awaiting_transcript_state.sql` | The fix described below |

`bot-source.ts` is minified because that is how it is stored and run; no
unminified original was found in any repository or in the database.

## The bug fixed on 2026-08-05

Voice messages went in, were transcribed and parsed correctly, and produced
nothing. Pressing **✅ To'g'ri** on the "Men shuni eshitdim" card did nothing at
all.

`inbox_events.state` had a CHECK constraint that did not list
`awaiting_transcript`, the one state the voice flow depends on. The write was
rejected; the code never looks at the update's error, so it failed silently and
the row kept its old state. The confirm handler starts with

```js
if (x.state !== "awaiting_transcript")
    return answerCallbackQuery({ text: "Allaqachon" })
```

so it returned before doing any work. Every voice message died there. No
`inbox_events` row of kind `draft` had been created since 2026-07-25 — eleven
days with the confirm path dead and nothing reporting it.

The parse itself was never at fault. The event that prompted the report
(`inbox_events.id = 622`) had extracted exactly the right thing:

```json
{ "intent": "task", "business": "hanguk", "confidence": 1,
  "task": { "title": "Universitetlarning 2026-yil sentabr semestri uchun qabul yuriqnomalarini topish",
            "assignee_hint": "Diyora" } }
```

The owner never saw it, because the card that shows it is created after the
confirm that could not happen.

## How to restore the bot from this backup

```bash
# 1. gzip + base64 the source
gzip -c bot-source.ts | base64 -w0 > blob.b64

# 2. split into 4000-char parts and write them to _bot_code as (part, content),
#    part starting at 1, in order — the loader concatenates by `part`.
```

Then hit `telegram-bot?health=1`; it reports `loaded_from` and `load_error`.

## Worth doing next

- The silent-failure pattern that hid this is everywhere in the bot: writes go
  out with no error check. The single most valuable change is to log (or
  surface) failed writes on the inbox_events path.
- The bot source should live in this repository and be *deployed* into
  `_bot_code`, rather than only existing there.

## The fix of 2026-08-21 — reports that arrive after the digest

### What was wrong

Two separate faults, which together made a submitted report look like it
vanished.

**The digest could not carry what anyone wrote.** `Ee`, the handler for a
submitted report, saved it with the four extracted fields hard-coded empty:

```js
await ft(a, { done: "", blockers: "", plans: "", summary: "" }, l, s)
```

Nothing ever parsed the text into sections, so `done`/`blockers`/`plans` were
always `null`. The digest built each person's line from exactly those three
columns — it selected `raw_text` and then never used it — so a real report
reached the owner as `- Diyora: bajardi=[-] muammo=[-] reja=[-]`.

**A report that missed its digest reached nobody.** `staff_digest` runs once a
day. `Ee` answered "✅ Hisobot qabul qilindi" and stopped there, forwarding
nothing. Anything written after the digest sat in `daily_reports` unread.

A third, quieter one: `report_date` came from the wall-clock date, so a report
written at 00:30 was filed under the *next* day and counted as missing from the
day it was actually about.

### What changed

| | |
|---|---|
| `Bd()` | New. The workday a report belongs to: before 04:00 Tashkent it is still the previous day. `B()` is untouched and still means "today". |
| `ft()` | Files reports against `Bd()` instead of `B()`. |
| `Dg(day)` | New. Whether the digest for that day has already gone out — read from the `staff_digest_cron` row the digest already writes to `audit_log`, so no new table. |
| `Ee()` | If the digest has gone, forwards the report to the owner immediately, tagged `🕘 Kechikkan hisobot` with name and time, and tells the sender it was passed on separately. Logs `staff_report_late`. |
| `pt()` | Falls back to `raw_text` (whitespace collapsed, 600 chars) when no section was extracted. Extracted sections still win, and empty ones are dropped rather than printed as `[-]`. |

Deliberately unchanged: the 20:00 digest still runs once and still reads the
same tables; nothing was added to the schema.

### Still open

- **Sections are never extracted.** The fallback means the owner now reads the
  report, but `done`/`blockers`/`plans` stay null. Parsing the text into the
  three sections is the next piece of work.
- **Nobody is reminded.** `_t` (`staff_remind`) is written correctly and
  messages everyone with no report that day, but *when* it runs is a schedule
  outside this repository. On 2026-08-18 all five staff were listed as missing,
  which is what a reminder that never fires looks like. Check that the
  `staff_remind` job exists and fires before 20:00.

### Deploying it

```bash
node tools/pack.mjs        # regenerates deploy/_bot_code.sql from bot-source.ts
```

Run `deploy/_bot_code.sql` in the SQL editor of project `zqpglkxbtpkvyraxquao`.
It replaces `_bot_code` inside one transaction, so a longer previous blob
cannot leave a stale tail behind. Then hit `telegram-bot?health=1` and confirm
`loaded_from` is `_bot_code` and `load_error` is null — if the blob were bad the
loader would silently fall back to `_bot_code_good` and keep running the old
bot.

## The fix of 2026-08-21, part two — extraction, and the AI call that never ran

### Every AI call was failing

`ae()` built every request with `temperature: e.temperature ?? .5`. Sampling
parameters were removed from the current Claude models — `temperature` returns a
400 on Sonnet 5, Opus 5, Opus 4.7/4.8 and Fable 5 — and `ae()` throws on any
status outside `[500, 503, 529]`. So on any current model, every call through
`ae()` died before it began.

The digest hid this. Its call is wrapped in a bare `catch` that falls back to a
plain join:

```js
try { y = await ae(t, {…, temperature: .3}) } catch { y = `${d}\nYubormaganlar: …` }
```

That fallback is exactly what the 2026-08-18 digest printed:

```
(bugun hech kim hisobot yubormadi)
Yubormaganlar: Diyora, Nigina, Odina, Omina, Xushnud
```

Two lines, template-shaped — not something the model wrote. `ae()` no longer
sends `temperature` at all; the call sites still pass it and it is now ignored.
Older models fall back to their own default, which is fine for a digest and for
extraction against a strict JSON instruction.

### Reports are now split into sections

`Er(cfg, text)` asks Claude — through the same `ae()`, so it honours whatever
`app_config.anthropic_model` holds — to split one Uzbek report into
`done` / `blockers` / `plans` / `summary`, and is told to leave a field empty
rather than invent content for it. `Jp()` pulls the JSON out of the reply,
tolerating code fences and surrounding prose, and returns `null` instead of
throwing when there is nothing parseable.

`Ee()` runs the extraction before saving. If it fails or returns nothing, the
empty record is saved exactly as before and the digest's `raw_text` fallback
still carries the report — so a bad AI day degrades to the previous behaviour
rather than losing anything.

`Rr(sections, rawText)` renders a report for the owner: the sections that have
content, or the raw text when none do. Everything it emits is HTML-escaped,
since it goes out with `parse_mode: HTML`.

```
🕘 Kechikkan hisobot — Diyora · 2026-08-21 21:14

✅ Bajardi: Skladni sanadim
⚠️ Muammo: Yuk kech keldi
📌 Reja: Ertaga hisobotni yopaman
```

### Worth knowing

`ae()`'s fallback model is `claude-haiku-4-5-20251001`. The current ID is
`claude-haiku-4-5` — the dated suffix may not resolve. It was left alone here
because it only matters once the primary model is unavailable, but it is worth
correcting the next time this file is touched.

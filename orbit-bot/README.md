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

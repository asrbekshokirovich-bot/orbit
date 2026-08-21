-- Applied to the Orbit project (zqpglkxbtpkvyraxquao) on 2026-08-05.
--
-- The bot writes state = 'awaiting_transcript' on an inbox_events row while a
-- voice message waits for the owner to confirm what was heard. That value was
-- never in the CHECK, so the write was rejected and — because the code does not
-- inspect the update's error — it failed silently and the row kept its previous
-- state.
--
-- The "✅ To'g'ri" button then hit
--
--     if (x.state !== "awaiting_transcript")
--         return answerCallbackQuery({ text: "Allaqachon" })
--
-- and returned immediately, so pressing it did nothing and no draft card was
-- ever produced from a voice message. No inbox_events row of kind 'draft' had
-- been created since 2026-07-25.

alter table public.inbox_events drop constraint inbox_events_state_check;

alter table public.inbox_events add constraint inbox_events_state_check
  check (state = any (array[
    'received', 'parsed', 'awaiting_transcript', 'awaiting_business',
    'awaiting_confirm', 'confirmed', 'cancelled', 'rejected', 'error'
  ]::text[]));

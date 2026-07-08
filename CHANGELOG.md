# Changelog

## 0.4.4 - 2026-07-08

### Fixed

- Sender `flush_held` tolerates a non-ok send: the coalesce flush hard-matched
  `{:ok, state} = do_send_text(...)` inside `handle_info`, so any future
  error-shaped return would MatchError on a timer and kill the sender object
  (dead slot claims, wiped mailbox — the same trap as the 2026-07-07 prod
  crash-loop, one layer down). The result is now cased: ok stamps reply+sig as
  before; anything else keeps the sender alive — a failed flush loses the held
  tail, never the sender, and the failure stays in the delivery audit.

## 0.4.3 - 2026-07-07

### Added

- Sender claim re-seed at init: new optional delivery-effects callback
  `current_bindings/0` (or `/1` for tuple adapters). The sender's
  slot→conversation claims are process-local, so a sender restart used to
  drop in-flight agent replies as "no target" until the conversation's next
  inbound re-bound it. Hosts with a live session registry can now hand the
  current bindings back at init; the seam is TOTAL (a raising or malformed
  host implementation degrades to the old cold start) and hosts without it
  are unchanged.

## 0.4.2 - 2026-07-07

### Changed

- Sender spam window: coalesce instead of swallow. Extra agent replies inside
  the 30s window are now HELD per conversation and flushed as ONE real message
  when the window expires (a rate limit, not censorship) — multi-part answers
  no longer lose their substance to the gate. A new inbound flushes the held
  tail immediately (order preserved); exact replays of the just-delivered text
  still die (the original spam case); caps (3 texts / 3000 chars / 500 cids)
  degrade to the previous pure suppression; rich/card paths keep the previous
  behavior. Wire-compatible: `reply_suppressed` still fires on hold, and the
  flush emits a normal delivery.

## 0.4.1 - 2026-07-07

### Added

- Ingress poller health: `last_poll_ok_ms` / `conflict_count` state (409 replies
  from `getUpdates` bump the latter), an injectable `poll_health_sink` config
  hook (total against a raising sink) fired after every poll result, the
  `status` action reply now surfaces both plus `poll_failures`, and a new pure
  `Genswarms.Telegram.Dashboard.poller_health_block/1` builder shipping the
  `telegram_poller` machine block with `poller_deaf`/`poll_conflict`
  `health_rules` — additive, `dashboard_extension/1`'s output is unchanged.

## 0.4.0 - 2026-07-05

### Added

- `config_schema` (design §14.2.1) on the Ingress `swarm-object.json`, with
  `x-secret`/`x-mutable` annotations, and a `bot_token_env` secret ref so the
  swarm config never carries the literal bot token.

_(Backfilled: this release shipped without a CHANGELOG entry at the time —
see `git log 4da215b..538dd9e`.)_

## 0.3.1 - 2026-07-03

### Added

- Optional `DeliveryEffects` observability hooks (`reply_suppressed`,
  `progress_sent`, `reply_unresolvable`) for the hookless sender paths that
  `after_delivery` cannot see.

_(Backfilled: this release shipped without a CHANGELOG entry at the time —
see `git log 744a183..4da215b`.)_

## 0.3.0 - 2026-07-03

### Added

- `Genswarms.Telegram.Dashboard`: reference session shaping (labels, dm/group
  kind, `transport_ref`) plus this package's `dashboard_extension/1`
  implementation of the genswarms-dashboard extension contract (schema 1).

_(Backfilled: this release shipped without a CHANGELOG entry at the time —
see `git log 7f16d5b..744a183`.)_

## 0.2.1 - 2026-07-02

### Documentation

- Added the `genswarms-telegram-use` Claude Code skill and declared it in
  `swarmidx.json` via the manifest `skill` field, so consuming agents can load
  package usage guidance through swarmidx.

## 0.2.0 - 2026-07-02

### Security

- Added a default-deny scoped action gate for every sender action. Agent actions
  are conversation-scoped to the caller's bound slot, while operator groups are
  denied unless the host explicitly grants each group through `action_grants`.
- Classified operator groups for chat administration, business, payments, gifts,
  stories, sticker management, bot profile, managed bots, inline operations,
  verification, passport, games, utility, message operations, and infrastructure.
- Added `agent_surface`, `action_grants`, `audit_sources`,
  `own_message_window`, and related gate metadata so hosts can expose only the
  surfaces they intend.
- Made `audit` require configured `audit_sources` instead of being
  unauthenticated.
- Scoped own-message edit and delete actions to messages sent by the same
  calling slot and within the configured own-message window.
- Routed ingress command replies through the sender so rate limiting,
  redaction, delivery audit, and target authorization are applied consistently.

### Agent surface & discovery

- Derived `capabilities` from the action table and made it caller-specific so it
  advertises only actions the caller may actually use, including card schema
  details and Telegram Bot API 10.1 targeting.
- Added teaching `validate_card` errors with paths and hints for agent
  authoring.
- Added curated, round-trip-verified `examples` for card and rich message
  authoring.
- Shipped a flat `priv/agent-guide/` for consumers that need file-based agent
  guidance.
- Added inbound `replied_to` and quote parsing plus outbound
  `ReplyParameters` quote fields; quote fields are accepted only with a
  `reply_to_message_id`.
- Reclassified one-shot `send_chat_action` and `send_rich_raw` as restricted
  operator/infrastructure actions while keeping system-managed typing unchanged.

### Structure

- Split `Genswarms.Telegram.Delivery` internals into per-group submodules under
  `lib/genswarms/telegram/delivery/` while preserving the public delivery API.

### Neutrality

- Scrubbed shipped fixtures and documentation for product-neutral package
  language.
- Added a static neutrality test to keep product-specific terms out of shipped
  files.

### Added

- Added a structured Telegram card/rich-message layer with safe rendering for
  headings, paragraphs, lists, checklists, tables, details, quotes, code,
  dividers, media, collages, slideshows, references, time, maps, and draft-only
  thinking blocks.
- Added structured inline rich-text spans for bold, italic, underline,
  strikethrough, spoiler, mark, code, subscript, superscript, links, custom
  emoji, date-time, mentions, inline math, email, phone, bank-card, hashtag,
  cashtag, bot-command, anchor, and reference forms.
- Added structured rich-card rendering for Bot API math blocks, anchors,
  blockquote aliases, preformatted aliases, ordered-list attributes, and
  quote/pullquote credits.
- Added Telegram rich message delivery actions: `capabilities`, `examples`,
  `validate_card`, `send_card`, `stream_card`, `edit_card`, and
  `send_rich_raw`.
- Added `stream_text` support for Telegram `sendMessageDraft` alongside
  `sendRichMessageDraft`.
- Added sender delivery for media, live photos, video notes, media groups,
  stickers, polls/quizzes, locations, venues, contacts, and dice.
- Added agent-facing one-shot `send_chat_action` and non-paid `set_reaction`
  sender actions.
- Added agent-facing `edit_message`, `edit_caption`, `edit_reply_markup`, and
  `stop_poll` actions with inline-keyboard-only edit markup validation.
- Added agent-facing message lifecycle and native edit actions for
  copy/forward/delete, media edits, and live-location edits/stops.
- Added native Telegram checklist send/edit actions with business-connection
  validation, task normalization, and documentation distinct from rich-card
  checklist blocks.
- Added monetization/game message actions for paid media, invoices, and games
  with Stars, price, payload, and Pay-button validation.
- Added payment lifecycle actions for invoice links, shipping/pre-checkout
  answers, Star refunds, and Star subscription cancellation/re-enable.
- Added Telegram Stars and Gifts actions for bot Star balances/transactions,
  available gifts, sending gifts, gifting Premium, business Star transfers,
  gift listing, gift conversion, upgrades, and transfers.
- Added organization verification and managed-business account actions for
  verification, business message read/delete, profile fields, profile photos,
  and gift settings.
- Added guest-query answers, chat boost/business connection reads, managed-bot
  token/access operations, user personal-chat message reads, suggested-post
  approval/decline, Telegram Passport error reporting, and game score/high-score
  actions.
- Added bot profile/configuration actions for commands, localized name and
  descriptions, profile photo, chat menu button, and default administrator
  rights.
- Added inline/Web App response actions for callback queries, Web App queries,
  inline queries, prepared inline messages, and prepared keyboard buttons.
- Added managed-business story actions for posting, reposting, editing, and
  deleting Telegram stories with content and active-period validation.
- Added chat administration, invite-link, join-request, reaction-deletion, chat
  profile/info, and forum-topic actions with Telegram permission/range
  validation.
- Added utility actions for `logOut`, `close`, file lookup, user profile
  photo/audio reads, and user emoji status updates.
- Added sticker-set management actions for sticker lookup, custom emoji lookup,
  uploads, set creation, add/replace/delete operations, emoji lists, keywords,
  mask positions, thumbnails, and set deletion.
- Expanded safe inline-keyboard normalization to cover URL, callback, Web App,
  switch-inline, chosen-chat switch-inline, copy-text, and pay buttons.
- Added safe `reply_markup` normalization for reply keyboards, keyboard removal,
  and force-reply prompts while preserving `buttons` as inline-keyboard shorthand.
- Added machine-readable capability cataloging for agent-safe actions and
  restricted Bot API areas that require host policy or permissions.
- Documented the card protocol in `docs/telegram-cards.md` and included docs in
  package files.
- Hardened invalid payload handling so agent-facing sender actions return
  structured errors instead of raising.

## 0.1.7 - 2026-07-01

- Declared `:crypto` as an OTP application because bot fingerprints, offset
  paths, and curl temp names use crypto helpers at runtime.
- Preserved reply threading on photo sends and photo fallback paths.
- Added generic webhook registration client helpers for `setWebhook`,
  `deleteWebhook`, and `getWebhookInfo`.
- Made durable `MEMORY.md` context opt-in by defaulting ingress
  `memory_policy` to `:none`.
- Documented tuple adapter callback arities for host adapters configured as
  `{Module, opts}`.

## 0.1.6 - 2026-07-01

- Corrected the published README release metadata so the package artifact points
  at the current swarmidx and Git refs.

## 0.1.5 - 2026-07-01

- Moved robust generic sender mechanics into the reusable package: bounded async
  batch draining, rate limiting, typing keepalive, owed-turn duplicate reply
  suppression, progress edit coalescing/expiry, public delivery helper wrappers,
  and response classification helpers.
- Kept host-specific delivery side effects behind the delivery effects adapter.
- Aligned the session runtime behaviour with the modern ingress contract, wired
  routed-update effects, and exposed a generic command-menu registration action.
- Hardened command detection for leading-whitespace slash commands and preserved
  Telegram `chat.type` in parsed events so hosts can scope member events safely.

## 0.1.4 - 2026-07-01

- Added public generic Telegram addressing helpers.
- Added public generic spam guard helpers.
- Added safe inline-keyboard normalization, including `action` callback aliases.
- Added single-file offset helpers for hosts with existing getUpdates offset files.
- Updated ingress and sender objects to use the new generic helpers.

## 0.1.3 - 2026-07-01

- Corrected the public swarmidx scope to the token-backed registry scope.
- Documented the published package as `swarmidx:acastellana/genswarms-telegram@0.1.3`.

## 0.1.2 - 2026-07-01

- Added tuple adapter support for host-specific stores, identity sinks, command routers, inbound effects, session runtimes, and delivery effects.
- Added inbound effects hooks for spam guards, skipped updates, and non-text handling.
- Extended ingress routing so command routers can return GenSwarms sends as well as direct Telegram replies.
- Extended session runtime callbacks with event-aware `ensure_session/3` and structured `deliver_turn/3`.
- Extended sender delivery hooks for logical delivery outcomes, unreachable chats, dry-run delivery, batch metadata, and dashboard delivery status.

## 0.1.1 - 2026-07-01

- Hardened Telegram response classification for dead chats, transient API errors,
  and success bodies without a `result` key.
- Made outbound chunking preserve newline content exactly while still preferring
  newline boundaries and UTF-16-safe hard splits.
- Added sender-compatible `disable_web_page_preview` in sendMessage payloads.
- Added host-compatible identity aliases in parsed events.
- Skipped dedupe writes for malformed non-integer update ids.

## 0.1.0 - 2026-07-01

- Initial reusable Telegram transport package for GenSwarms.
- Added Telegram ingress and sender object handlers.
- Added curl and fake Bot API clients.
- Added update parsing, delivery payloads, safe formatting, webhook helpers, polling helpers, file store, and durable `MEMORY.md` context.
- Added slot-bound reply enforcement, command routing, progress edits, reply threading validation, and package tests.

# Changelog

## Unreleased

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

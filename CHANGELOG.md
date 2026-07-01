# Changelog

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

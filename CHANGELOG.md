# Changelog

## 0.1.1 - 2026-07-01

- Hardened Telegram response classification for dead chats, transient API errors,
  and success bodies without a `result` key.
- Made outbound chunking preserve newline content exactly while still preferring
  newline boundaries and UTF-16-safe hard splits.
- Added sender-compatible `disable_web_page_preview` in sendMessage payloads.
- Added Wingston-compatible identity aliases in parsed events.
- Skipped dedupe writes for malformed non-integer update ids.

## 0.1.0 - 2026-07-01

- Initial reusable Telegram transport package for GenSwarms.
- Added Telegram ingress and sender object handlers.
- Added curl and fake Bot API clients.
- Added update parsing, delivery payloads, safe formatting, webhook helpers, polling helpers, file store, and durable `MEMORY.md` context.
- Added slot-bound reply enforcement, command routing, progress edits, reply threading validation, and package tests.

---
name: genswarms-telegram-use
description: >-
  Wire the genswarms-telegram package into a GenSwarms swarm: Telegram ingress +
  sender objects, agent replies via priv/reply.sh, structured cards, and the
  bound-slot security model. Use when adding Telegram to a swarm, sending
  messages/cards/media from agents or objects, or debugging "why doesn't my
  agent's reply reach Telegram" (unbound slot, wrong sender source, getUpdates
  conflict). This is the importer's guide — to change the package itself, read
  CONTRIBUTING/README and the test suite.
---

# genswarms-telegram — using the package

Reusable Telegram transport for GenSwarms: an **Ingress** object (updates in) and
a **Sender** object (messages out), with no product persona, policy, quota logic,
or domain commands — those stay in YOUR swarm. `swarmidx:acastellana/genswarms-telegram`.

## Install

```elixir
# mix.exs of the host app
{:genswarms_telegram, github: "genlayerlabs/genswarms-telegram", tag: "v0.2.0"}
```

- `genswarms` is a peer/runtime dependency — the HOST app provides it; the package
  calls `Genswarms.SwarmManager` / `AgentServer` dynamically only when you use
  `session_opts.swarm_name` + `agent_template`.
- Runtime tools for the defaults: `curl` (Client.Curl), `jq` + `swarm-msg`
  (`priv/reply.sh`). No Telegram SDK — the default client is shell-native curl
  and keeps the bot token out of argv (short-lived config/body files).

## Minimal wiring (the two objects)

See `examples/minimal_bot.swarm.exs` for the complete runnable shape:

- `:telegram_sender` → `Genswarms.Telegram.Objects.Sender` with `bot_token`,
  `client: Client.Curl`, `binding_authority: :telegram_ingress`, `slot_prefix`.
- `:telegram_ingress` → `Genswarms.Telegram.Objects.Ingress` with `bot_token`,
  `client`, `sender: :telegram_sender`, `poll_enabled: true`, `session_opts`
  (swarm_name + agent_template with `connections: [:telegram_sender]`), and
  `binding_sinks: [:telegram_sender]`.

Ingress long-polls `getUpdates` (or takes `inject_update` from your webhook
forwarder — `examples/webhook_forwarder.exs`), dedupes updates, spawns/binds a
per-conversation agent through the session runtime, and delivers the user text.

## How an agent replies

The agent NEVER picks a Telegram target. Inside the agent's shell context:

```sh
priv/reply.sh "the reply text"
```

It reads `GENSWARMS_TELEGRAM_CONVERSATION_ID` + `GENSWARMS_TELEGRAM_SENDER_OBJECT`
from the env the runtime set, and sends via `swarm-msg` to the sender — with NO
target in the payload. The sender resolves the target from the caller's **bound
slot**: ingress binds slot ↔ conversation BEFORE user text is delivered, replies
from a bound agent slot go to that conversation only, and an agent-like unbound
slot **fails closed**. Explicit `conversation_id` targets are honored only from
configured sources (`send_sources`, `progress_sources`, `typing_sources`,
`batch_sources`, `slot_reply_sources`) — add YOUR object there if it must target
conversations directly.

## Sending from objects (the protocol)

Everything is a JSON action on the sender object. The full vocabulary (~150
actions: media, polls, cards, streaming drafts, inline queries, business
accounts, stars/gifts, forum topics, invoices…) is enumerated in README
§"Object Protocol"; the ones you reach for first:

- `{"action":"send","conversation_id":"tg:123:0","text":"..."}`
- `{"action":"reply","text":"...","reply_to_message_id":123}` (from a bound slot)
- `{"action":"progress","text":"..."}` — edit-coalesced progress line
- `{"action":"stream_text","draft_id":123,"text":"Working..."}` — draft streaming
- `{"action":"send_card","conversation_id":"tg:123:0","card":{...}}` — structured
  cards; grammar + block types in `docs/telegram-cards.md`, ready payloads in
  `examples/card_actions.exs`; `{"action":"validate_card",...}` checks one
  without sending; `{"action":"capabilities"}` / `{"action":"examples"}` are
  self-describing.

`conversation_id` format is `tg:<chat_id>:<thread_id>` (`ConversationId` module).

## State, memory, workspaces

- Bot transport state (offsets, dedupe): `Store.File` under
  `${XDG_STATE_HOME:-~/.local/state}/genswarms/telegram`.
- Slot workspaces are TEMPORARY (`${TMPDIR:-/tmp}/genswarms-telegram`) — safe to
  wipe. Durable per-conversation `MEMORY.md` (`Context.MemoryMd`) lives in the
  state dir, keyed by bot fingerprint + conversation; the agent sees a copy at
  `<workspace>/MEMORY.md`.
- **`memory_policy` defaults to `:none`** — nothing durable is written unless the
  host opts in (`:dm_only` for private chats, `:all` for groups/topics too).

## Testing

`Client.Fake` is the deterministic test adapter (records Bot API calls, no
network) — use it in CI, always. `mix deps.get && mix format --check-formatted
&& mix compile --warnings-as-errors && mix test`.

## Gotchas

- **`getUpdates` is single-consumer per bot token.** A second poller (your laptop
  vs prod, or live smoke tests in CI) steals updates and the deployed bot goes
  silent intermittently. Live smoke = disposable credentials, explicit release
  step, never regular CI.
- **"Reply never arrives"** → the slot isn't bound (agent spawned outside the
  ingress flow, or reply sent from a non-slot identity). Binding is the ingress's
  job (`binding_sinks`); replies assume the GenSwarms agent slot identity, so
  `priv/reply.sh` must run INSIDE the bound agent's context.
- **"Object X can't send"** → it's not in `send_sources` (fail-closed by design);
  configure the source lists instead of routing through an agent.
- **Webhook mode** — Ingress still owns processing: forward the raw update as
  `{"action":"inject_update","update":{...}}` (see `examples/webhook_forwarder.exs`);
  `Webhook` has the decode/registration helpers.
- Rich sends degrade deliberately: parse-error retries as plain text, photo
  falls back, chunking is rate-limited — don't re-implement retry around the
  sender.

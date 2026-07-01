# GenSwarms Telegram

Reusable Telegram transport and GenSwarms object handlers.

The package gives a swarm Telegram ingress and sender objects without product
persona, private policy, quota logic, or domain commands.

## Install

```elixir
def deps do
  [
    {:genswarms_telegram, github: "genlayerlabs/genswarms-telegram", tag: "v0.1.1"}
  ]
end
```

Runtime tools used by defaults:

- `curl` for `Genswarms.Telegram.Client.Curl`;
- `jq` and `swarm-msg` for `priv/reply.sh`.

## What Importers Get

- `Genswarms.Telegram.Objects.Ingress` — GenSwarms-native Telegram ingress handler
  with `inject_update`, optional `getUpdates` long polling, update dedupe, webhook
  forwarding support, callback acking, group addressing gates, identity hooks, and
  per-conversation session delivery through an injected runtime. Command-router
  replies are sent through Telegram before the update is marked processed.
- `Genswarms.Telegram.Objects.Sender` — outbound Telegram handler with slot-to-chat
  binding, fail-closed agent replies, send/reply/send_batch, typing, progress edits,
  inline keyboards, photo fallback, chunking, parse-error plain-text retry, recent
  reply-tag validation, and a bounded audit trail.
- `Genswarms.Telegram.Client.Curl` — default shell-native Bot API adapter. It keeps
  bot tokens out of argv by using short-lived curl config/body files.
- `Genswarms.Telegram.Client.Fake` — deterministic test adapter.
- `Genswarms.Telegram.Poller` — pure `getUpdates` offset/payload helpers.
- `Genswarms.Telegram.Parser`, `Delivery`, `Format`, `ConversationId`, `Webhook` —
  pure Telegram update, payload, formatting, id, and webhook helpers.
- `Genswarms.Telegram.Store.File` and `Context.MemoryMd` — minimal local defaults
  for bot transport state and durable per-conversation `MEMORY.md`.
- `priv/reply.sh` — agent reply helper using `GENSWARMS_TELEGRAM_CONVERSATION_ID`
  and `GENSWARMS_TELEGRAM_SENDER_OBJECT`. The helper does not include a Telegram
  target in the payload; the sender must resolve the target from the caller's bound
  slot identity.

## What Hosts Provide

The host swarm still owns product commands, persona, policy/privacy objects,
durable application databases, quota/accounting, dashboard sources, and any
product-specific webhooks. The package exposes behaviours for those boundaries.

`Genswarms.Telegram.SessionRuntime.Default` can either call an injected
`session_opts.deliver` function or, when used inside a GenSwarms app, use
`session_opts.swarm_name` plus `session_opts.agent_template` to call
`Genswarms.SwarmManager` / `Genswarms.Agents.AgentServer` dynamically. The
default runtime uses a bounded opaque slot pool; if a slot is reused it unbinds
the previous conversation before binding the new one. GenSwarms object binding is
serialized with an object-state barrier before user text is delivered. Production
systems can replace the runtime when they need a different persistence, spawn, or
eviction policy.

## Defaults

- App: `:genswarms_telegram`
- Modules: `Genswarms.Telegram.*`
- Swarmidx ref: `swarmidx:genlayerlabs/genswarms-telegram@0.1.1`
- Sender object: `:telegram_sender`
- Ingress object: `:telegram_ingress`
- Agent conversation env: `GENSWARMS_TELEGRAM_CONVERSATION_ID`
- Reply helper sender env: `GENSWARMS_TELEGRAM_SENDER_OBJECT`
- Linux state dir: `${XDG_STATE_HOME:-$HOME/.local/state}/genswarms/telegram`
- Workspace root: `${TMPDIR:-/tmp}/genswarms-telegram`
- Memory policy: DMs only by default; use `memory_policy: :all` to persist group
  or topic memory.

## Client Adapters

`Genswarms.Telegram.Client.Curl` is the default runtime adapter. It keeps bot
tokens out of argv by writing the Telegram URL to a short-lived curl config file.

`Genswarms.Telegram.Client.Fake` is the test adapter and records Bot API calls
without network access.

Normal CI should use `Client.Fake`. Live Telegram smoke tests should be explicit
release checks with disposable credentials, because `getUpdates` is single-consumer
per bot token.

## Security Model

Agents do not choose Telegram targets. Sender binds an opaque slot to a
conversation id and forces replies from that slot back to the bound conversation.
Agent-like unbound slots fail closed. Explicit `conversation_id` targets are
accepted only from configured sender sources such as the ingress object or batch
senders. This assumes replies arrive at the sender from the GenSwarms agent slot
identity; shell helpers must be executed inside that bound agent context. In the
default GenSwarms runtime, ingress performs the sender binding before delivering
user text to the agent.

Durable `MEMORY.md` files live outside reusable slot workspaces:

```text
<state_dir>/<bot_fingerprint>/conversations/<encoded_conversation_id>/MEMORY.md
```

The agent can see a copy at `<workspace>/MEMORY.md`, but slot workspaces are
temporary and can be wiped safely.

By default, `Ingress` uses `memory_policy: :dm_only`, so group and topic messages
do not create durable `MEMORY.md` files unless the host opts in.

## Object Protocol

Ingress:

- `{"action":"inject_update","update":{...}}`
- `{"action":"status"}`

Sender:

- `{"action":"reply","text":"...","reply_to_message_id":123}`
- `{"action":"send","conversation_id":"tg:123:0","text":"..."}`
- `{"action":"send_batch","recipients":[{"conversation_id":"tg:123:0"}],"text":"..."}`
- `{"action":"progress","text":"...","conversation_id":"tg:123:0"}`
- `{"action":"typing","conversation_id":"tg:123:0","message_id":123}`
- `{"action":"bind_session","slot":"telegram_agent_0","conversation_id":"tg:123:0"}`
- `{"action":"unbind_session","slot":"telegram_agent_0"}`
- `{"action":"slot_reply","slot":"telegram_agent_0","content":"..."}`
- `{"action":"audit"}`

Configure `send_sources`, `progress_sources`, `typing_sources`, `batch_sources`,
and `slot_reply_sources` when non-ingress objects need to target Telegram
conversations directly.

## Testing

```sh
mix deps.get
mix format --check-formatted
mix compile --warnings-as-errors
mix test
```

Optional live Telegram smoke tests should use separate credentials and should
not be required in regular CI.

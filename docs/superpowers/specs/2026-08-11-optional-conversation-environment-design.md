# Optional Conversation Environment Design

## Goal

Let hosts use `Genswarms.Telegram.SessionRuntime.Default` without exposing the
raw Telegram conversation ID to an agent backend, while preserving the current
behavior by default.

## Configuration

Add `session_opts.inject_conversation_env`. It defaults to `true`.

- When `true` or absent, the runtime adds the conversation ID under
  `conversation_env`, which continues to default to
  `GENSWARMS_TELEGRAM_CONVERSATION_ID`.
- When `false`, the runtime does not add any conversation-ID environment entry.
  `extra_env` remains unchanged, including any host-provided entry that happens
  to use the configured conversation-variable name.

## Runtime Design

Build `session.env` once in `ensure_session/2`. Start with `extra_env` and add
the conversation entry only when `inject_conversation_env` is not `false`.
Existing backend construction continues to copy `session.env` into bwrap,
Docker, and local/default backend options, so no backend-specific branches are
needed.

The session's host-side `conversation_id`, slot lease, workspace selection,
eviction metadata, binding calls, bind/unbind payloads, and binding barrier are
unchanged. Ingress therefore still completes binding before delivering a turn.

## Error Handling

The option is disabled only by the boolean value `false`; missing or other
values retain the backward-compatible behavior. Existing validation and backend
errors are unaffected.

## Tests

Extend the default-runtime tests to prove:

- absent configuration still injects the default variable;
- a configured `conversation_env` is still honored by default;
- disabling injection preserves unrelated `extra_env` entries and adds no raw
  conversation ID;
- bwrap, Docker, and local backend specs receive only the preserved environment
  when injection is disabled;
- with injection disabled, ingress still binds the host-side conversation ID
  before delivering the turn.

Document the option alongside the default session-runtime configuration in the
README.

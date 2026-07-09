# GenSwarms Telegram 0.5 — the bot-kit release (spec)

Status: approved design (Albert, 2026-07-09) · Origin: marbleapp_bot
retrospective — the first second consumer spent ~6h rediscovering knowledge
that lived only in wingston's config. 0.5 ships that knowledge as package
defaults. Companion docs in the marbleapp_bot repo: `docs/friction-log.md`,
`docs/retrospective-2026-07-09.md`.

## Goal

A new bot = a token + (optionally) a SOUL.md. Everything else — agent
template, reply wrappers, skill mechanics, persona fallback, send
observability — ships in this package with correct defaults. Acceptance:
the in-repo **blank bot** answers a DM with zero bot-authored files.

## Non-negotiable constraints

- **Additive only.** 0.5.0 is a no-op for existing consumers: no changed
  defaults, no changed shapes, new config keys all optional with
  behavior-preserving defaults. Anything that can't meet this bar moves to
  0.6 (explicitly: the wingston session-runtime extraction is OUT).
- **Consumer matrix as merge gate.** Every PR runs wingston's and marble's
  harnesses against the branch (sibling checkouts) before merge. Marble
  additionally DELETES its hand-rolled copy of whatever the PR ships and
  adopts the package version — extraction proven, not duplicated.
- **Placeholders announce themselves** (operator requirement): the default
  persona says in its own voice that it's the blank bot awaiting
  replacement; boot logs name each skill file as `package default` vs
  `bot-provided`; docs lead with "replace the placeholder".

## The five PRs

### PR-A — agent wrappers in priv (`priv/agent-bin/`)
`reply.sh` (move from priv/, keep a symlink for back-compat), `card.sh`,
`draft.sh` — parameterized by the conversation-env var name (already env-
driven). New helpers:
- `Genswarms.Telegram.AgentBin.ro_binds/0` → the bwrap bind list (wrappers →
  `/usr/local/bin/*`), for `extra_ro_binds`.
- `Genswarms.Telegram.AgentBin.local_path/0` → a dir of exec-named symlinks
  for `:local` backends (PATH prepend).
Tests: shellcheck-in-CI for the scripts; helpers return existing paths.

### PR-B — `default_agent_template/1`
`Genswarms.Telegram.AgentTemplate.default(opts)` returns the dynamic-spawn
template with everything marble had to learn the hard way:
- backend opts INSIDE the tuple (OpPolicy forbids host-access keys in
  dynamic `:config`) — documented in the function docs with the why;
- `:sender` in connections (the reply path — Router drops the send with only
  a warning if absent), plus caller's extra connections/incoming;
- platform backend selection (bwrap on Linux, mock on darwin, `opts` /
  env override), wired to PR-A's binds/PATH per backend;
- `request_extra` pass-through for router policies.
Opts override everything; the function only assembles safe defaults.
Tests: shape assertions incl. "never emits :config", ":sender always
present", per-platform backend; property: any opts keep those invariants.

### PR-C — skills runtime defaults + placeholder persona (`priv/skills-pack/`)
Files: `using-objects.md` (the reply-discipline index: "plain text goes
NOWHERE", one-reply-per-turn, never echo envelopes/raw JSON — the rules
marble added after live leaks), `PLACEHOLDER-SOUL.md` (honest placeholder:
competent, friendly, and explicit — "I'm a blank bot; my operator hasn't
given me a personality yet. Operator: create skills/SOUL.md to replace
me."), `objects-help/` stubs for the package's own objects.
Mechanism (**runtime defaults + overlay**): a skills resolver merges
`package defaults ← bot skills dir` per FILE (bot file wins; SOUL.md
presence drops the placeholder). Ingress/session_opts gain optional
`skills_pack: true | dir-override | false` (default **false** in 0.5 —
additive; blank bot and generator turn it on; 0.6 may flip the default).
Boot log: one line per resolved file with its origin.
Tests: overlay precedence, placeholder drop-out, log lines.

### PR-D — send observability
Sender config gains `metrics: object_name | nil` (default nil = today).
When set: fire-and-forget `reply_sent` / `reply_failed` (+`card_sent`)
counter bumps to that object (metrics-package wire shape). Dry-run sends log
one INFO line (`[sender] DRY-RUN would send to tg:…: "…"` truncated) —
silent success is indistinguishable from silent failure today.
Tests: counters emitted iff configured; dry-run line present; nil config
byte-identical behavior (existing suite must not change).

### PR-E — release CI
Workflow: on tag push → run suite → `gsp publish` to the notary
(`SWARMIDX_TOKEN_GENLAYERLABS` secret) → `gsp resolve` verify → GitHub
release with changelog section. Kills the "tagged but never published"
class (0.4.5 shipped that way). Also a `mix swarmidx.check` task: every
`attested.()` ref in a given config resolves on the notary.

## The blank bot (acceptance)

`examples/blank_bot/` — a runnable swarm config using ONLY package pieces:
ingress + sender (token env), `AgentTemplate.default/1`, `skills_pack:
true`, no bot skills dir. Docs walk: BotFather token → `.env` → run → DM →
placeholder persona answers and tells you to give it a soul. CI boots it
with a fake token (poll off) as the integration test of A+B+C together.
README gains a "Start here" section fronting it; the placeholder-replacement
path (`skills/SOUL.md`) is step 1 of the walkthrough.

## Consumer follow-ups (separate repos, after 0.5.0 is notarized)

- marble: adopt A (delete config/local-bin + wrapper copies), B (delete
  hand-rolled template), C (keep its 4 skills as the overlay — mechanics
  file comes from the pack; delete marble-using-objects.md only if the pack
  version covers its object list via objects-help), D (wire `metrics:
  :metrics` — closes the reply_sent=0 blind spot). Bump attested pin.
- wingston: no changes required (additive); opportunistically adopt D.

## Out of scope (0.6 candidates)

Session-runtime extraction (coalescing/turn-buffer/pending-flush),
`skills_pack` default flip, webhook ingress hardening, the `genswarms new`
generator (engine repo), spam-guard default-on.

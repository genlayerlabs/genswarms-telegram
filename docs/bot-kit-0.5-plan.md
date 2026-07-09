# GenSwarms Telegram 0.5 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development. Implementers are Codex subagents (`--cd /Users/albert/dev/genswarms-telegram --sandbox workspace-write`); the controller runs tests and commits. **Every task's requirements = its section in `docs/bot-kit-0.5-spec.md` (read it first, verbatim authority) + this plan's mechanics.**

**Goal:** Ship the five additive PRs + blank-bot acceptance example from the spec; wingston byte-identical, marble adopts and deletes its copies.

**Repo:** /Users/albert/dev/genswarms-telegram, branch per task off `feat/0.5-bot-kit` (PR-A → `feat/0.5-agent-bin`, etc.), merged back into `feat/0.5-bot-kit`; that branch becomes the 0.5.0 release PR to main.

## Global Constraints

- ADDITIVE ONLY: existing test suite must pass unchanged on every task (`mix test` — currently green at v0.4.6+). A diff to an existing test = spec violation, stop.
- Consumer-matrix gate before marking any task complete (controller runs):
  - `cd ~/dev/wingstonrallybot && mix run tests/test_harness.exs` (sibling resolution picks the branch; siblings must stay artifact-clean for attestation — `mv` artifacts to scratch, never publish-affecting)
  - `cd ~/dev/marbleapp_bot && mix run tests/test_harness.exs`
  - NOTE: both consumers pin attested digests for the PUBLISHED 0.4.6 — their `mode: :verify` re-hash will FAIL against a modified sibling. For matrix runs set `GENSWARMS_TELEGRAM_PATH` to the branch checkout AND relax via each harness's documented dev override, or run with the consumer's attestation env override if present; if neither exists, the matrix gate for code-affecting tasks is: consumer harness with its telegram pin temporarily set to `%{path: sibling}` un-attested handler (a one-line local, uncommitted edit — controller applies, runs, reverts).
- Wrappers/scripts: POSIX sh, shellcheck-clean.
- Every commit ends with the Claude co-author trailer.
- Placeholder self-announcement requirement (spec "Non-negotiable constraints") binds tasks C and F.

## Task map

### T1 (PR-A) — `priv/agent-bin/` + AgentBin helpers
Files: move `priv/reply.sh` → `priv/agent-bin/reply.sh` (leave `priv/reply.sh` as a relative symlink), add `card.sh`/`draft.sh` (port from `~/dev/marbleapp_bot/config/` — strip the MARBLE_ env name back to the package default `GENSWARMS_TELEGRAM_CONVERSATION_ID`, honoring an env-name override the same way reply.sh does — read reply.sh first), `lib/genswarms/telegram/agent_bin.ex` (`ro_binds/0`, `local_path/0` per spec), tests `test/genswarms/telegram/agent_bin_test.exs` (paths exist+executable; ro_binds shape; local_path dir contains exec-named entries), CI shellcheck step if a workflow exists (else a `mix` alias `test.scripts` running shellcheck when available).
Wrinkle the implementer must resolve by READING the scripts: marble's card.sh/draft.sh use `MARBLE_CONVERSATION_ID`; the package convention is the `conversation_env` session opt — scripts must read the var whose NAME arrives via `SWARM_MSG_CONVERSATION_ENV` fallback chain exactly as priv/reply.sh does today (mirror it, don't invent).

### T2 (PR-B) — `AgentTemplate.default/1`
Files: `lib/genswarms/telegram/agent_template.ex`, `test/genswarms/telegram/agent_template_test.exs`.
Interface (spec PR-B): `default(opts \\ %{})` → template map consumed by `SessionRuntime.Default` (`maybe_spawn_agent` — read it; the template must round-trip through `drop_route_keys/backend_with_session` correctly). Invariants (each a test): never a `:config` key; `:sender` ∈ connections even when caller passes connections (union, not replace); backend per platform/env/opts (`{:bwrap, opts}` w/ AgentBin.ro_binds on Linux default; `:mock` darwin default; `:local` selectable — document that `:local` needs engine ≥ the PR-85 fix); `request_extra`/`skills`/`presets` pass-through; opts deep-override wins except the invariants (assert overriding CANNOT remove :sender or introduce :config — invariant beats caller).

### T3 (PR-C) — skills pack + resolver + placeholder persona
Files: `priv/skills-pack/{using-objects.md,PLACEHOLDER-SOUL.md,objects-help/…}`, `lib/genswarms/telegram/skills_pack.ex` (resolver: `resolve(bot_skills_dir | nil, opts)` → ordered file list with origins; per-file override by basename; SOUL.md presence drops PLACEHOLDER-SOUL.md), session_opts/ingress wiring behind `skills_pack:` (default false — additive; when truthy, resolver output feeds the same skills plumbing `skills:` uses today — find the merge point in ingress/session_runtime and extend, don't fork), boot log line per file with origin. Prose: using-objects.md distilled from `~/dev/marbleapp_bot/skills/marble-using-objects.md` (the reply-discipline rules generalized — no marble objects), PLACEHOLDER-SOUL.md per spec (self-announcing, tells operator to create skills/SOUL.md). Controller reviews prose personally.
Tests: resolver precedence matrix; skills_pack:false = zero behavior change (existing suite green is the assertion); log-line origins.

### T4 (PR-D) — send observability
Files: sender.ex (surgical: the send/reply result fold + dry-run branch), `test/…/sender_metrics_test.exs`.
`metrics:` config (nil default): on delivered reply/send bump `reply_sent`, on failure `reply_failed`, cards `card_sent` — fire-and-forget `deliver_message` in the metrics package's wire shape (read `~/dev/genswarms-objects/packages/metrics` interface). Dry-run: one INFO line, truncated text. Tests: counters iff configured; nil = no messages (assert via fake router capture); dry-run log via CaptureLog. EXTRA CAUTION: this touches live wingston code paths — the existing sender suite must be untouched and green.

### T5 (PR-E) — release CI + swarmidx check
Files: `.github/workflows/release.yml` (tag `v*` → mix test → gsp publish (secret `SWARMIDX_TOKEN`) → gsp resolve verify → gh release), `lib/mix/tasks/swarmidx.check.ex` (parse a swarm exs for `attested.(ref, digest, …)` pairs → `gsp resolve` each → digest equality report; pure-CLI shell-out to gsp, path via env GSP_BIN). Tests: mix task against a fixture config with a known-good + known-bad pin (resolve mocked via a fake gsp script on PATH).

### T6 — blank bot (acceptance)
Files: `examples/blank_bot/{README.md,blank_bot.swarm.exs,.env.example}`, CI job booting it (poll off, fake token, mock backend) asserting: objects supervised, skills resolve to all-package-default origins, placeholder SOUL present, AgentTemplate invariants hold in the loaded config. README: the token→DM walkthrough, step 1 of "make it yours" = create skills/SOUL.md (placeholder-replacement requirement).

### T7 — consumer matrix + release
Controller-driven: full matrix run (both harnesses per Global Constraints), marble adoption PRs in the marbleapp-bot repo (delete config/local-bin+wrappers → AgentBin; delete hand-rolled template → AgentTemplate.default; skills_pack:true keeping marble's 4 files as overlay; sender metrics: :metrics), CHANGELOG, version 0.5.0, tag, publish via the new CI, `gsp resolve` verify, marble attested-pin bump + live smoke (`/start` + one NL turn), wingston untouched (optionally a follow-up PR for metrics adoption).

## Sequencing

T1 → T2 (uses AgentBin) → T3 (independent of T2, after T1 for wrapper paths) → T4 (independent) → T5 (independent) → T6 (needs T1–T3) → T7 last. T4/T5 can run interleaved with T2/T3 between reviews.

## Self-review
Spec coverage: PR-A→T1, B→T2, C→T3, D→T4, E→T5, blank bot→T6, consumer follow-ups+release→T7; placeholder requirement bound to T3+T6; additivity enforced via existing-suite-unchanged rule in every task. Deliberate deferrals: none beyond the spec's own out-of-scope list. The attestation-vs-modified-sibling wrinkle in the matrix gate is called out with the exact workaround rather than discovered mid-run.

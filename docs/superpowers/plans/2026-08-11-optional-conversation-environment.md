# Optional Conversation Environment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Allow the default session runtime to omit the raw conversation ID from agent environments without changing host-side identity handling.

**Architecture:** Construct `session.env` once in `ensure_session/2`, conditionally adding the conversation entry unless `inject_conversation_env` is exactly `false`. Existing backend shaping consumes that map unchanged, while ingress binding continues to use the separate host-side conversation ID.

**Tech Stack:** Elixir 1.14+, ExUnit, Mix

## Global Constraints

- `inject_conversation_env` defaults to `true`.
- With `inject_conversation_env: false`, do not add the default or configured conversation-ID variable.
- Preserve `extra_env`, session metadata, workspaces, slot leasing, binding sinks, bind/unbind messages, and binding-before-delivery ordering.
- Add no dependencies or backend-specific opt-out branches.

---

### Task 1: Add the identity-free environment seam

**Files:**
- Modify: `lib/genswarms/telegram/session_runtime/default.ex:25-30`
- Modify: `test/client_store_memory_test.exs:482-663`
- Modify: `test/objects_test.exs:4-14,699-740`
- Modify: `README.md:67-85`

**Interfaces:**
- Consumes: `session_opts.inject_conversation_env :: boolean()` and existing `session_opts.extra_env` / `session_opts.conversation_env` values.
- Produces: `session.env :: map()` with the conversation entry present by default and absent only when `inject_conversation_env` is `false`.

- [ ] **Step 1: Fetch the already-declared test dependency**

Run:

```bash
mix deps.get
```

Expected: the existing `jason` dependency is available; no dependency files are edited.

- [ ] **Step 2: Write failing backend-environment coverage**

Add this test after the existing bwrap spawn test in
`test/client_store_memory_test.exs`:

```elixir
test "default session runtime omits conversation identity from supported backends",
     %{dir: dir} do
  Process.put(:genswarms_telegram_test_parent, self())

  base_opts = %{
    bot_ref: "bot-a",
    workspace_root: Path.join(dir, "identity-free-backends"),
    swarm_name: "telegram-test",
    inject_conversation_env: false,
    conversation_env: "CID",
    extra_env: %{"HOST_ENV" => "1"}
  }

  backends = [
    {:bwrap, {:bwrap, %{extra_env: %{"BACKEND_ENV" => "bwrap"}}}, :extra_env,
     %{"BACKEND_ENV" => "bwrap", "HOST_ENV" => "1"}},
    {:docker, {:docker, "telegram-agent:latest", %{env: %{"BACKEND_ENV" => "docker"}}},
     :env, %{"BACKEND_ENV" => "docker", "HOST_ENV" => "1"}},
    {:local, :local, :extra_env, %{"HOST_ENV" => "1"}}
  ]

  for {name, backend, env_key, expected_env} <- backends do
    conversation_id = "tg:#{name}:0"
    opts = Map.put(base_opts, :agent_template, %{backend: backend})

    assert {:ok, session} = DefaultRuntime.ensure_session(conversation_id, opts)
    assert session.env == %{"HOST_ENV" => "1"}
    assert session.conversation_id == conversation_id
    assert_receive {:swarm_add_agent, "telegram-test", spec, _route_opts}

    backend_opts =
      case spec.backend do
        {:bwrap, backend_opts} -> backend_opts
        {:docker, _image, backend_opts} -> backend_opts
        {:local, backend_opts} -> backend_opts
      end

    assert backend_opts.workspace == session.workspace
    backend_env = Map.fetch!(backend_opts, env_key)
    assert backend_env == expected_env
    refute conversation_id in Map.values(backend_env)
  end
after
  Process.delete(:genswarms_telegram_test_parent)
end
```

The existing tests at `test/client_store_memory_test.exs:387-406` and
`test/client_store_memory_test.exs:482-524` already cover default injection,
custom `conversation_env`, and unrelated `extra_env` preservation when the flag
is absent; keep those assertions unchanged.

- [ ] **Step 3: Write a failing ingress-ordering test using the default runtime**

Add the alias and expose the existing setup directory in `test/objects_test.exs`:

```elixir
alias Genswarms.Telegram.SessionRuntime.Default, as: DefaultRuntime
```

```elixir
{:ok, fake: fake, dir: dir}
```

Then add this test after the existing bind-before-delivery test:

```elixir
test "identity-free default sessions still bind host identity before delivery",
     %{fake: fake, dir: dir} do
  parent = self()

  {:ok, state} =
    Ingress.init(%{
      inject_sources: [:test],
      bot_token: "token",
      client: Fake,
      client_opts: [fake: fake],
      session_runtime: DefaultRuntime,
      session_opts: %{
        workspace_root: Path.join(dir, "identity-free-workspaces"),
        inject_conversation_env: false,
        extra_env: %{"STATIC" => "1"},
        bind: fn session, conversation_id, sinks ->
          send(parent, {:bound, session, conversation_id, sinks})
          :ok
        end,
        deliver: fn session, text ->
          send(parent, {:delivered, session, text})
          :ok
        end
      },
      binding_sinks: [:telegram_sender],
      bot_username: nil
    })

  update = %{
    "update_id" => 7,
    "message" => %{"chat" => %{"id" => 123}, "text" => "hello"}
  }

  {:reply, body, _state} =
    Ingress.handle_message(:test, %{"action" => "inject_update", "update" => update}, state)

  assert Jason.decode!(body)["routed"] == true
  assert_receive first_runtime_event

  assert {:bound, %{env: %{"STATIC" => "1"}}, "tg:123:0", [:telegram_sender]} =
           first_runtime_event

  assert_receive second_runtime_event

  assert {:delivered, %{conversation_id: "tg:123:0", env: %{"STATIC" => "1"}}, text} =
           second_runtime_event

  assert text =~ "hello"
end
```

- [ ] **Step 4: Run the focused tests and verify the new behavior fails**

Run:

```bash
mix test test/client_store_memory_test.exs test/objects_test.exs
```

Expected: FAIL because `session.env` and backend environments still contain
`"CID" => conversation_id`; the existing tests remain green up to the new
assertion.

- [ ] **Step 5: Implement the minimum shared environment branch**

Replace the environment construction in
`lib/genswarms/telegram/session_runtime/default.ex` with:

```elixir
extra_env = Map.get(opts, :extra_env, %{})

env =
  if Map.get(opts, :inject_conversation_env, true) == false do
    extra_env
  else
    Map.put(
      extra_env,
      Map.get(opts, :conversation_env, "GENSWARMS_TELEGRAM_CONVERSATION_ID"),
      conversation_id
    )
  end
```

Do not change the backend constructors or host-side binding flow.

- [ ] **Step 6: Run the focused tests and verify they pass**

Run:

```bash
mix test test/client_store_memory_test.exs test/objects_test.exs
```

Expected: PASS with no warnings.

- [ ] **Step 7: Document the option**

Add this sentence to the default-runtime paragraph in `README.md`:

```markdown
Set `session_opts.inject_conversation_env: false` to omit the raw conversation
ID from `session.env` and bwrap, Docker, or local backend environments; slot
binding continues to use the host-side ID. The option defaults to `true`.
```

Update the Defaults bullet to read:

```markdown
- Agent conversation env: `GENSWARMS_TELEGRAM_CONVERSATION_ID`, injected by
  default; disable with `session_opts.inject_conversation_env: false`.
```

- [ ] **Step 8: Run formatting and the complete verification suite**

Run:

```bash
mix format --check-formatted
mix test
git diff --check
```

Expected: all commands exit 0 with no new warnings beyond the baseline's
intentional negative-path Logger output, and with no whitespace errors.

- [ ] **Step 9: Commit the implementation**

```bash
git add lib/genswarms/telegram/session_runtime/default.ex \
  test/client_store_memory_test.exs test/objects_test.exs README.md
git commit -m "feat: allow identity-free session environments"
```

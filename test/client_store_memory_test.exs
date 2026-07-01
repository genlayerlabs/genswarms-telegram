defmodule Genswarms.Telegram.ClientStoreMemoryTest do
  use ExUnit.Case

  alias Genswarms.Telegram.Client
  alias Genswarms.Telegram.Client.{Curl, Fake}
  alias Genswarms.Telegram.Context.MemoryMd
  alias Genswarms.Telegram.DeliveryEffects
  alias Genswarms.Telegram.IdentitySink
  alias Genswarms.Telegram.InboundEffects
  alias Genswarms.Telegram.OffsetFile
  alias Genswarms.Telegram.Poller
  alias Genswarms.Telegram.Store.File, as: FileStore
  alias Genswarms.Telegram.SessionRuntime.Default, as: DefaultRuntime

  defmodule Elixir.Genswarms.Objects.ObjectServer do
    def deliver_message(swarm_name, object_name, from, content) do
      send(
        Process.get(:genswarms_telegram_test_parent),
        {:object_delivery, swarm_name, object_name, from, content}
      )

      :ok
    end

    def get_state(swarm_name, object_name) do
      send(
        Process.get(:genswarms_telegram_test_parent),
        {:object_barrier, swarm_name, object_name}
      )

      :idle
    end
  end

  defmodule Elixir.Genswarms.SwarmManager do
    def add_agent(swarm_name, spec, route_opts) do
      if parent = Process.get(:genswarms_telegram_test_parent) do
        send(parent, {:swarm_add_agent, swarm_name, spec, route_opts})
      end

      Process.get(:genswarms_telegram_add_agent_return, {:ok, spec})
    end

    def remove_agent(swarm_name, slot) do
      if parent = Process.get(:genswarms_telegram_test_parent) do
        send(parent, {:swarm_remove_agent, swarm_name, slot})
      end

      Process.get(:genswarms_telegram_remove_agent_return, :ok)
    end
  end

  defmodule Elixir.Genswarms.Agents.AgentServer do
    def send_task(swarm_name, slot, text) do
      if parent = Process.get(:genswarms_telegram_test_parent) do
        send(parent, {:agent_send_task, swarm_name, slot, text})
      end

      Process.get(:genswarms_telegram_send_task_return, {:ok, :sent})
    end
  end

  setup do
    dir = Path.join(System.tmp_dir!(), "gst-test-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    Application.put_env(:genswarms_telegram, :state_dir, dir)

    on_exit(fn ->
      Application.delete_env(:genswarms_telegram, :state_dir)
      File.rm_rf(dir)
    end)

    {:ok, dir: dir}
  end

  test "fake client records calls and scripts responses" do
    {:ok, fake} = Fake.start_link([{:ok, %{"id" => 1}}])
    assert {:ok, %{"id" => 1}} = Client.get_me(Fake, fake: fake)
    assert [%{method: :get_me, payload: %{}}] = Fake.calls(fake)
  end

  test "client exposes webhook registration helpers through adapters" do
    {:ok, fake} = Fake.start_link([{:ok, true}, {:ok, true}, {:ok, %{"url" => ""}}])

    assert {:ok, true} =
             Client.set_webhook(Fake, %{url: "https://example.com/telegram"}, fake: fake)

    assert {:ok, true} = Client.delete_webhook(Fake, %{drop_pending_updates: true}, fake: fake)
    assert {:ok, %{"url" => ""}} = Client.get_webhook_info(Fake, fake: fake)

    assert [
             %{method: :set_webhook, payload: %{url: "https://example.com/telegram"}},
             %{method: :delete_webhook, payload: %{drop_pending_updates: true}},
             %{method: :get_webhook_info, payload: %{}}
           ] = Fake.calls(fake)

    assert Client.method_name(:set_webhook) == "setWebhook"
    assert Client.method_name(:delete_webhook) == "deleteWebhook"
    assert Client.method_name(:get_webhook_info) == "getWebhookInfo"
  end

  test "client response classification handles rate limits and dead chats" do
    assert {:ok, %{"message_id" => 1}} =
             Client.classify_response(200, ~s({"ok":true,"result":{"message_id":1}}))

    assert {:error, {:rate_limited, 2, _}} =
             Client.classify_response(
               429,
               ~s({"ok":false,"error_code":429,"description":"Too Many","parameters":{"retry_after":2}})
             )

    assert {:error, {:dead_chat, 403, _}} =
             Client.classify_response(
               403,
               ~s({"ok":false,"error_code":403,"description":"bot was blocked by the user"})
             )

    assert {:error, {:dead_chat, 400, _}} =
             Client.classify_response(
               400,
               ~s({"ok":false,"error_code":400,"description":"Bad Request: chat not found"})
             )

    assert {:error, {:transient, 503, _}} =
             Client.classify_response(
               200,
               ~s({"ok":false,"error_code":503,"description":"Service Unavailable"})
             )

    assert {:ok, %{"ok" => true}} = Client.classify_response(200, ~s({"ok":true}))
  end

  test "curl client keeps token out of argv, removes temp files, and redacts failures", %{
    dir: dir
  } do
    argv_log = Path.join(dir, "argv.log")
    ok_curl = Path.join(dir, "curl-ok")

    File.write!(ok_curl, """
    #!/bin/sh
    printf '%s\\n' "$@" > "$ARGV_LOG"
    printf '%s\\n%s' '{"ok":true,"result":{"message_id":99}}' '200'
    """)

    File.chmod!(ok_curl, 0o700)
    System.put_env("ARGV_LOG", argv_log)

    assert {:ok, %{"message_id" => 99}} =
             Client.send_message(Curl, %{chat_id: 1, text: "hi"},
               token: "SECRET_TOKEN",
               curl_bin: ok_curl
             )

    args = File.read!(argv_log)
    refute args =~ "SECRET_TOKEN"

    config_path = logged_arg_after(args, "--config")
    body_path = logged_arg_after(args, "--data-binary") |> String.trim_leading("@")
    refute File.exists?(config_path)
    refute File.exists?(body_path)

    err_curl = Path.join(dir, "curl-error")

    File.write!(err_curl, """
    #!/bin/sh
    printf '%s\\n' 'SECRET_TOKEN leaked by curl' >&2
    exit 7
    """)

    File.chmod!(err_curl, 0o700)

    assert {:error, {:curl, 7, redacted}} =
             Client.send_message(Curl, %{chat_id: 1, text: "hi"},
               token: "SECRET_TOKEN",
               curl_bin: err_curl
             )

    assert redacted =~ "[REDACTED]"
    refute redacted =~ "SECRET_TOKEN"
  after
    System.delete_env("ARGV_LOG")
  end

  test "poller fetches updates from persisted offset without committing before handling" do
    {:ok, fake} = Fake.start_link()
    Fake.push_response(fake, {:ok, [%{"update_id" => 4}, %{"update_id" => 6}]})

    assert {:ok, updates, 7} =
             Poller.fetch_updates(Fake, FileStore, "bot-a",
               client_opts: [fake: fake, token: "token"],
               timeout_s: 1
             )

    assert length(updates) == 2
    assert FileStore.read_offset("bot-a") == 0

    [call] = Fake.calls(fake)
    assert call.method == :get_updates
    assert call.payload.offset == 0
    assert call.payload.timeout == 1

    assert :ok = FileStore.write_offset("bot-a", 7)
    assert FileStore.read_offset("bot-a") == 7
  end

  test "poller reports malformed or failed getUpdates responses without advancing offsets" do
    {:ok, fake} =
      Fake.start_link([
        {:ok, %{"not" => "a list"}},
        {:error, {:transient, 502, "bad gateway"}}
      ])

    assert {:error, {:bad_updates_result, %{"not" => "a list"}}} =
             Poller.fetch_updates(Fake, FileStore, "bot-poller",
               client_opts: [fake: fake, token: "token"],
               allowed_updates: ["message", "callback_query"],
               timeout_s: 9
             )

    assert {:error, {:transient, 502, "bad gateway"}} =
             Poller.fetch_updates(Fake, FileStore, "bot-poller",
               client_opts: [fake: fake, token: "token"]
             )

    [bad_call, error_call] = Fake.calls(fake)
    assert bad_call.payload.allowed_updates == ["message", "callback_query"]
    assert bad_call.payload.timeout == 9
    assert error_call.payload.offset == 0
    assert FileStore.read_offset("bot-poller") == 0

    assert Poller.next_offset(4, [%{"update_id" => "bad"}, %{"update_id" => 8}]) == 9
    assert Poller.next_offset(4, [%{"update_id" => "bad"}]) == 4
  end

  test "offset file helper namespaces token paths and treats invalid files as zero", %{dir: dir} do
    base = Path.join(dir, "offset")

    assert OffsetFile.path(nil, "token") == nil
    assert OffsetFile.path(base, nil) == base
    assert OffsetFile.path(base, "") == base

    tagged_path = OffsetFile.path(base, "123:SECRET")
    assert tagged_path =~ base <> "."
    refute tagged_path =~ "SECRET"
    assert String.ends_with?(tagged_path, OffsetFile.token_tag("123:SECRET"))

    assert OffsetFile.read(nil) == 0
    assert OffsetFile.read(Path.join(dir, "missing")) == 0

    File.write!(tagged_path, " 42\n")
    assert OffsetFile.read(tagged_path) == 42

    File.write!(tagged_path, "-1")
    assert OffsetFile.read(tagged_path) == 0

    File.write!(tagged_path, "not-an-int")
    assert OffsetFile.read(tagged_path) == 0

    assert :ok = OffsetFile.write(tagged_path, 99)
    assert OffsetFile.read(tagged_path) == 99
    assert :ok = OffsetFile.write(tagged_path, -1)
    assert OffsetFile.read(tagged_path) == 99
    assert :ok = OffsetFile.write(nil, 100)
  end

  test "file store namespaces offsets and dedupe by bot ref" do
    assert FileStore.read_offset("bot-a") == 0
    assert :ok = FileStore.write_offset("bot-a", 42)
    assert FileStore.read_offset("bot-a") == 42
    assert FileStore.read_offset("bot-b") == 0

    assert :new = FileStore.mark_update_seen("bot-a", 10)
    assert :duplicate = FileStore.mark_update_seen("bot-a", 10)
    assert :new = FileStore.mark_update_seen("bot-b", 10)
  end

  test "file store and memory paths sanitize configured bot refs", %{dir: dir} do
    cid = "tg:123:0"

    state_path = FileStore.state_path("../bad/bot")
    memory_path = MemoryMd.memory_path("../bad/bot", cid)

    assert String.starts_with?(Path.expand(state_path), Path.expand(dir))
    assert String.starts_with?(Path.expand(memory_path), Path.expand(dir))
    refute state_path =~ "../"
    refute memory_path =~ "../"
  end

  test "file store recovers from corrupt JSON as default state" do
    path = FileStore.state_path("bot-corrupt")
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, "{not-json")

    assert FileStore.read_offset("bot-corrupt") == 0
    assert :new = FileStore.mark_update_seen("bot-corrupt", 1)
    assert :duplicate = FileStore.mark_update_seen("bot-corrupt", 1)
  end

  test "memory md persists by conversation outside workspace and can be exposed" do
    workspace = Path.join(System.tmp_dir!(), "gst-ws-#{System.unique_integer([:positive])}")
    cid = "tg:123:0"

    assert :ok = MemoryMd.init_session("bot-a", cid, %{workspace: workspace})
    assert File.exists?(Path.join(workspace, "MEMORY.md"))

    assert :ok = MemoryMd.after_turn("bot-a", cid, :user, "hello\nthere", %{})
    assert MemoryMd.before_turn("bot-a", cid, "", %{}) =~ "user: hello there"

    refute MemoryMd.before_turn("bot-a", "tg:999:0", "", %{}) =~ "hello there"
    assert :ok = MemoryMd.delete("bot-a", cid)
    refute File.exists?(MemoryMd.memory_path("bot-a", cid))
  end

  test "memory md trims large histories and sanitizes multiline turns", %{dir: dir} do
    workspace = Path.join(dir, "memory-workspace")
    cid = "tg:trim:0"

    assert :ok = MemoryMd.init_session("bot-trim", cid, %{workspace: workspace})
    assert File.exists?(Path.join(workspace, "MEMORY.md"))

    assert :ok =
             MemoryMd.after_turn(
               "bot-trim",
               cid,
               :assistant,
               "line 1\r\nline 2\n" <> String.duplicate("x", 2_500),
               %{max_bytes: 120}
             )

    body = File.read!(MemoryMd.memory_path("bot-trim", cid))
    assert byte_size(body) <= 130
    refute body =~ "\r"
    refute body =~ "line 1\nline 2"

    assert byte_size(MemoryMd.before_turn("bot-trim", cid, "", %{max_bytes: 50})) <= 50
  end

  test "noop effect adapters preserve contract defaults" do
    assert DeliveryEffects.Noop.before_send(%{}) == :ok
    assert DeliveryEffects.Noop.after_send(%{}, {:ok, true}) == :ok
    assert DeliveryEffects.Noop.delivery_failed(%{}, :boom) == :ok
    assert DeliveryEffects.Noop.redact_outbound("hello", %{}) == "hello"
    assert DeliveryEffects.Noop.after_delivery(%{}, %{ok: true}, %{}) == :ok
    assert DeliveryEffects.Noop.on_unreachable("tg:1:0", :blocked, %{}) == :ok

    assert IdentitySink.Noop.upsert_identity("bot", "tg:1:0", %{}) == :ok
    assert IdentitySink.Noop.mark_reachable("bot", "tg:1:0", %{}) == :ok
    assert IdentitySink.Noop.mark_unreachable("bot", "tg:1:0", :blocked) == :ok

    assert InboundEffects.Noop.init([]) == {:ok, %{}}
    assert InboundEffects.Noop.before_route(%{id: 1}, %{}, %{seen: 1}) ==
             {:cont, %{id: 1}, %{seen: 1}}

    assert InboundEffects.Noop.on_non_text(%{}, %{}, %{seen: 1}) == {:ok, %{seen: 1}}
    assert InboundEffects.Noop.on_skipped(%{}, :duplicate, %{}, %{seen: 1}) == {:ok, %{seen: 1}}
    assert InboundEffects.Noop.after_routed(%{}, :ok, %{}, %{seen: 1}) == {:ok, %{seen: 1}}
  end

  test "default session runtime confines bot refs and preserves workspace by default", %{dir: dir} do
    root = Path.join(dir, "workspaces")

    assert {:ok, session} =
             DefaultRuntime.ensure_session("tg:123:0", %{
               bot_ref: "../bad/bot",
               workspace_root: root,
               pool_size: 4
             })

    assert String.starts_with?(Path.expand(session.workspace), Path.expand(root))
    refute session.workspace =~ "../"

    marker = Path.join(session.workspace, "marker.txt")
    File.write!(marker, "kept")

    assert {:ok, session2} =
             DefaultRuntime.ensure_session("tg:123:0", %{
               bot_ref: "../bad/bot",
               workspace_root: root,
               pool_size: 4
             })

    assert session2.workspace == session.workspace
    assert File.read!(marker) == "kept"
  end

  test "default session runtime supports slot workspaces, patterns, injected delivery, and teardown",
       %{dir: dir} do
    root = Path.join(dir, "runtime-shapes")

    assert DefaultRuntime.workspace_root(%{workspace_root: root}) == root

    opts = %{
      bot_ref: "bot-a",
      workspace_root: root,
      workspace_by: :slot,
      pool_size: 1,
      slot_prefix: "agent/slash",
      extra_env: %{"STATIC" => "1"},
      conversation_env: "CID"
    }

    assert {:ok, session} = DefaultRuntime.ensure_session("tg:123:0", opts)
    assert session.slot == :agent_slash_0
    assert session.workspace == Path.join(root, "agent_slash_0")
    assert session.env == %{"STATIC" => "1", "CID" => "tg:123:0"}

    assert {:delivered, :agent_slash_0, "hello"} =
             DefaultRuntime.deliver_to_session(session, "hello", %{
               deliver: fn delivered_session, text ->
                 {:delivered, delivered_session.slot, text}
               end
             })

    assert :ok =
             DefaultRuntime.teardown_session(
               session,
               :normal,
               Map.put(opts, :wipe_workspace, true)
             )

    refute File.exists?(session.workspace)

    pattern_opts = %{
      bot_ref: "bot-a",
      workspace_root: root,
      workspace_pattern: Path.join(root, "{bot_ref}/{slot}/{conversation_id}")
    }

    assert {:ok, patterned} = DefaultRuntime.ensure_session("tg:1:7", pattern_opts)
    assert patterned.workspace =~ "/bot-a/telegram_agent_"
    refute patterned.workspace =~ "tg:1:7"
  end

  test "default session runtime uses a bounded opaque slot pool", %{dir: dir} do
    root = Path.join(dir, "pooled-workspaces")
    opts = %{bot_ref: "bot-a", workspace_root: root, pool_size: 2, slot_prefix: "telegram_agent"}

    assert {:ok, first} = DefaultRuntime.ensure_session("tg:1:0", opts)
    assert {:ok, second} = DefaultRuntime.ensure_session("tg:2:0", opts)
    refute first.slot == second.slot

    assert {:ok, first_again} = DefaultRuntime.ensure_session("tg:1:0", opts)
    assert first_again.slot == first.slot

    assert {:ok, third} = DefaultRuntime.ensure_session("tg:3:0", opts)
    assert third.slot == second.slot
    assert third.evicted == %{conversation_id: "tg:2:0", slot: second.slot}

    assert {:ok, second_again} = DefaultRuntime.ensure_session("tg:2:0", opts)
    assert second_again.evicted == %{conversation_id: "tg:1:0", slot: first.slot}
  end

  test "default session runtime exposes eviction during binding", %{dir: dir} do
    parent = self()
    root = Path.join(dir, "binding-workspaces")

    opts = %{
      bot_ref: "bot-a",
      workspace_root: root,
      pool_size: 1,
      bind: fn session, cid, sinks ->
        send(parent, {:bound, session, cid, sinks})
        :ok
      end
    }

    assert {:ok, first} = DefaultRuntime.ensure_session("tg:1:0", opts)
    assert :ok = DefaultRuntime.bind_session(first, "tg:1:0", [:telegram_sender], opts)
    assert_receive {:bound, %{evicted: nil}, "tg:1:0", [:telegram_sender]}

    assert {:ok, second} = DefaultRuntime.ensure_session("tg:2:0", opts)
    assert second.slot == first.slot
    assert second.evicted == %{conversation_id: "tg:1:0", slot: first.slot}

    assert :ok = DefaultRuntime.bind_session(second, "tg:2:0", [:telegram_sender], opts)

    assert_receive {:bound, %{evicted: %{conversation_id: "tg:1:0"}}, "tg:2:0",
                    [:telegram_sender]}
  end

  test "default session runtime spawns GenSwarms agents with session backend and route opts",
       %{dir: dir} do
    Process.put(:genswarms_telegram_test_parent, self())
    root = Path.join(dir, "spawn-workspaces")

    opts = %{
      bot_ref: "bot-a",
      workspace_root: root,
      slot_prefix: "telegram/agent",
      pool_size: 2,
      swarm_name: "telegram-test",
      binding_sinks: [:telegram_sender],
      extra_env: %{"HOST_ENV" => "1"},
      conversation_env: "CID",
      agent_template: %{
        "backend" => {:bwrap, %{extra_env: %{"TEMPLATE_ENV" => "1"}}},
        "skills" => [:telegram_skill],
        "connections" => [:template_sender],
        "incoming" => [:template_incoming],
        "persist" => true,
        role: :assistant
      }
    }

    assert {:ok, session} = DefaultRuntime.ensure_session("tg:spawn:0", opts)

    assert_receive {:swarm_add_agent, "telegram-test", spec, route_opts}

    assert spec.name == session.slot
    assert spec.skills == [:telegram_skill]
    assert spec.role == :assistant
    refute Map.has_key?(spec, "connections")
    refute Map.has_key?(spec, "incoming")
    refute Map.has_key?(spec, "persist")

    assert {:bwrap, backend_opts} = spec.backend
    assert backend_opts.workspace == session.workspace
    assert backend_opts.extra_env == %{
             "TEMPLATE_ENV" => "1",
             "HOST_ENV" => "1",
             "CID" => "tg:spawn:0"
           }

    assert route_opts == [
             connections: [:template_sender],
             incoming: [:template_incoming],
             persist: true
           ]
  after
    Process.delete(:genswarms_telegram_test_parent)
  end

  test "default session runtime evicts old GenSwarms agents before reusing a full slot pool",
       %{dir: dir} do
    Process.put(:genswarms_telegram_test_parent, self())
    root = Path.join(dir, "evict-spawn-workspaces")

    opts = %{
      bot_ref: "bot-a",
      workspace_root: root,
      pool_size: 1,
      swarm_name: "telegram-test",
      binding_sinks: [:fallback_sender],
      agent_template: %{
        backend: :local,
        incoming: [],
        persist: false
      }
    }

    assert {:ok, first} = DefaultRuntime.ensure_session("tg:first:0", opts)
    assert_receive {:swarm_add_agent, "telegram-test", %{name: first_slot}, first_route_opts}
    assert first_slot == first.slot
    assert first_route_opts[:connections] == [:fallback_sender]

    assert {:ok, second} = DefaultRuntime.ensure_session("tg:second:0", opts)
    assert second.slot == first.slot
    assert second.evicted == %{conversation_id: "tg:first:0", slot: first.slot}
    assert_receive {:swarm_remove_agent, "telegram-test", first_slot}
    assert_receive {:swarm_add_agent, "telegram-test", %{name: ^first_slot}, _route_opts}
  after
    Process.delete(:genswarms_telegram_test_parent)
  end

  test "default session runtime reports invalid spawn configuration and add_agent failures",
       %{dir: dir} do
    root = Path.join(dir, "spawn-errors")

    base_opts = %{
      bot_ref: "bot-a",
      workspace_root: root,
      pool_size: 4
    }

    assert {:error, :missing_swarm_name} =
             DefaultRuntime.ensure_session(
               "tg:no-swarm:0",
               Map.put(base_opts, :agent_template, %{backend: :local})
             )

    assert {:error, :invalid_agent_template} =
             DefaultRuntime.ensure_session(
               "tg:bad-template:0",
               base_opts
               |> Map.put(:swarm_name, "telegram-test")
               |> Map.put(:agent_template, "not-a-template")
             )

    Process.put(:genswarms_telegram_add_agent_return, {:error, :boom})

    assert {:error, :boom} =
             DefaultRuntime.ensure_session(
               "tg:add-fails:0",
               base_opts
               |> Map.put(:swarm_name, "telegram-test")
               |> Map.put(:agent_template, %{backend: :local})
             )

    Process.put(:genswarms_telegram_add_agent_return, {:error, {:already_started, self()}})

    assert {:ok, _session} =
             DefaultRuntime.ensure_session(
               "tg:already-started:0",
               base_opts
               |> Map.put(:swarm_name, "telegram-test")
               |> Map.put(:agent_template, %{backend: :local})
             )
  after
    Process.delete(:genswarms_telegram_add_agent_return)
  end

  test "default session runtime delivers through GenSwarms agent server when configured" do
    Process.put(:genswarms_telegram_test_parent, self())
    session = %{slot: :telegram_agent_0, conversation_id: "tg:deliver:0"}

    assert {:ok, :sent} =
             DefaultRuntime.deliver_to_session(session, "hello", %{swarm_name: "telegram-test"})

    assert_receive {:agent_send_task, "telegram-test", :telegram_agent_0, "hello"}

    assert {:error, :no_delivery_adapter} =
             DefaultRuntime.deliver_to_session(session, "hello", %{swarm_name: nil})
  after
    Process.delete(:genswarms_telegram_test_parent)
  end

  test "default session runtime shapes docker and custom backends with session context",
       %{dir: dir} do
    Process.put(:genswarms_telegram_test_parent, self())
    root = Path.join(dir, "backend-shapes")

    docker_opts = %{
      bot_ref: "bot-a",
      workspace_root: root,
      swarm_name: "telegram-test",
      extra_env: %{"HOST_ENV" => "1"},
      agent_template: %{
        backend: {:docker, "telegram-agent:latest", %{env: %{"IMAGE_ENV" => "1"}}}
      }
    }

    assert {:ok, docker_session} = DefaultRuntime.ensure_session("tg:docker:0", docker_opts)
    assert_receive {:swarm_add_agent, "telegram-test", docker_spec, _route_opts}
    assert {:docker, "telegram-agent:latest", docker_backend_opts} = docker_spec.backend
    assert docker_backend_opts.workspace == docker_session.workspace
    assert docker_backend_opts.env["IMAGE_ENV"] == "1"
    assert docker_backend_opts.env["HOST_ENV"] == "1"
    assert docker_backend_opts.env["GENSWARMS_TELEGRAM_CONVERSATION_ID"] == "tg:docker:0"

    custom_opts = %{
      bot_ref: "bot-a",
      workspace_root: root,
      swarm_name: "telegram-test",
      agent_template: %{backend: {:remote, :pool_a}}
    }

    assert {:ok, _custom_session} = DefaultRuntime.ensure_session("tg:custom:0", custom_opts)
    assert_receive {:swarm_add_agent, "telegram-test", %{backend: {:remote, :pool_a}}, _}
  after
    Process.delete(:genswarms_telegram_test_parent)
  end

  test "default session runtime handles nil templates and non-session teardown", %{dir: dir} do
    root = Path.join(dir, "nil-template")

    assert {:ok, session} =
             DefaultRuntime.ensure_session("tg:nil-template:0", %{
               bot_ref: "bot-a",
               workspace_root: root,
               agent_template: nil
             })

    assert session.slot == :telegram_agent_0
    assert :ok =
             DefaultRuntime.teardown_session(%{}, :normal, %{
               workspace_root: root,
               wipe_workspace: false
             })
    assert String.ends_with?(DefaultRuntime.workspace_root(), "genswarms-telegram")
  end

  test "default session runtime does not require a binding adapter for injected delivery" do
    session = %{slot: :telegram_agent_0, conversation_id: "tg:1:0"}
    opts = %{deliver: fn _session, _text -> :ok end}

    assert :ok = DefaultRuntime.bind_session(session, "tg:1:0", [:telegram_sender], opts)
  end

  test "default session runtime binds through GenSwarms with configured authority and barrier" do
    Process.put(:genswarms_telegram_test_parent, self())

    session = %{
      slot: :telegram_agent_0,
      conversation_id: "tg:2:0",
      evicted: %{slot: :telegram_agent_1, conversation_id: "tg:1:0"}
    }

    opts = %{swarm_name: "telegram-test", binding_authority: :custom_ingress}

    assert :ok = DefaultRuntime.bind_session(session, "tg:2:0", [:custom_sender], opts)

    assert_receive {:object_delivery, "telegram-test", :custom_sender, :custom_ingress,
                    unbind_payload}

    assert Jason.decode!(unbind_payload) == %{
             "action" => "unbind_session",
             "slot" => "telegram_agent_1"
           }

    assert_receive {:object_delivery, "telegram-test", :custom_sender, :custom_ingress,
                    bind_payload}

    assert Jason.decode!(bind_payload) == %{
             "action" => "bind_session",
             "slot" => "telegram_agent_0",
             "conversation_id" => "tg:2:0"
           }

    assert_receive {:object_barrier, "telegram-test", :custom_sender}
  after
    Process.delete(:genswarms_telegram_test_parent)
  end

  test "default session runtime reports missing GenSwarms delivery configuration" do
    session = %{slot: :telegram_agent_0, conversation_id: "tg:1:0"}

    assert {:error, :no_delivery_adapter} =
             DefaultRuntime.deliver_to_session(session, "hello", %{})

    assert {:error, :no_binding_adapter} =
             DefaultRuntime.bind_session(session, "tg:1:0", [:telegram_sender], %{})

    assert :ok = DefaultRuntime.bind_session(session, "tg:1:0", [], %{})
  end

  defp logged_arg_after(args, marker) do
    args
    |> String.split("\n", trim: true)
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.find_value(fn
      [^marker, value] -> value
      _ -> nil
    end)
  end
end

defmodule Genswarms.Telegram.ClientStoreMemoryTest do
  use ExUnit.Case

  alias Genswarms.Telegram.Client
  alias Genswarms.Telegram.Client.{Curl, Fake}
  alias Genswarms.Telegram.Store.File, as: FileStore
  alias Genswarms.Telegram.Context.MemoryMd
  alias Genswarms.Telegram.Poller
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

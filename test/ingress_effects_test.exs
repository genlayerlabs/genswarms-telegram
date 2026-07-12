defmodule Genswarms.Telegram.IngressEffectsTest do
  use ExUnit.Case

  alias Genswarms.Telegram.Client.Fake
  alias Genswarms.Telegram.Objects.Ingress
  alias Genswarms.Telegram.Store.File, as: FileStore

  defmodule Effects do
    @behaviour Genswarms.Telegram.InboundEffects

    @impl true
    def init(opts), do: {:ok, %{mode: Map.fetch!(opts, :mode), parent: Map.fetch!(opts, :parent)}}

    @impl true
    def before_route(event, meta, state) do
      send(state.parent, {:before_route, event.type, meta.sender})

      case state.mode do
        :drop -> {:drop, :policy_drop, state}
        :send -> {:send, :telegram_sender, %{action: "reply", text: "intercepted"}, state}
        :send_many -> {:send_many, [{:one, %{action: "one"}}, {:two, "raw"}], state}
        _ -> {:cont, event, state}
      end
    end

    @impl true
    def on_non_text(event, _meta, state) do
      send(state.parent, {:on_non_text, event.media})

      case state.mode do
        :non_text_send ->
          {:send, :telegram_sender, %{action: "reply", text: "photo seen"}, state}

        :non_text_many ->
          {:send_many, [{:telegram_sender, %{action: "reply"}}, {:audit, "raw"}], state}

        _ ->
          {:ok, state}
      end
    end

    @impl true
    def on_skipped(event, reason, _meta, state) do
      send(state.parent, {:skipped, event.conversation_id, reason})
      {:ok, state}
    end

    @impl true
    def after_routed(event, route, _meta, state) do
      send(state.parent, {:after_routed, event.conversation_id, route.kind})
      {:ok, state}
    end
  end

  defmodule MenuRouter do
    @behaviour Genswarms.Telegram.CommandRouter

    @impl true
    def handle_command(_event, _state), do: :ok

    @impl true
    def handle_callback(_event, _state), do: :ok

    @impl true
    def command_menu(:dm, _state), do: [%{command: "start", description: "Start"}]
    def command_menu(:group, _state), do: [%{command: "help", description: "Help"}]
  end

  defmodule MinimalRouter do
    @behaviour Genswarms.Telegram.CommandRouter

    @impl true
    def handle_command(_event, _state), do: :ok

    @impl true
    def handle_callback(_event, _state), do: :ok
  end

  # 0.5.1 scoped menus: privileged verbs shown ONLY in the operators' chat
  # (and one entry narrowed further, to a single member of it).
  defmodule ScopedMenuRouter do
    @behaviour Genswarms.Telegram.CommandRouter

    @impl true
    def handle_command(_event, _state), do: :ok

    @impl true
    def handle_callback(_event, _state), do: :ok

    @impl true
    def command_menu(:dm, _state), do: [%{command: "help", description: "Help"}]
    def command_menu(:group, _state), do: [%{command: "help", description: "Help"}]

    @impl true
    def command_menu_scoped(_state) do
      [
        %{
          scope: %{type: "chat", chat_id: -5_498_467_198},
          commands: [%{command: "reach", description: "Operator DM to one user"}]
        },
        %{
          scope: %{type: "chat_member", chat_id: -5_498_467_198, user_id: 5_681_202},
          commands: [%{command: "wake", description: "Wake a user's agent"}]
        }
      ]
    end
  end

  defmodule BadScopedMenuRouter do
    @behaviour Genswarms.Telegram.CommandRouter

    @impl true
    def handle_command(_event, _state), do: :ok

    @impl true
    def handle_callback(_event, _state), do: :ok

    @impl true
    def command_menu(:dm, _state), do: []
    def command_menu(:group, _state), do: []

    @impl true
    def command_menu_scoped(_state),
      do: [%{scope: %{type: "everywhere"}, commands: []}]
  end

  setup do
    dir =
      Path.join(System.tmp_dir!(), "gst-ingress-effects-#{System.unique_integer([:positive])}")

    File.mkdir_p!(dir)
    Application.put_env(:genswarms_telegram, :state_dir, dir)

    on_exit(fn ->
      Application.delete_env(:genswarms_telegram, :state_dir)
      File.rm_rf(dir)
    end)

    {:ok, fake} = Fake.start_link()
    {:ok, fake: fake}
  end

  test "inbound effects can drop, send, and fan out before route without reaching runtime", %{
    fake: fake
  } do
    drop_state = ingress(fake, :drop)

    {:reply, body, _state} =
      Ingress.handle_message(
        :tester,
        %{"action" => "inject_update", "update" => text_update("hello")},
        drop_state
      )

    assert Jason.decode!(body)["skipped"] == "policy_drop"
    assert_receive {:before_route, :text, :telegram_sender}
    assert_receive {:skipped, "tg:123:0", :policy_drop}

    send_state = ingress(fake, :send)

    assert {:send, :telegram_sender, payload, _state} =
             Ingress.handle_message(
               :tester,
               %{"action" => "inject_update", "update" => text_update("hello")},
               send_state
             )

    assert Jason.decode!(payload) == %{"action" => "reply", "text" => "intercepted"}

    fanout_state = ingress(fake, :send_many)

    assert {:send_many, messages, _state} =
             Ingress.handle_message(
               :tester,
               %{"action" => "inject_update", "update" => text_update("hello")},
               fanout_state
             )

    assert messages == [{:one, Jason.encode!(%{action: "one"})}, {:two, "raw"}]
  end

  test "non-text inbound effects can acknowledge media or emit sender actions", %{fake: fake} do
    ok_state = ingress(fake, :cont)

    {:reply, body, _state} =
      Ingress.handle_message(
        :tester,
        %{"action" => "inject_update", "update" => photo_update()},
        ok_state
      )

    assert Jason.decode!(body)["non_text"] == true
    assert_receive {:on_non_text, "photo"}

    send_state = ingress(fake, :non_text_send)

    assert {:send, :telegram_sender, payload, _state} =
             Ingress.handle_message(
               :tester,
               %{"action" => "inject_update", "update" => photo_update()},
               send_state
             )

    assert Jason.decode!(payload)["text"] == "photo seen"

    many_state = ingress(fake, :non_text_many)

    assert {:send_many, [{:telegram_sender, encoded}, {:audit, "raw"}], _state} =
             Ingress.handle_message(
               :tester,
               %{"action" => "inject_update", "update" => photo_update()},
               many_state
             )

    assert Jason.decode!(encoded)["action"] == "reply"
  end

  test "set_commands reports Telegram client failures and unsupported routers cleanly", %{
    fake: fake
  } do
    Fake.push_response(fake, {:error, {:failed, 400, "bad commands"}})

    menu_state =
      Ingress.new(%{
        client: Fake,
        client_opts: [fake: fake],
        command_router: MenuRouter,
        store: FileStore
      })

    {:reply, body, _state} =
      Ingress.handle_message(:tester, %{"action" => "set_commands"}, menu_state)

    assert Jason.decode!(body)["error"] =~ "set_commands_failed"

    unsupported_state =
      ingress(fake, :cont)
      |> Map.put(:command_router, MinimalRouter)

    {:reply, body, _state} =
      Ingress.handle_message(:tester, %{"action" => "set_commands"}, unsupported_state)

    assert Jason.decode!(body)["command_menus"] == "unsupported"
  end

  test "scoped command menus (0.5.1): per-chat and per-member entries ride set_commands", %{
    fake: fake
  } do
    state =
      Ingress.new(%{
        client: Fake,
        client_opts: [fake: fake],
        command_router: ScopedMenuRouter,
        store: FileStore
      })

    {:reply, body, _state} = Ingress.handle_message(:tester, %{"action" => "set_commands"}, state)

    assert %{"ok" => true, "command_menus" => %{"scoped" => 2}} = Jason.decode!(body)

    [_dm, _group, chat, member] = Fake.calls(fake)
    assert chat.method == :set_my_commands
    assert chat.payload.scope == %{type: "chat", chat_id: -5_498_467_198}
    assert Enum.map(chat.payload.commands, & &1.command) == ["reach"]

    assert member.payload.scope == %{
             type: "chat_member",
             chat_id: -5_498_467_198,
             user_id: 5_681_202
           }

    assert Enum.map(member.payload.commands, & &1.command) == ["wake"]
  end

  test "a malformed scoped entry fails set_commands LOUDLY (a missing operator menu is drift)",
       %{fake: fake} do
    state =
      Ingress.new(%{
        client: Fake,
        client_opts: [fake: fake],
        command_router: BadScopedMenuRouter,
        store: FileStore
      })

    {:reply, body, _state} = Ingress.handle_message(:tester, %{"action" => "set_commands"}, state)

    assert Jason.decode!(body)["error"] =~ "bad_scoped_menu_entry"
  end

  test "routers without command_menu_scoped keep the pre-0.5.1 behavior (scoped: 0)", %{
    fake: fake
  } do
    state =
      Ingress.new(%{
        client: Fake,
        client_opts: [fake: fake],
        command_router: MenuRouter,
        store: FileStore
      })

    {:reply, body, _state} = Ingress.handle_message(:tester, %{"action" => "set_commands"}, state)

    assert %{"ok" => true, "command_menus" => %{"scoped" => 0}} = Jason.decode!(body)
    assert length(Fake.calls(fake)) == 2
  end

  test "poll lifecycle ignores duplicate polls and accounts task crashes without writing offsets",
       %{
         fake: fake
       } do
    ref = make_ref()

    state =
      ingress(fake, :cont)
      |> Map.merge(%{poll_ref: ref, poll_enabled: false, poll_failures: 0})

    assert {:noreply, ^state} = Ingress.handle_info(:poll, state)

    {:noreply, crashed} = Ingress.handle_info({:DOWN, ref, :process, self(), :boom}, state)
    assert crashed.poll_ref == nil
    assert crashed.poll_failures == 1
    assert FileStore.read_offset(crashed.bot_ref) == 0
  end

  test "text updates create/bind/deliver a session once and dedupe repeated update ids", %{
    fake: fake
  } do
    Process.put(:ingress_runtime_parent, self())

    state =
      Ingress.new(%{
        client: Fake,
        client_opts: [fake: fake],
        store: FileStore,
        bot_ref: "bot-runtime",
        inbound_effects: {Effects, %{mode: :cont, parent: self()}},
        fail_open_without_username?: true,
        binding_authority: :custom_ingress,
        binding_sinks: [:telegram_sender, :audit_sink],
        session_runtime: __MODULE__.Runtime,
        session_opts: %{workspace_root: "/tmp/unused"},
        # 0.5.0: inject_update is from-gated; this test injects as :tester
        inject_sources: [:tester]
      })

    update = Map.put(text_update("hello runtime"), "update_id", 101)

    {:reply, body, state} =
      Ingress.handle_message(:tester, %{"action" => "inject_update", "update" => update}, state)

    assert Jason.decode!(body)["routed"] == true
    assert_receive {:runtime_ensure, "tg:123:0", opts}
    assert opts.binding_authority == :custom_ingress
    assert opts.binding_sinks == [:telegram_sender, :audit_sink]
    assert_receive {:runtime_bind, "tg:123:0", [:telegram_sender, :audit_sink]}

    assert_receive {:runtime_deliver, %{slot: :runtime_slot}, "hello runtime", deliver_opts}
    assert deliver_opts.bot_ref == "bot-runtime"
    assert_receive {:after_routed, "tg:123:0", :session}

    assert [%{event: %{conversation_id: "tg:123:0"}, session: %{slot: :runtime_slot}}] =
             state.routed

    {:reply, body, state} =
      Ingress.handle_message(:tester, %{"action" => "inject_update", "update" => update}, state)

    assert Jason.decode!(body)["duplicate"] == true
    assert state.routed |> length() == 1
  after
    Process.delete(:ingress_runtime_parent)
  end

  test "status, interface, malformed messages, ignored updates, and unknown actions are stable",
       %{
         fake: fake
       } do
    state = ingress(fake, :cont)

    assert Ingress.interface() == %{
             actions: ["inject_update", "status", "set_commands", "agent_wake"]
           }
    assert {:noreply, ^state} = Ingress.handle_message(:tester, "{bad", state)

    {:reply, body, state} = Ingress.handle_message(:tester, %{"action" => "status"}, state)
    assert Jason.decode!(body)["routed"] == 0

    {:reply, body, state} =
      Ingress.handle_message(
        :tester,
        %{"action" => "inject_update", "update" => %{"edited_message" => %{}}},
        state
      )

    assert Jason.decode!(body)["ignored"] == true

    {:reply, body, _state} = Ingress.handle_message(:tester, %{"action" => "wat"}, state)
    assert Jason.decode!(body)["error"] == ":unknown_action"
  end

  defp ingress(fake, mode) do
    Ingress.new(%{
      client: Fake,
      client_opts: [fake: fake],
      store: FileStore,
      bot_ref: "bot-effects-#{mode}",
      inbound_effects: {Effects, %{mode: mode, parent: self()}},
      fail_open_without_username?: true,
      session_runtime: NoRuntime,
      # 0.5.0: inject_update is from-gated; these tests inject as :tester
      inject_sources: [:tester]
    })
  end

  defmodule NoRuntime do
    @behaviour Genswarms.Telegram.SessionRuntime

    @impl true
    def ensure_session(_conversation_id, _opts), do: {:error, :should_not_route}

    @impl true
    def deliver_to_session(_session, _text, _opts), do: :ok

    @impl true
    def teardown_session(_session, _reason, _opts), do: :ok
  end

  defmodule Runtime do
    @behaviour Genswarms.Telegram.SessionRuntime

    @impl true
    def ensure_session(conversation_id, opts) do
      send(Process.get(:ingress_runtime_parent), {:runtime_ensure, conversation_id, opts})
      {:ok, %{slot: :runtime_slot, workspace: "/tmp/runtime-workspace"}}
    end

    @impl true
    def bind_session(_session, conversation_id, sinks, _opts) do
      send(Process.get(:ingress_runtime_parent), {:runtime_bind, conversation_id, sinks})
      :ok
    end

    @impl true
    def deliver_to_session(session, text, opts) do
      send(Process.get(:ingress_runtime_parent), {:runtime_deliver, session, text, opts})
      :ok
    end

    @impl true
    def teardown_session(_session, _reason, _opts), do: :ok
  end

  defp text_update(text) do
    %{
      "message" => %{
        "message_id" => 1,
        "chat" => %{"id" => 123, "type" => "private"},
        "from" => %{"id" => 7, "username" => "alice"},
        "text" => text
      }
    }
  end

  defp photo_update do
    %{
      "message" => %{
        "message_id" => 2,
        "chat" => %{"id" => 123, "type" => "private"},
        "from" => %{"id" => 7},
        "photo" => [%{"file_id" => "photo-1"}]
      }
    }
  end
end

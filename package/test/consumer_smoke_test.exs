defmodule Genswarms.Telegram.ConsumerSmokeTest do
  use ExUnit.Case

  alias Genswarms.Telegram.Client.Fake
  alias Genswarms.Telegram.CommandRouter.Basic
  alias Genswarms.Telegram.Objects.{Ingress, Sender}

  defmodule NeutralRuntime do
    @behaviour Genswarms.Telegram.SessionRuntime

    @impl true
    def ensure_session(conversation_id, opts) do
      send(opts.parent, {:session, conversation_id})
      {:ok, %{slot: :neutral_agent_0, conversation_id: conversation_id}}
    end

    @impl true
    def bind_session(session, conversation_id, sinks, opts) do
      send(opts.parent, {:bound, session, conversation_id, sinks})
      :ok
    end

    @impl true
    def deliver_to_session(session, text, opts) do
      send(opts.parent, {:delivered, session, text})
      :ok
    end

    @impl true
    def teardown_session(_session, _reason, _opts), do: :ok
  end

  setup do
    dir = Path.join(System.tmp_dir!(), "gst-consumer-smoke-#{System.unique_integer([:positive])}")
    Application.put_env(:genswarms_telegram, :state_dir, dir)

    on_exit(fn ->
      Application.delete_env(:genswarms_telegram, :state_dir)
      File.rm_rf(dir)
    end)

    {:ok, fake} = Fake.start_link()
    {:ok, fake: fake}
  end

  test "neutral consumer ingress and sender run end to end without network", %{fake: fake} do
    parent = self()

    {:ok, ingress} =
      Ingress.init(%{
        bot_token: "token",
        client: Fake,
        client_opts: [fake: fake],
        command_router: Basic,
        session_runtime: NeutralRuntime,
        session_opts: %{parent: parent},
        binding_sinks: [:telegram_sender],
        bot_username: "NeutralBot"
      })

    {:ok, sender} =
      Sender.init(%{
        bot_token: "token",
        client: Fake,
        client_opts: [fake: fake],
        binding_authority: :telegram_ingress,
        slot_prefix: "neutral_agent",
        rate_per_sec: 1_000
      })

    modules = [Fake, Basic, Ingress, Sender]

    assert Enum.all?(
             modules,
             &String.starts_with?(Atom.to_string(&1), "Elixir.Genswarms.Telegram.")
           )

    update = %{
      "update_id" => 10,
      "message" => %{
        "message_id" => 100,
        "chat" => %{"id" => 123},
        "from" => %{"id" => 456, "is_bot" => false, "first_name" => "Test"},
        "text" => "hello from a neutral consumer"
      }
    }

    {:reply, body, _ingress} =
      Ingress.handle_message(
        :consumer,
        %{"action" => "inject_update", "update" => update},
        ingress
      )

    assert Jason.decode!(body)["routed"] == true
    assert_receive {:session, "tg:123:0"}
    assert_receive {:bound, %{slot: :neutral_agent_0}, "tg:123:0", [:telegram_sender]}
    assert_receive {:delivered, %{conversation_id: "tg:123:0"}, text}
    assert text == "hello from a neutral consumer"
    assert Fake.calls(fake) == []

    {:noreply, sender} =
      Sender.handle_message(
        :telegram_ingress,
        %{
          "action" => "bind_session",
          "slot" => "neutral_agent_0",
          "conversation_id" => "tg:123:0"
        },
        sender
      )

    card = %{
      "title" => "Consumer Smoke",
      "blocks" => [%{"kind" => "paragraph", "text" => "The neutral consumer path works."}]
    }

    {:noreply, sender} =
      Sender.handle_message(
        :neutral_agent_0,
        %{"action" => "send_card", "conversation_id" => "tg:999:0", "card" => card},
        sender
      )

    [card_call] = Fake.calls(fake)
    assert card_call.method == :send_rich_message
    assert card_call.payload.chat_id == "123"
    assert card_call.payload.rich_message.html =~ "Consumer Smoke"

    {:reply, denied_body, _sender} =
      Sender.handle_message(
        :neutral_agent_0,
        %{"action" => "ban_chat_member", "chat_id" => -100_123, "user_id" => 456},
        sender
      )

    assert Jason.decode!(denied_body)["error"] == ":unauthorized_action"
    assert Fake.calls(fake) == [card_call]
  end
end

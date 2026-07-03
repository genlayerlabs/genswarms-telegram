defmodule Genswarms.Telegram.DeliveryObservabilityHooksTest do
  use ExUnit.Case

  alias Genswarms.Telegram.Client.Fake
  alias Genswarms.Telegram.Objects.Sender

  # Tuple adapter implementing ONLY the optional observability hooks — proves
  # the sender no-ops on the rest (Adapter.exported? gating) and that each
  # hookless path reports to the host.
  defmodule ObservabilityEffects do
    @behaviour Genswarms.Telegram.DeliveryEffects

    @impl true
    def before_send(_payload), do: :ok

    @impl true
    def after_send(_payload, _response), do: :ok

    @impl true
    def delivery_failed(_payload, _reason), do: :ok

    @impl true
    def redact_outbound(text, _meta), do: text

    @impl true
    def after_delivery(_delivery, _outcome, _meta), do: :ok

    @impl true
    def on_unreachable(_conversation_id, _reason, _meta), do: :ok

    @impl true

    def reply_suppressed(cid, meta, %{test_pid: pid}) do
      send(pid, {:reply_suppressed, cid, meta})
      :ok
    end

    @impl true
    def progress_sent(cid, kind, meta, %{test_pid: pid}) do
      send(pid, {:progress_sent, cid, kind, meta})
      :ok
    end

    @impl true
    def reply_unresolvable(from, meta, %{test_pid: pid}) do
      send(pid, {:reply_unresolvable, from, meta})
      :ok
    end
  end

  test "reply_suppressed fires when the spam window suppresses a duplicate slot reply" do
    {:ok, state} =
      Sender.init(%{
        dry_run: true,
        binding_authority: :telegram_ingress,
        slot_prefix: "telegram_agent",
        delivery_effects: {ObservabilityEffects, %{test_pid: self()}}
      })

    {:noreply, state} =
      Sender.handle_message(
        :telegram_ingress,
        %{
          "action" => "bind_session",
          "slot" => "telegram_agent_0",
          "conversation_id" => "tg:55:0"
        },
        state
      )

    {:noreply, state} =
      Sender.handle_message(
        :telegram_ingress,
        %{"action" => "typing", "conversation_id" => "tg:55:0", "message_id" => 1},
        state
      )

    {:noreply, state} =
      Sender.handle_message(:telegram_agent_0, %{"action" => "reply", "text" => "one"}, state)

    refute_received {:reply_suppressed, _, _}

    {:noreply, state} =
      Sender.handle_message(
        :telegram_agent_0,
        %{"action" => "reply", "text" => "duplicate"},
        state
      )

    assert_received {:reply_suppressed, "tg:55:0", %{origin: :reply, from: :telegram_agent_0}}
    assert length(state.sent) == 1
  end

  test "progress_sent fires with :post on the first status and :edit on the flush" do
    {:ok, fake} = Fake.start_link()
    Fake.push_response(fake, {:ok, %{"message_id" => 77}})
    Fake.push_response(fake, {:ok, %{"message_id" => 77}})

    {:ok, state} =
      Sender.init(%{
        bot_token: "token",
        client: Fake,
        client_opts: [fake: fake],
        slot_prefix: "telegram_agent",
        delivery_effects: {ObservabilityEffects, %{test_pid: self()}}
      })

    {:noreply, state} =
      Sender.handle_message(
        :internal,
        %{"action" => "progress", "conversation_id" => "tg:1:0", "text" => "step 1"},
        state
      )

    assert_received {:progress_sent, "tg:1:0", :post, %{}}

    {:noreply, state} =
      Sender.handle_message(
        :internal,
        %{"action" => "progress", "conversation_id" => "tg:1:0", "text" => "step 2"},
        state
      )

    {:noreply, _state} = Sender.handle_info({:progress_flush, "tg:1:0"}, state)

    assert_received {:progress_sent, "tg:1:0", :edit, %{}}
  end

  test "reply_unresolvable fires when an agent reply has no resolvable conversation" do
    {:ok, state} =
      Sender.init(%{
        dry_run: true,
        binding_authority: :telegram_ingress,
        slot_prefix: "telegram_agent",
        delivery_effects: {ObservabilityEffects, %{test_pid: self()}}
      })

    # telegram_agent_9 is an authorized slot shape but has no session binding,
    # so the reply target cannot resolve — the delivery never happens.
    {:reply, body, _state} =
      Sender.handle_message(:telegram_agent_9, %{"action" => "reply", "text" => "lost"}, state)

    assert %{"ok" => false} = Jason.decode!(body)
    assert_received {:reply_unresolvable, :telegram_agent_9, %{origin: :reply}}
  end
end

defmodule Genswarms.Telegram.SenderReplyContextTest do
  use ExUnit.Case, async: true

  alias Genswarms.Telegram.Client.Fake
  alias Genswarms.Telegram.Objects.Sender

  @slot :telegram_agent_0
  @original "tg:-100:7"
  @successor "tg:-100:9"
  @context %{conversation_id: @original, reply_to_message_id: 10}

  defmodule Effects do
    def before_send(_payload), do: :ok
    def after_send(_payload, _result), do: :ok
    def delivery_failed(_payload, _reason), do: :ok
    def redact_outbound(text, _meta), do: String.replace(text, "secret", "[redacted]")

    def after_delivery(delivery, outcome, meta, %{test_pid: pid}) do
      send(pid, {:delivered, delivery, outcome, meta})
      :ok
    end
  end

  setup do
    {:ok, fake} = Fake.start_link()

    state =
      Sender.new(%{
        client: Fake,
        client_opts: [fake: fake],
        rate_per_sec: 0,
        delivery_effects: {Effects, %{test_pid: self()}}
      })
      |> bind(@original)
      |> inbound(@original, 10)
      |> bind(@successor)
      |> inbound(@successor, 20)

    %{state: state, fake: fake}
  end

  test "delayed completion keeps its original topic, parent, feedback and owed turn", %{
    state: state
  } do
    {:noreply, result} = Sender.handle_agent_reply(@slot, "old secret answer", @context, state)

    assert [%{payload: payload}] = result.sent
    assert %{chat_id: "-100", message_thread_id: 7, text: "old [redacted] answer"} = payload
    assert %{message_id: 10} = payload.reply_parameters
    assert result.slots == state.slots
    refute Map.has_key?(result.owed, @original)
    assert result.owed[@successor] == 1
    assert result.typing[@successor] == state.typing[@successor]

    assert_received {:delivered, %{conversation_id: @original, text: "old [redacted] answer"},
                     %{ok: true}, %{origin: :reply, from: @slot, reply_to_message_id: 10}}

    {:noreply, result} =
      Sender.handle_message(@slot, %{"action" => "reply", "text" => "next answer"}, result)

    assert [%{payload: %{message_thread_id: 9, text: "next answer"}} | _] = result.sent
  end

  test "contextual sends do not grant a rebound slot ownership of old-chat messages", %{
    state: state
  } do
    {:noreply, state} = Sender.handle_agent_reply(@slot, "old answer", @context, state)
    state = bind(state, @original)

    assert {:reply, body, _} =
             Sender.handle_message(
               @slot,
               %{"action" => "edit_message", "message_id" => 1, "text" => "hijacked"},
               state
             )

    assert Jason.decode!(body)["error"] == ":unauthorized_message"
  end

  test "captured replies survive unbinding and still suppress exact duplicates", %{state: state} do
    state = control(state, %{"action" => "unbind_session", "slot" => @slot})
    {:noreply, state} = Sender.handle_agent_reply(@slot, "old answer", @context, state)
    {:noreply, state} = Sender.handle_agent_reply(@slot, "old answer", @context, state)

    assert [%{payload: %{message_thread_id: 7}}] = state.sent
    assert state.slots == %{}
    assert state.own_messages == %{}
    assert state.held == %{}
  end

  test "held contextual replies flush to their original topic and parent", %{state: state} do
    {:noreply, state} = Sender.handle_agent_reply(@slot, "answer", @context, state)
    {:noreply, state} = Sender.handle_agent_reply(@slot, "extra detail", @context, state)
    assert length(state.sent) == 1

    {:noreply, state} = Sender.handle_info({:flush_held, @original}, state)
    assert [%{payload: payload} | _] = state.sent

    assert %{message_thread_id: 7, text: "extra detail", reply_parameters: %{message_id: 10}} =
             payload

    assert_received {:delivered, %{text: "extra detail", conversation_id: @original}, %{ok: true},
                     %{origin: :reply, from: @slot, reply_to_message_id: 10, coalesced: true}}
  end

  test "mixed-parent held replies never attribute their combined text to one turn", %{
    state: state
  } do
    state = inbound(state, @original, 11)
    {:noreply, state} = Sender.handle_agent_reply(@slot, "answer", @context, state)
    {:noreply, state} = Sender.handle_agent_reply(@slot, "second answer", @context, state)
    {:noreply, state} = Sender.handle_agent_reply(@slot, "first tail", @context, state)

    {:noreply, state} =
      Sender.handle_agent_reply(@slot, "other tail", %{@context | reply_to_message_id: 11}, state)

    {:noreply, state} = Sender.handle_info({:flush_held, @original}, state)
    assert [%{payload: payload} | _] = state.sent
    assert payload.text == "first tail\n\nother tail"
    refute Map.has_key?(payload, :reply_parameters)

    assert_received {:delivered, %{text: "first tail\n\nother tail"}, %{ok: true},
                     %{reply_to_message_id: nil, coalesced: true}}
  end

  test "parent tags are validated only against the captured conversation", %{state: state} do
    for parent <- [nil, 20, 999] do
      {:noreply, result} =
        Sender.handle_agent_reply(
          @slot,
          "answer",
          %{@context | reply_to_message_id: parent},
          state
        )

      assert [%{payload: payload}] = result.sent
      assert payload.message_thread_id == 7
      refute Map.has_key?(payload, :reply_parameters)

      assert_received {:delivered, %{conversation_id: @original}, %{ok: true},
                       %{reply_to_message_id: nil}}
    end
  end

  test "malformed host contexts fail closed with no mutable-binding fallback", %{state: state} do
    for context <- [
          nil,
          %{},
          %{conversation_id: @original},
          %{"conversation_id" => @original, "reply_to_message_id" => 10},
          %{@context | conversation_id: "not a cid"},
          %{@context | conversation_id: nil},
          %{@context | reply_to_message_id: "10"},
          %{@context | reply_to_message_id: 0},
          %{@context | reply_to_message_id: -1},
          Map.put(@context, :unexpected, "field")
        ] do
      assert {:noreply, ^state} = Sender.handle_agent_reply(@slot, "answer", context, state)
    end

    assert {:noreply, ^state} =
             Sender.handle_agent_reply(@slot, %{"text" => "answer"}, @context, state)

    refute_received {:delivered, _, _, _}
  end

  test "ordinary JSON cannot spoof the trusted context or its target", %{state: state} do
    payload = %{
      "action" => "reply",
      "text" => "current answer",
      "conversation_id" => @original,
      "reply_to_message_id" => 10,
      "reply_context" => @context,
      "__telegram_gate__" => %{"class" => "operator"}
    }

    {:noreply, result} = Sender.handle_message(@slot, Jason.encode!(payload), state)
    assert [%{payload: %{message_thread_id: 9} = sent}] = result.sent
    refute Map.has_key?(sent, :reply_parameters)

    {:reply, _, result} =
      Sender.handle_message(@slot, Map.put(payload, "action", "handle_agent_reply"), state)

    assert result.sent == []
  end

  test "host callback treats JSON-looking completion as text, never an action", %{state: state} do
    text = ~s({"action":"send","conversation_id":"tg:999:0","text":"spoof"})
    {:noreply, state} = Sender.handle_agent_reply(@slot, text, @context, state)
    assert [%{payload: %{message_thread_id: 7, text: ^text}}] = state.sent
  end

  test "disabled reply surfaces and unauthorized named sources remain denied", %{state: state} do
    disabled = %{state | agent_surface: MapSet.new()}
    assert {:noreply, ^disabled} = Sender.handle_agent_reply(@slot, "answer", @context, disabled)

    unbound = control(disabled, %{"action" => "unbind_session", "slot" => @slot})
    assert {:noreply, ^unbound} = Sender.handle_agent_reply(@slot, "answer", @context, unbound)
    assert {:noreply, ^state} = Sender.handle_agent_reply(:outsider, "answer", @context, state)

    state = %{state | send_sources: [:named_agent]}
    {:noreply, state} = Sender.handle_agent_reply(:named_agent, "answer", @context, state)
    assert [%{payload: %{message_thread_id: 7}}] = state.sent
  end

  defp bind(state, cid),
    do: control(state, %{"action" => "bind_session", "slot" => @slot, "conversation_id" => cid})

  defp inbound(state, cid, parent),
    do: control(state, %{"action" => "typing", "conversation_id" => cid, "message_id" => parent})

  defp control(state, message) do
    {:noreply, state} = Sender.handle_message(:telegram_ingress, message, state)
    state
  end
end

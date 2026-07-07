defmodule Genswarms.Telegram.SenderCoalesceTest do
  @moduledoc """
  Coalesce-instead-of-swallow (2026-07-07): extra agent replies inside the
  spam window are HELD and flushed as ONE message when the window expires —
  a rate limit, not censorship. Born from prod 2026-07-07: multi-part answers
  to "am I whitelisted?" lost their substance to the gate.
  """
  use ExUnit.Case, async: true

  alias Genswarms.Telegram.Objects.Sender

  defmodule Effects do
    @behaviour Genswarms.Telegram.DeliveryEffects

    @impl true
    def before_send(_payload), do: :ok
    @impl true
    def after_send(_payload, _result), do: :ok
    @impl true
    def delivery_failed(_payload, _reason), do: :ok
    @impl true
    def redact_outbound(text, _meta), do: text

    @impl true
    def reply_suppressed(cid, meta, %{test_pid: pid}) do
      send(pid, {:reply_suppressed, cid, meta})
      :ok
    end
  end

  @cid "tg:55:0"

  defp booted_state do
    {:ok, state} =
      Sender.init(%{
        dry_run: true,
        binding_authority: :telegram_ingress,
        slot_prefix: "telegram_agent",
        delivery_effects: {Effects, %{test_pid: self()}}
      })

    {:noreply, state} =
      Sender.handle_message(
        :telegram_ingress,
        %{"action" => "bind_session", "slot" => "telegram_agent_0", "conversation_id" => @cid},
        state
      )

    state
  end

  defp inbound(state, id) do
    {:noreply, state} =
      Sender.handle_message(
        :telegram_ingress,
        %{"action" => "typing", "conversation_id" => @cid, "message_id" => id},
        state
      )

    state
  end

  defp agent_reply(state, text) do
    {:noreply, state} =
      Sender.handle_message(:telegram_agent_0, %{"action" => "reply", "text" => text}, state)

    state
  end

  defp sent_texts(state) do
    state.sent |> Enum.reverse() |> Enum.map(fn %{payload: p} -> p[:text] end)
  end

  test "an extra reply is HELD (not delivered, not lost) and flushes as one message" do
    state = booted_state() |> inbound(1)
    state = agent_reply(state, "part one")
    assert length(state.sent) == 1

    state = agent_reply(state, "part two — the substance")
    state = agent_reply(state, "part three")

    # nothing extra delivered yet; the texts wait in the buffer
    assert length(state.sent) == 1
    assert state.held[@cid].texts == ["part two — the substance", "part three"]
    assert_received {:reply_suppressed, @cid, %{origin: :reply}}

    # the window-expiry timer fires → ONE message with everything, in order
    {:noreply, state} = Sender.handle_info({:flush_held, @cid}, state)
    assert state.held == %{}
    assert length(state.sent) == 3 or length(state.sent) == 2

    joined = sent_texts(state) |> List.last()
    assert joined =~ "part two — the substance"
    assert joined =~ "part three"

    # the flush re-armed the window (rate limit): its text is the new signature
    assert state.last_reply_sig[@cid] != nil
  end

  test "a NEW inbound flushes the held tail immediately, before the next answer" do
    state = booted_state() |> inbound(1) |> agent_reply("answer 1") |> agent_reply("tail")
    assert state.held[@cid].texts == ["tail"]

    state = inbound(state, 2)

    # the tail landed at inbound time — order preserved for the user
    assert state.held == %{}
    assert sent_texts(state) |> List.last() =~ "tail"

    # and the answer to the new message passes normally (owed > 0)
    state = agent_reply(state, "answer 2")
    assert sent_texts(state) |> List.last() == "answer 2"
  end

  test "an exact replay of the delivered reply still dies (the original spam case)" do
    state = booted_state() |> inbound(1) |> agent_reply("same text")
    state = agent_reply(state, "same text")

    assert state.held == %{}
    assert length(state.sent) == 1
    assert_received {:reply_suppressed, @cid, _meta}
  end

  test "a duplicate of an already-held text is not held twice" do
    state = booted_state() |> inbound(1) |> agent_reply("answer")
    state = state |> agent_reply("extra") |> agent_reply("extra")

    assert state.held[@cid].texts == ["extra"]
  end

  test "caps degrade to plain suppression: max texts per conversation" do
    state = booted_state() |> inbound(1) |> agent_reply("answer")

    state =
      Enum.reduce(1..5, state, fn i, acc -> agent_reply(acc, "extra #{i}") end)

    assert length(state.held[@cid].texts) == 3
  end

  test "an empty flush timer is a no-op (timer races are harmless)" do
    state = booted_state()
    {:noreply, state2} = Sender.handle_info({:flush_held, @cid}, state)
    assert state2.held == state.held
    assert state2.sent == state.sent
  end
end

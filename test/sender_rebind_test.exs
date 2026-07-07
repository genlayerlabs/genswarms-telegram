defmodule Genswarms.Telegram.SenderRebindTest do
  @moduledoc """
  Claim re-seed at init (2026-07-07): the sender's slot→conversation claims
  are process-local, so a sender restart (prod crash-loop, 7× in one pod)
  dropped in-flight agent replies as "no target" until the conversation's
  next inbound re-bound it. If the host exports `current_bindings/0` on the
  delivery-effects seam, init re-seeds the claims; the seam is TOTAL — a
  broken host implementation degrades to the old cold start.
  """
  use ExUnit.Case, async: true

  alias Genswarms.Telegram.Objects.Sender

  @cid "tg:55:0"

  defmodule BindingEffects do
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
    def current_bindings(%{bindings: bindings}), do: bindings
  end

  defmodule RaisingEffects do
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
    def current_bindings(_opts), do: raise("host bug")
  end

  defp boot(effects) do
    {:ok, state} =
      Sender.init(%{
        dry_run: true,
        binding_authority: :telegram_ingress,
        slot_prefix: "telegram_agent",
        delivery_effects: effects
      })

    state
  end

  test "init re-seeds claims from the host and a reply delivers without any bind_session" do
    state =
      boot(
        {BindingEffects,
         %{bindings: [%{slot: "telegram_agent_0", conversation_id: @cid}]}}
      )

    assert state.slots == %{"telegram_agent_0" => @cid}

    {:noreply, state} =
      Sender.handle_message(
        :telegram_agent_0,
        %{"action" => "reply", "text" => "still here after the restart"},
        state
      )

    assert [%{payload: %{text: "still here after the restart", chat_id: "55"}}] = state.sent
  end

  test "malformed entries are skipped, valid ones kept" do
    state =
      boot(
        {BindingEffects,
         %{
           bindings: [
             %{slot: "telegram_agent_1", conversation_id: "tg:9:0"},
             %{"slot" => "telegram_agent_2", "conversation_id" => "tg:10:0"},
             %{slot: "telegram_agent_3", conversation_id: "not a cid"},
             %{slot: nil, conversation_id: "tg:11:0"},
             "not even a map"
           ]
         }}
      )

    assert state.slots == %{
             "telegram_agent_1" => "tg:9:0",
             "telegram_agent_2" => "tg:10:0"
           }
  end

  test "a raising host implementation degrades to a cold start" do
    state = boot({RaisingEffects, %{}})
    assert state.slots == %{}
  end

  test "a host returning a non-list degrades to a cold start" do
    state = boot({BindingEffects, %{bindings: :whoops}})
    assert state.slots == %{}
  end

  test "a host without the callback is unchanged (no seed, no crash)" do
    state = boot(Genswarms.Telegram.DeliveryEffects.Noop)
    assert state.slots == %{}
  end
end

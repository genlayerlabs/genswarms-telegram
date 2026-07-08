defmodule Genswarms.Telegram.Objects.IngressBackpressureTest do
  @moduledoc """
  The ingress poll loop under load: it must survive a slow/timed-out agent spawn
  (add_agent), and it must not stampede the SwarmManager during a burst.
  """
  use ExUnit.Case

  alias Genswarms.Telegram.Client.Fake
  alias Genswarms.Telegram.Objects.Ingress
  alias Genswarms.Telegram.Store.File, as: FileStore

  setup do
    dir = Path.join(System.tmp_dir!(), "gst-ingress-bp-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    Application.put_env(:genswarms_telegram, :state_dir, dir)

    on_exit(fn ->
      Application.delete_env(:genswarms_telegram, :state_dir)
      File.rm_rf(dir)
    end)

    {:ok, fake} = Fake.start_link()
    {:ok, fake: fake}
  end

  # ensure_session exits exactly like a timed-out SwarmManager.add_agent
  defmodule ExitingRuntime do
    @behaviour Genswarms.Telegram.SessionRuntime
    @impl true
    def ensure_session(_cid, _opts),
      do: exit({:timeout, {GenServer, :call, [Genswarms.SwarmManager, {:add_agent, :x}]}})

    @impl true
    def bind_session(_s, _c, _sinks, _o), do: :ok
    @impl true
    def deliver_to_session(_s, _t, _o), do: :ok
    @impl true
    def teardown_session(_s, _r, _o), do: :ok
  end

  # every conversation is a brand-new (fresh?) spawn — the expensive case
  defmodule FreshRuntime do
    @behaviour Genswarms.Telegram.SessionRuntime
    @impl true
    def ensure_session(cid, _opts),
      do:
        {:ok,
         %{slot: String.to_atom("slot_" <> cid), conversation_id: cid, workspace: "/tmp/bp", fresh?: true}}

    @impl true
    def bind_session(_s, _c, _sinks, _o), do: :ok
    @impl true
    def deliver_to_session(_s, _t, _o), do: :ok
    @impl true
    def teardown_session(_s, _r, _o), do: :ok
  end

  defp ingress(fake, runtime, extra) do
    Ingress.new(
      Map.merge(
        %{
          client: Fake,
          client_opts: [fake: fake],
          store: FileStore,
          bot_ref: "bot-bp-#{System.unique_integer([:positive])}",
          fail_open_without_username?: true,
          session_runtime: runtime
        },
        extra
      )
    )
  end

  defp text_update(chat_id, update_id) do
    %{
      "update_id" => update_id,
      "message" => %{
        "message_id" => update_id,
        "chat" => %{"id" => chat_id, "type" => "private"},
        "from" => %{"id" => chat_id, "username" => "u#{chat_id}"},
        "text" => "hi"
      }
    }
  end

  defp state_of({:noreply, s}), do: s
  defp state_of({:send_many, _msgs, s}), do: s

  test "poll loop survives an add_agent :exit in ensure_session and re-arms", %{fake: fake} do
    state = ingress(fake, ExitingRuntime, %{poll_enabled: true})

    # Processing this update exits inside ensure_session (a timed-out add_agent).
    # Before the fix this unwound past schedule_poll and the ingress stopped
    # polling Telegram forever. handle_info must contain it and re-arm.
    result = Ingress.handle_info({:telegram_poll_result, {:ok, [text_update(500, 500)], 501}}, state)
    new_state = state_of(result)

    assert new_state.poll_failures >= 1
    # the poll was re-armed (schedule_poll → Process.send_after(self(), :poll, _))
    assert_receive :poll, 5_000
    # a crashed batch must not advance the committed offset
    assert FileStore.read_offset(new_state.bot_ref) == 0
  end

  test "caps new sessions per poll; the rest stay queued in Telegram (offset stops)", %{fake: fake} do
    state = ingress(fake, FreshRuntime, %{max_new_sessions_per_poll: 2, memory_policy: :none})

    # five distinct brand-new conversations arriving in one batch
    updates = for i <- 1..5, do: text_update(600 + i, 600 + i)
    result = Ingress.handle_info({:telegram_poll_result, {:ok, updates, 606}}, state)
    new_state = state_of(result)

    # only the first 2 (update_id 601, 602) opened new sessions → offset committed
    # at 603. Updates 603..605 were left unconsumed; Telegram re-delivers them on
    # the next poll — a natural backpressure queue that drains as load falls.
    assert FileStore.read_offset(new_state.bot_ref) == 603
  end

  test "existing (warm) sessions are not throttled by the cap", %{fake: fake} do
    # a runtime whose sessions are NOT fresh — reused pool slots, cheap
    defmodule WarmRuntime do
      @behaviour Genswarms.Telegram.SessionRuntime
      @impl true
      def ensure_session(cid, _opts),
        do: {:ok, %{slot: String.to_atom("w_" <> cid), conversation_id: cid, workspace: "/tmp/bp", fresh?: false}}

      @impl true
      def bind_session(_s, _c, _sinks, _o), do: :ok
      @impl true
      def deliver_to_session(_s, _t, _o), do: :ok
      @impl true
      def teardown_session(_s, _r, _o), do: :ok
    end

    state = ingress(fake, WarmRuntime, %{max_new_sessions_per_poll: 2, memory_policy: :none})
    updates = for i <- 1..5, do: text_update(700 + i, 700 + i)
    result = Ingress.handle_info({:telegram_poll_result, {:ok, updates, 706}}, state)

    # all five consumed — warm slots don't count against the spawn cap → offset 706
    assert FileStore.read_offset(state_of(result).bot_ref) == 706
  end
end

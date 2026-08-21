defmodule Genswarms.Telegram.Objects.IngressPollStallTest do
  @moduledoc """
  The poll loop must survive a latched `poll_ref`.

  Production incident (genmochi 2026-08-21): a handler crash during send-many
  fan-out makes the ObjectServer keep the PRE-call handler state — one where
  `poll_ref` is still a reference even though the poll task already finished.
  Every subsequent `:poll` tick then hit the `is_reference` guard and was
  dropped without re-arming: a permanently dead poller inside a live object,
  with zero log lines. The guard must reap a stale ref (dead task) and repoll,
  while still deduplicating ticks for a genuinely in-flight poll.
  """
  use ExUnit.Case

  import ExUnit.CaptureLog

  alias Genswarms.Telegram.Client.Fake
  alias Genswarms.Telegram.Objects.Ingress
  alias Genswarms.Telegram.Store.File, as: FileStore

  setup do
    dir = Path.join(System.tmp_dir!(), "gst-poll-stall-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    Application.put_env(:genswarms_telegram, :state_dir, dir)

    on_exit(fn ->
      Application.delete_env(:genswarms_telegram, :state_dir)
      File.rm_rf(dir)
    end)

    {:ok, fake} = Fake.start_link()
    {:ok, fake: fake}
  end

  defp ingress(fake, extra) do
    Ingress.new(
      Map.merge(
        %{
          client: Fake,
          client_opts: [fake: fake],
          store: FileStore,
          bot_ref: "bot-stall-#{System.unique_integer([:positive])}",
          fail_open_without_username?: true,
          poll_enabled: true
        },
        extra
      )
    )
  end

  defp state_of({:noreply, s}), do: s
  defp state_of({:send_many, _msgs, s}), do: s

  test "a :poll tick reaps a STALE latched poll_ref and repolls", %{fake: fake} do
    state = ingress(fake, %{})

    # the reverted-state scenario: the ref's task is long gone
    dead = spawn(fn -> :ok end)
    ref = Process.monitor(dead)
    Process.demonitor(ref, [:flush])
    refute Process.alive?(dead)

    stale = %{state | poll_ref: ref} |> Map.put(:poll_pid, dead)

    log =
      capture_log(fn ->
        new_state = state_of(Ingress.handle_info(:poll, stale))

        # a fresh poll task must be running — the stale latch may not stand
        assert new_state.poll_ref != ref
        assert is_reference(new_state.poll_ref)

        # and its result arrives like any normal poll cycle
        assert_receive {:telegram_poll_result, _result}, 5_000
      end)

    assert log =~ "stale"
  end

  test "a :poll tick during a genuinely in-flight poll is still deduplicated", %{fake: fake} do
    state = ingress(fake, %{})

    alive = spawn(fn -> Process.sleep(:infinity) end)
    ref = Process.monitor(alive)
    in_flight = %{state | poll_ref: ref} |> Map.put(:poll_pid, alive)

    assert {:noreply, new_state} = Ingress.handle_info(:poll, in_flight)
    assert new_state.poll_ref == ref
    refute_receive {:telegram_poll_result, _result}, 200

    Process.exit(alive, :kill)
  end
end

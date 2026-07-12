defmodule Genswarms.Telegram.Objects.IngressWakeGateTest do
  @moduledoc """
  The 0.5.0 privileged surface: `agent_wake` (operator speaks THROUGH the
  agent) and the retrofitted `inject_sources` gate on `inject_update`.

  Both actions are from-gated against engine-stamped senders, default [] =
  disabled. The wake envelope is FIXED in the package — callers choose the
  prompt, never the framing — and the turn lands with transcript role
  :operator, never :user (the whole point: a wake must not be able to
  impersonate the user).
  """
  use ExUnit.Case, async: false

  alias Genswarms.Telegram.Client.Fake
  alias Genswarms.Telegram.Objects.Ingress
  alias Genswarms.Telegram.Store.File, as: FileStore

  @sink :wake_gate_test_sink

  setup do
    dir = Path.join(System.tmp_dir!(), "gst-ingress-wake-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    Application.put_env(:genswarms_telegram, :state_dir, dir)

    on_exit(fn ->
      Application.delete_env(:genswarms_telegram, :state_dir)
      File.rm_rf(dir)
    end)

    {:ok, fake} = Fake.start_link()
    Process.register(self(), @sink)
    on_exit(fn -> if Process.whereis(@sink) == self(), do: Process.unregister(@sink) end)
    {:ok, fake: fake}
  end

  # Warm session; reports every delivered turn text to the test process.
  defmodule CapturingRuntime do
    @behaviour Genswarms.Telegram.SessionRuntime
    @impl true
    def ensure_session(cid, _opts),
      do: {:ok, %{slot: :wake_slot, conversation_id: cid, workspace: "/tmp/wake", fresh?: false}}

    @impl true
    def bind_session(_s, _c, _sinks, _o), do: :ok
    @impl true
    def deliver_to_session(_s, text, _o) do
      send(:wake_gate_test_sink, {:delivered, text})
      :ok
    end

    @impl true
    def teardown_session(_s, _r, _o), do: :ok
  end

  # Refusal-first admission: the runtime says no (full pool, nonresident cid).
  defmodule RefusingRuntime do
    @behaviour Genswarms.Telegram.SessionRuntime
    @impl true
    def ensure_session(_cid, _opts), do: {:skip, :pool_full}
    @impl true
    def bind_session(_s, _c, _sinks, _o), do: :ok
    @impl true
    def deliver_to_session(_s, _t, _o), do: :ok
    @impl true
    def teardown_session(_s, _r, _o), do: :ok
  end

  # A transcript-owning runtime (wingston-shaped): prefers deliver_turn/3 and
  # sees the WHOLE turn map — the role must arrive there.
  defmodule TurnRuntime do
    @behaviour Genswarms.Telegram.SessionRuntime
    @impl true
    def ensure_session(cid, _opts),
      do: {:ok, %{slot: :turn_slot, conversation_id: cid, workspace: "/tmp/wake", fresh?: false}}

    @impl true
    def bind_session(_s, _c, _sinks, _o), do: :ok

    @impl true
    def deliver_turn(_session, turn, _opts) do
      send(:wake_gate_test_sink, {:turn, turn})
      :ok
    end

    @impl true
    def deliver_to_session(_s, _t, _o), do: :ok
    @impl true
    def teardown_session(_s, _r, _o), do: :ok
  end

  # Reports every on_skipped — the hosts' redelivery seam a refused wake must
  # never reach (wingston queues skipped USER turns and re-injects them later).
  defmodule SkipSpyEffects do
    def on_skipped(event, reason, _meta, effects_state) do
      send(:wake_gate_test_sink, {:on_skipped, Map.get(event, :conversation_id), reason})
      {:ok, effects_state}
    end
  end

  # Captures the transcript role after_turn records.
  defmodule CapturingContext do
    def init_session(_bot_ref, _cid, _meta), do: :ok
    def before_turn(_bot_ref, _cid, _text, _opts), do: ""

    def after_turn(_bot_ref, cid, role, text, _opts) do
      send(:wake_gate_test_sink, {:after_turn, cid, role, text})
      :ok
    end
  end

  defp ingress(fake, extra) do
    Ingress.new(
      Map.merge(
        %{
          client: Fake,
          client_opts: [fake: fake],
          store: FileStore,
          bot_ref: "bot-wake-#{System.unique_integer([:positive])}",
          fail_open_without_username?: true,
          session_runtime: CapturingRuntime,
          memory_policy: :none
        },
        extra
      )
    )
  end

  defp wake_msg(cid \\ "tg:42:0", prompt \\ "nudge them about the deadline") do
    Jason.encode!(%{action: "agent_wake", conversation_id: cid, prompt: prompt, kind: "reengage"})
  end

  defp reply_of({:reply, json, _state}), do: Jason.decode!(json)

  # ── agent_wake gate ──────────────────────────────────────────────────────────

  test "agent_wake is DISABLED by default — any sender is refused", %{fake: fake} do
    state = ingress(fake, %{})

    reply = reply_of(Ingress.handle_message(:commands, wake_msg(), state))
    assert reply["ok"] == false
    assert reply["error"] =~ "unauthorized_wake"
    refute_receive {:delivered, _}, 50
  end

  test "agent_wake from a non-listed sender is refused even when the gate is open", %{fake: fake} do
    state = ingress(fake, %{wake_sources: [:commands]})

    reply = reply_of(Ingress.handle_message(:proactive, wake_msg(), state))
    assert reply["error"] =~ "unauthorized_wake"
    refute_receive {:delivered, _}, 50
  end

  test "a listed sender wakes the session: enveloped prompt, ack woken (never routed)", %{
    fake: fake
  } do
    state = ingress(fake, %{wake_sources: [:commands]})

    reply = reply_of(Ingress.handle_message(:commands, wake_msg(), state))

    assert reply["ok"] == true
    assert reply["woken"] == true
    refute Map.has_key?(reply, "routed")
    assert reply["conversation_id"] == "tg:42:0"

    assert_receive {:delivered, text}
    # the FIXED package envelope precedes the caller's prompt
    assert text =~ "the user did NOT send a message"
    assert text =~ "output nothing at all"
    assert text =~ "nudge them about the deadline"
  end

  test "sources compare as strings (atom config, string from)", %{fake: fake} do
    state = ingress(fake, %{wake_sources: ["commands"]})

    reply = reply_of(Ingress.handle_message(:commands, wake_msg(), state))
    assert reply["woken"] == true
  end

  test "the wake turn is recorded with role :operator, never :user", %{fake: fake} do
    state =
      ingress(fake, %{
        wake_sources: [:commands],
        memory_policy: :all,
        context_store: CapturingContext
      })

    assert %{"woken" => true} = reply_of(Ingress.handle_message(:commands, wake_msg(), state))
    assert_receive {:after_turn, "tg:42:0", :operator, _text}
  end

  test "refusal-first admission surfaces as skipped, not error", %{fake: fake} do
    state = ingress(fake, %{wake_sources: [:commands], session_runtime: RefusingRuntime})

    reply = reply_of(Ingress.handle_message(:commands, wake_msg(), state))
    assert reply["ok"] == true
    assert reply["skipped"] == "pool_full"
    refute Map.has_key?(reply, "woken")
  end

  test "a REFUSED wake never reaches on_skipped (the hosts' requeue seam — a queued wake would replay as a forged user update)",
       %{fake: fake} do
    state =
      ingress(fake, %{
        wake_sources: [:commands],
        session_runtime: RefusingRuntime,
        inbound_effects: SkipSpyEffects
      })

    reply = reply_of(Ingress.handle_message(:commands, wake_msg(), state))
    assert reply["skipped"] == "pool_full"
    refute_receive {:on_skipped, _, _}, 50

    # ...while the SAME refusal on a USER turn still reaches the hook (the
    # redelivery seam lives — only wakes stay out of it).
    state2 =
      ingress(fake, %{
        inject_sources: [:tester],
        session_runtime: RefusingRuntime,
        inbound_effects: SkipSpyEffects
      })

    _ = Ingress.handle_message(:tester, inject_msg(text_update(9, 9)), state2)
    assert_receive {:on_skipped, "tg:9:0", :pool_full}
  end

  test "the delivered TURN carries role :operator for wakes and :user for user turns (transcript-owning runtimes read it)",
       %{fake: fake} do
    state = ingress(fake, %{wake_sources: [:commands], session_runtime: TurnRuntime})

    assert %{"woken" => true} = reply_of(Ingress.handle_message(:commands, wake_msg(), state))
    assert_receive {:turn, %{role: :operator, conversation_id: "tg:42:0", text: text}}
    assert text =~ "the user did NOT send a message"

    # a normal user turn through the same runtime carries :user
    state2 = ingress(fake, %{inject_sources: [:tester], session_runtime: TurnRuntime})
    update = text_update(9, 9)
    _ = Ingress.handle_message(:tester, inject_msg(update), state2)
    assert_receive {:turn, %{role: :user, text: "replayed turn"}}
  end

  test "a malformed kind (map/number) falls back to the default label instead of crashing", %{
    fake: fake
  } do
    state = ingress(fake, %{wake_sources: [:commands], session_runtime: TurnRuntime})

    msg =
      Jason.encode!(%{
        action: "agent_wake",
        conversation_id: "tg:42:0",
        prompt: "hi",
        kind: %{"weird" => true}
      })

    assert %{"woken" => true} = reply_of(Ingress.handle_message(:commands, msg, state))
    assert_receive {:turn, %{event: %{wake_kind: "operator"}}}
  end

  test "missing/malformed cid or blank prompt are refused before touching the session", %{
    fake: fake
  } do
    state = ingress(fake, %{wake_sources: [:commands]})

    no_cid = Jason.encode!(%{action: "agent_wake", prompt: "hi"})
    # review: a non-empty but malformed cid must be rejected too — it would
    # bind a session to a garbage string and misderive the Telegram target.
    bad_cid = Jason.encode!(%{action: "agent_wake", conversation_id: "tg:-100:bad", prompt: "hi"})
    blank = Jason.encode!(%{action: "agent_wake", conversation_id: "tg:1:0", prompt: "   "})

    assert reply_of(Ingress.handle_message(:commands, no_cid, state))["error"] =~
             "wake_invalid_conversation_id"

    assert reply_of(Ingress.handle_message(:commands, bad_cid, state))["error"] =~
             "wake_invalid_conversation_id"

    assert reply_of(Ingress.handle_message(:commands, blank, state))["error"] =~
             "wake_missing_prompt"

    refute_receive {:delivered, _}, 50
  end

  test "interface advertises agent_wake" do
    assert "agent_wake" in Ingress.interface().actions
  end

  # ── inject_update gate (0.5.0 BREAKING: was ungated) ────────────────────────

  defp text_update(chat_id, update_id) do
    %{
      "update_id" => update_id,
      "message" => %{
        "message_id" => update_id,
        "chat" => %{"id" => chat_id, "type" => "private"},
        "from" => %{"id" => chat_id, "username" => "u#{chat_id}"},
        "text" => "replayed turn"
      }
    }
  end

  defp inject_msg(update), do: Jason.encode!(%{action: "inject_update", update: update})

  test "inject_update is DISABLED by default — the pre-0.5.0 open edge is closed", %{fake: fake} do
    state = ingress(fake, %{})

    reply = reply_of(Ingress.handle_message(:proactive, inject_msg(text_update(9, 9)), state))
    assert reply["ok"] == false
    assert reply["error"] =~ "unauthorized_inject"
    refute_receive {:delivered, _}, 50
  end

  test "a listed injector still replays turns through the full pipeline", %{fake: fake} do
    state = ingress(fake, %{inject_sources: [:proactive]})

    reply = reply_of(Ingress.handle_message(:proactive, inject_msg(text_update(9, 9)), state))
    assert reply["ok"] == true
    assert reply["routed"] == true
    assert_receive {:delivered, text}
    assert text =~ "replayed turn"
  end

  test "a non-listed sender cannot inject even when the gate lists others", %{fake: fake} do
    state = ingress(fake, %{inject_sources: [:proactive]})

    reply = reply_of(Ingress.handle_message(:evil_object, inject_msg(text_update(9, 9)), state))
    assert reply["error"] =~ "unauthorized_inject"
  end
end

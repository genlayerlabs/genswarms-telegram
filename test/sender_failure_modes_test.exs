defmodule Genswarms.Telegram.SenderFailureModesTest do
  use ExUnit.Case

  alias Genswarms.Telegram.Client.Fake
  alias Genswarms.Telegram.Objects.Sender

  defmodule BlockingEffects do
    @behaviour Genswarms.Telegram.DeliveryEffects

    @impl true
    def before_send(_payload), do: {:error, :blocked}

    @impl true
    def before_send(payload, %{test_pid: pid}) do
      send(pid, {:before_send, payload})
      {:error, :blocked}
    end

    @impl true
    def after_send(_payload, _response), do: :ok

    @impl true
    def delivery_failed(_payload, _reason), do: :ok

    @impl true
    def delivery_failed(payload, reason, %{test_pid: pid}) do
      send(pid, {:delivery_failed, payload, reason})
      :ok
    end

    @impl true
    def redact_outbound(text, _meta), do: text

    @impl true
    def after_delivery(_delivery, _outcome, _meta), do: :ok

    @impl true
    def on_unreachable(_conversation_id, _reason, _meta), do: :ok
  end

  defmodule AuditEffects do
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
    def after_delivery(delivery, outcome, meta, %{test_pid: pid}) do
      send(pid, {:after_delivery, delivery, outcome, meta})
      :ok
    end

    @impl true
    def after_delivery(_delivery, _outcome, _meta), do: :ok

    @impl true
    def on_unreachable(cid, reason, meta, %{test_pid: pid}) do
      send(pid, {:unreachable, cid, reason, meta})
      :ok
    end

    @impl true
    def on_unreachable(_conversation_id, _reason, _meta), do: :ok
  end

  test "before_send can block delivery before Telegram is called and still records failure effects" do
    {:ok, fake} = Fake.start_link()

    state =
      Sender.new(%{
        client: Fake,
        client_opts: [fake: fake],
        delivery_effects: {BlockingEffects, %{test_pid: self()}},
        rate_per_sec: 1_000
      })

    {:noreply, state} =
      Sender.handle_message(
        :telegram_ingress,
        %{"action" => "send", "conversation_id" => "tg:123:0", "text" => "blocked"},
        state
      )

    assert_receive {:before_send, %{chat_id: "123", text: "blocked"}}
    assert_receive {:delivery_failed, %{chat_id: "123"}, {:before_send, :blocked}}
    assert Fake.calls(fake) == []
    assert [%{result: {:error, {:before_send, :blocked}}}] = state.sent
  end

  test "raw rich messages fall back to plain text on parse errors when the agent provides fallback text" do
    {:ok, fake} =
      Fake.start_link([
        {:error, {:parse_error, "can't parse entities"}},
        {:ok, %{"message_id" => 42}}
      ])

    state =
      Sender.new(%{
        client: Fake,
        client_opts: [fake: fake],
        rate_per_sec: 1_000,
        action_grants: %{infra: [:telegram_ingress]}
      })

    {:noreply, state} =
      Sender.handle_message(
        :telegram_ingress,
        %{
          "action" => "send_rich_raw",
          "conversation_id" => "tg:123:0",
          "rich_message" => %{"html" => "<bad>"},
          "fallback_text" => "Plain fallback"
        },
        state
      )

    [rich_call, fallback_call] = Fake.calls(fake)
    assert rich_call.method == :send_rich_message
    assert rich_call.payload.rich_message == %{html: "<bad>"}

    assert fallback_call.method == :send_message
    assert fallback_call.payload.text == "Plain fallback"
    refute Map.has_key?(fallback_call.payload, :rich_message)
    assert [%{result: {:ok, %{"message_id" => 42}}}] = state.sent
  end

  test "raw rich messages return a structured error when parse fallback text is absent" do
    {:ok, fake} = Fake.start_link([{:error, {:parse_error, "can't parse entities"}}])

    state =
      Sender.new(%{
        client: Fake,
        client_opts: [fake: fake],
        rate_per_sec: 1_000,
        action_grants: %{infra: [:telegram_ingress]}
      })

    {:noreply, state} =
      Sender.handle_message(
        :telegram_ingress,
        %{
          "action" => "send_rich_raw",
          "conversation_id" => "tg:123:0",
          "rich_message" => %{"html" => "<bad>"}
        },
        state
      )

    [rich_call] = Fake.calls(fake)
    assert rich_call.method == :send_rich_message

    assert [
             %{
               result:
                 {:error,
                  {:parse_error, "rich message parse failed and no fallback_text was provided"}}
             }
           ] = state.sent
  end

  test "unknown actions and unauthorized targets fail without touching Telegram" do
    {:ok, fake} = Fake.start_link()
    state = Sender.new(%{client: Fake, client_opts: [fake: fake], send_sources: [:trusted]})

    {:reply, unknown_body, state} =
      Sender.handle_message(:telegram_ingress, %{"action" => "not_real"}, state)

    assert Jason.decode!(unknown_body)["error"] == ":unknown_action"

    {:reply, unauthorized_body, _state} =
      Sender.handle_message(
        :telegram_ingress,
        %{"action" => "send", "conversation_id" => "tg:123:0", "text" => "no"},
        state
      )

    assert Jason.decode!(unauthorized_body)["error"] == ":unauthorized_target"
    assert Fake.calls(fake) == []
  end

  test "dead chats trigger delivery audit and unreachable side effects" do
    {:ok, fake} = Fake.start_link([{:error, {:dead_chat, 403, "blocked"}}])

    state =
      Sender.new(%{
        client: Fake,
        client_opts: [fake: fake],
        delivery_effects: {AuditEffects, %{test_pid: self()}},
        rate_per_sec: 1_000
      })

    {:noreply, state} =
      Sender.handle_message(
        :telegram_ingress,
        %{"action" => "send", "conversation_id" => "tg:123:0", "text" => "hello"},
        state
      )

    assert_receive {:after_delivery, %{conversation_id: "tg:123:0", text: "hello"},
                    %{ok: false, result: {:error, {:dead_chat, 403, "blocked"}}},
                    %{origin: :proactive}}

    assert_receive {:unreachable, "tg:123:0", {:dead_chat, 403, "blocked"}, %{origin: :proactive}}

    assert [%{conversation_id: "tg:123:0", result: {:error, {:dead_chat, 403, "blocked"}}}] =
             state.sent

    [%{kind: :extension, name: "deliveries", data: %{count: 1, items: [item]}}] =
      Sender.dashboard(state)

    assert item.status == "dead_chat"
  end

  test "audit action, unauthorized batch, and slot reply guards do not call Telegram" do
    {:ok, fake} = Fake.start_link()

    state =
      Sender.new(%{
        client: Fake,
        client_opts: [fake: fake],
        batch_sources: [:batcher],
        slot_reply_sources: [:slotter],
        audit_sources: [:auditor],
        rate_per_sec: 1_000
      })

    {:reply, body, state} = Sender.handle_message(:auditor, %{"action" => "audit"}, state)
    assert Jason.decode!(body)["sent"] == []

    {:reply, body, state} = Sender.handle_message(:tester, %{"action" => "audit"}, state)
    assert Jason.decode!(body)["error"] == ":unauthorized_audit"

    {:reply, body, state} =
      Sender.handle_message(
        :tester,
        %{
          "action" => "send_batch",
          "recipients" => ["tg:123:0"],
          "text" => "batch"
        },
        state
      )

    assert Jason.decode!(body)["error"] == ":unauthorized_batch"

    {:reply, body, state} =
      Sender.handle_message(
        :slotter,
        %{"action" => "slot_reply", "slot" => "missing", "content" => "hello"},
        state
      )

    assert Jason.decode!(body)["error"] == ":unbound_slot"

    {:reply, body, _state} =
      Sender.handle_message(
        :tester,
        %{"action" => "slot_reply", "slot" => "missing", "content" => "hello"},
        state
      )

    assert Jason.decode!(body)["error"] == ":unauthorized_slot_reply"
    assert Fake.calls(fake) == []
  end

  test "binding authority is enforced for bind and unbind session messages" do
    {:ok, fake} = Fake.start_link()

    state =
      Sender.new(%{
        client: Fake,
        client_opts: [fake: fake],
        binding_authority: :ingress_a,
        rate_per_sec: 1_000
      })

    {:reply, body, state} =
      Sender.handle_message(
        :other,
        %{
          "action" => "bind_session",
          "slot" => "telegram_agent_0",
          "conversation_id" => "tg:1:0"
        },
        state
      )

    assert Jason.decode!(body)["error"] == ":unauthorized_binding"
    assert state.slots == %{}

    {:noreply, state} =
      Sender.handle_message(
        :ingress_a,
        %{
          "action" => "bind_session",
          "slot" => "telegram_agent_0",
          "conversation_id" => "tg:1:0"
        },
        state
      )

    assert state.slots == %{"telegram_agent_0" => "tg:1:0"}

    {:reply, body, state} =
      Sender.handle_message(
        :other,
        %{"action" => "unbind_session", "slot" => "telegram_agent_0"},
        state
      )

    assert Jason.decode!(body)["error"] == ":unauthorized_binding"
    assert state.slots == %{"telegram_agent_0" => "tg:1:0"}

    {:noreply, state} =
      Sender.handle_message(
        :ingress_a,
        %{"action" => "unbind_session", "slot" => "telegram_agent_0"},
        state
      )

    assert state.slots == %{}
    assert Fake.calls(fake) == []
  end

  test "empty sends are logical deliveries with no Telegram call but still audit outcome" do
    {:ok, fake} = Fake.start_link()

    state =
      Sender.new(%{
        client: Fake,
        client_opts: [fake: fake],
        delivery_effects: {AuditEffects, %{test_pid: self()}},
        rate_per_sec: 1_000
      })

    {:noreply, state} =
      Sender.handle_message(
        :telegram_ingress,
        %{"action" => "send", "conversation_id" => "tg:123:0", "text" => "   ", "mark" => "m1"},
        state
      )

    assert Fake.calls(fake) == []

    assert_receive {:after_delivery, %{conversation_id: "tg:123:0", text: "   "},
                    %{ok: false, result: {:error, :empty}}, %{origin: :proactive, mark: "m1"}}

    assert state.sent == []

    [%{kind: :extension, name: "deliveries", data: %{count: 0, items: []}}] =
      Sender.dashboard(state)
  end

  test "send_message retries transient and zero-second rate-limited failures once" do
    {:ok, fake} =
      Fake.start_link([
        {:error, {:rate_limited, 0, "slow down"}},
        {:ok, %{"message_id" => 11}},
        {:error, {:transient, 502, "bad gateway"}},
        {:ok, %{"message_id" => 12}}
      ])

    state = Sender.new(%{client: Fake, client_opts: [fake: fake], rate_per_sec: 1_000})

    {:noreply, state} =
      Sender.handle_message(
        :telegram_ingress,
        %{"action" => "send", "conversation_id" => "tg:123:0", "text" => "first"},
        state
      )

    {:noreply, state} =
      Sender.handle_message(
        :telegram_ingress,
        %{"action" => "send", "conversation_id" => "tg:123:0", "text" => "second"},
        state
      )

    assert Enum.map(Fake.calls(fake), & &1.method) ==
             [:send_message, :send_message, :send_message, :send_message]

    assert [%{result: {:ok, %{"message_id" => 12}}}, %{result: {:ok, %{"message_id" => 11}}}] =
             state.sent
  end

  test "plain send falls back without parse mode when Telegram rejects formatted HTML" do
    {:ok, fake} =
      Fake.start_link([
        {:error, {:parse_error, "can't parse entities"}},
        {:ok, %{"message_id" => 31}}
      ])

    state = Sender.new(%{client: Fake, client_opts: [fake: fake], rate_per_sec: 1_000})

    {:noreply, state} =
      Sender.handle_message(
        :telegram_ingress,
        %{"action" => "send", "conversation_id" => "tg:123:0", "text" => "<b>hello</b>"},
        state
      )

    [formatted, fallback] = Fake.calls(fake)
    assert formatted.method == :send_message
    assert formatted.payload.parse_mode == "HTML"
    assert fallback.method == :send_message
    assert fallback.payload.text == "<b>hello</b>"
    refute Map.has_key?(fallback.payload, :parse_mode)
    assert [%{result: {:ok, %{"message_id" => 31}}}] = state.sent
  end

  test "progress messages create status, coalesce quick edits, flush pending text, and expire" do
    {:ok, fake} = Fake.start_link()

    state =
      Sender.new(%{
        client: Fake,
        client_opts: [fake: fake],
        progress_min_interval_ms: 60_000,
        progress_ttl_ms: 1,
        rate_per_sec: 1_000
      })

    {:noreply, state} =
      Sender.handle_message(
        :telegram_ingress,
        %{"action" => "progress", "conversation_id" => "tg:123:0", "text" => "Working"},
        state
      )

    assert %{message_id: 1, pending: nil, edits: 0} = state.progress["tg:123:0"]

    {:noreply, state} =
      Sender.handle_message(
        :telegram_ingress,
        %{"action" => "progress", "conversation_id" => "tg:123:0", "text" => "Still working"},
        state
      )

    assert %{pending: "Still working", edits: 0} = state.progress["tg:123:0"]

    {:noreply, state} = Sender.handle_info({:progress_flush, "tg:123:0"}, state)
    assert %{pending: nil, edits: 1} = state.progress["tg:123:0"]

    Process.sleep(2)
    {:noreply, state} = Sender.handle_info({:progress_expire, "tg:123:0"}, state)
    refute Map.has_key?(state.progress, "tg:123:0")

    assert Enum.map(Fake.calls(fake), & &1.method) == [:send_message, :edit_message_text]
  end

  test "typing keepalive decrements, clears, and ignores unrelated info messages" do
    {:ok, fake} = Fake.start_link()

    state =
      Sender.new(%{
        client: Fake,
        client_opts: [fake: fake],
        bot_token: "token",
        rate_per_sec: 1_000
      })

    {:noreply, state} =
      Sender.handle_message(
        :telegram_ingress,
        %{"action" => "typing", "conversation_id" => "tg:123:0", "message_id" => 99},
        state
      )

    assert state.typing["tg:123:0"] == 15
    assert state.owed["tg:123:0"] == 1
    assert state.inbound["tg:123:0"] == [99]

    {:noreply, state} = Sender.handle_info({:typing, "tg:123:0"}, state)
    assert state.typing["tg:123:0"] == 14

    state = %{state | typing: %{"tg:123:0" => 1}, owed: %{"tg:123:0" => 1}}
    {:noreply, state} = Sender.handle_info({:typing, "tg:123:0"}, state)
    refute Map.has_key?(state.typing, "tg:123:0")
    refute Map.has_key?(state.owed, "tg:123:0")

    {:noreply, ^state} = Sender.handle_info(:unexpected, state)
    assert Enum.map(Fake.calls(fake), & &1.method) == [:send_chat_action, :send_chat_action]
  end

  test "card metadata actions and invalid payload errors return structured replies" do
    {:ok, fake} = Fake.start_link()
    state = Sender.new(%{client: Fake, client_opts: [fake: fake], rate_per_sec: 1_000})

    {:reply, body, state} =
      Sender.handle_message(:telegram_ingress, %{"action" => "capabilities"}, state)

    assert %{"ok" => true, "capabilities" => capabilities} = Jason.decode!(body)
    assert is_map(capabilities)

    {:reply, body, state} =
      Sender.handle_message(:telegram_ingress, %{"action" => "examples"}, state)

    assert %{"ok" => true, "examples" => examples} = Jason.decode!(body)
    assert is_list(examples)

    {:reply, body, state} =
      Sender.handle_message(
        :telegram_ingress,
        %{"action" => "validate_card", "card" => %{"blocks" => [%{"kind" => "unknown"}]}},
        state
      )

    assert %{"ok" => false, "error" => "invalid_card", "errors" => [_ | _]} =
             Jason.decode!(body)

    {:reply, body, _state} =
      Sender.handle_message(
        :telegram_ingress,
        %{"action" => "send_media", "conversation_id" => "tg:123:0", "media_type" => "bad"},
        state
      )

    assert %{
             "ok" => false,
             "error" => "invalid_payload",
             "reason" => "invalid Telegram media_type: \"bad\""
           } = Jason.decode!(body)

    assert Fake.calls(fake) == []
  end

  test "slot replies reject unsafe content and suppress repeated answered replies" do
    {:ok, fake} = Fake.start_link()

    state =
      Sender.new(%{
        client: Fake,
        client_opts: [fake: fake],
        slot_reply_sources: [:slotter],
        rate_per_sec: 1_000
      })

    state = %{state | slots: %{"telegram_agent_0" => "tg:123:0"}}

    {:reply, body, state} =
      Sender.handle_message(
        :slotter,
        %{"action" => "slot_reply", "slot" => "telegram_agent_0", "content" => "tg:999:0"},
        state
      )

    assert Jason.decode!(body)["error"] == ":invalid_slot_reply"

    state = %{state | last_reply_ms: %{"tg:123:0" => System.monotonic_time(:millisecond)}}

    {:noreply, state} =
      Sender.handle_message(
        :slotter,
        %{"action" => "slot_reply", "slot" => "telegram_agent_0", "content" => "already done"},
        state
      )

    assert Fake.calls(fake) == []
    assert state.sent == []
  end

  test "public sender helpers classify Telegram responses and rate limit disabled windows" do
    assert Sender.extract_message_id(~s({"ok":true,"result":{"message_id":44}})) == {:ok, 44}

    assert Sender.extract_message_id(~s({"ok":true,"result":{}})) ==
             {:failed, "no message_id in response"}

    assert {:unreachable, "blocked"} =
             Sender.extract_message_id(~s({"ok":false,"error_code":403,"description":"blocked"}))

    assert Sender.classify_send_response(
             ~s({"ok":false,"error_code":429,"parameters":{"retry_after":2},"description":"slow"})
           ) ==
             {:retry_after, 2}

    assert Sender.throttle_decision([1, 2, 3], 10, 0) == {:proceed, [10, 1, 2, 3]}
    assert Sender.build_send_body("tg:123:9", "hi", nil, nil, nil).message_thread_id == 9

    assert Sender.resolve_photo({"sent", nil}, :state, fn _ ->
             flunk("should not resolve fallback")
           end) ==
             {"sent", nil, :state}

    assert Sender.resolve_photo({"failed", nil}, :state, fn state ->
             {"fallback", "photo", state}
           end) ==
             {"fallback", "photo", :state}
  end
end

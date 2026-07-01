defmodule Genswarms.Telegram.ObjectsTest do
  use ExUnit.Case

  alias Genswarms.Telegram.Client.Fake
  alias Genswarms.Telegram.Objects.{Ingress, Sender}

  setup do
    dir = Path.join(System.tmp_dir!(), "gst-objects-#{System.unique_integer([:positive])}")
    Application.put_env(:genswarms_telegram, :state_dir, dir)

    on_exit(fn ->
      Application.delete_env(:genswarms_telegram, :state_dir)
      File.rm_rf(dir)
    end)

    {:ok, fake} = Fake.start_link()
    {:ok, fake: fake}
  end

  test "sender binds slots, forces bound cid, and rejects unbound agent-like origins", %{
    fake: fake
  } do
    {:ok, state} =
      Sender.init(%{
        bot_token: "token",
        client: Fake,
        client_opts: [fake: fake],
        binding_authority: :telegram_ingress,
        slot_prefix: "telegram_agent"
      })

    {:noreply, state} =
      Sender.handle_message(
        :telegram_ingress,
        %{
          "action" => "bind_session",
          "slot" => "telegram_agent_0",
          "conversation_id" => "tg:1:0"
        },
        state
      )

    {:noreply, state} =
      Sender.handle_message(
        :telegram_agent_0,
        %{"action" => "reply", "conversation_id" => "tg:999:0", "text" => "hi"},
        state
      )

    [call] = Fake.calls(fake)
    assert call.method == :send_message
    assert call.payload.chat_id == "1"
    assert hd(state.sent).conversation_id == "tg:1:0"

    {:reply, body, _state} =
      Sender.handle_message(
        :telegram_agent_9,
        %{"action" => "reply", "conversation_id" => "tg:9:0", "text" => "no"},
        state
      )

    assert Jason.decode!(body)["ok"] == false
  end

  test "sender validates reply tags and retries plain text on Telegram parse errors", %{
    fake: fake
  } do
    Fake.push_response(fake, {:ok, true})
    Fake.push_response(fake, {:error, {:parse_error, "can't parse entities"}})
    Fake.push_response(fake, {:ok, %{"message_id" => 2}})

    {:ok, state} =
      Sender.init(%{
        bot_token: "token",
        client: Fake,
        client_opts: [fake: fake],
        binding_authority: :telegram_ingress,
        slot_prefix: "telegram_agent"
      })

    {:noreply, state} =
      Sender.handle_message(
        :telegram_ingress,
        %{
          "action" => "bind_session",
          "slot" => "telegram_agent_0",
          "conversation_id" => "tg:1:0"
        },
        state
      )

    {:noreply, state} =
      Sender.handle_message(
        :telegram_ingress,
        %{"action" => "typing", "conversation_id" => "tg:1:0", "message_id" => 55},
        state
      )

    {:noreply, _state} =
      Sender.handle_message(
        :telegram_agent_0,
        %{"action" => "reply", "text" => "**hi**", "reply_to_message_id" => "55"},
        state
      )

    [_typing, html_send, plain_retry] = Fake.calls(fake)

    assert html_send.payload.reply_parameters == %{
             message_id: 55,
             allow_sending_without_reply: true
           }

    assert html_send.payload.text == "<b>hi</b>"
    refute Map.has_key?(plain_retry.payload, :parse_mode)
    assert plain_retry.payload.text == "hi"
  end

  test "sender keeps reply threading on photo replies", %{fake: fake} do
    {:ok, state} =
      Sender.init(%{
        bot_token: "token",
        client: Fake,
        client_opts: [fake: fake],
        slot_prefix: "telegram_agent"
      })

    {:noreply, state} =
      Sender.handle_message(
        :telegram_ingress,
        %{
          "action" => "bind_session",
          "slot" => "telegram_agent_0",
          "conversation_id" => "tg:1:0"
        },
        state
      )

    {:noreply, state} =
      Sender.handle_message(
        :telegram_ingress,
        %{"action" => "typing", "conversation_id" => "tg:1:0", "message_id" => 55},
        state
      )

    {:noreply, _state} =
      Sender.handle_message(
        :telegram_agent_0,
        %{
          "action" => "reply",
          "text" => "look",
          "photo" => "https://example.com/a.png",
          "reply_to_message_id" => "55"
        },
        state
      )

    [_typing, photo_send] = Fake.calls(fake)

    assert photo_send.method == :send_photo

    assert photo_send.payload.reply_parameters == %{
             message_id: 55,
             allow_sending_without_reply: true
           }
  end

  test "sender keeps quote fields on validated bound replies", %{fake: fake} do
    {:ok, state} =
      Sender.init(%{
        bot_token: "token",
        client: Fake,
        client_opts: [fake: fake],
        binding_authority: :telegram_ingress,
        slot_prefix: "telegram_agent"
      })

    {:noreply, state} =
      Sender.handle_message(
        :telegram_ingress,
        %{
          "action" => "bind_session",
          "slot" => "telegram_agent_0",
          "conversation_id" => "tg:1:0"
        },
        state
      )

    {:noreply, state} =
      Sender.handle_message(
        :telegram_ingress,
        %{"action" => "typing", "conversation_id" => "tg:1:0", "message_id" => 55},
        state
      )

    {:noreply, _state} =
      Sender.handle_message(
        :telegram_agent_0,
        %{
          "action" => "reply",
          "text" => "replying to the quote",
          "reply_to_message_id" => "55",
          "quote" => "the quote",
          "quote_position" => "13",
          "quote_parse_mode" => "HTML"
        },
        state
      )

    [_typing, reply] = Fake.calls(fake)

    assert reply.payload.reply_parameters == %{
             message_id: 55,
             allow_sending_without_reply: true,
             quote: "the quote",
             quote_position: 13,
             quote_parse_mode: "HTML"
           }
  end

  test "sender posts progress once then edits the progress message", %{fake: fake} do
    Fake.push_response(fake, {:ok, %{"message_id" => 77}})
    Fake.push_response(fake, {:ok, %{"message_id" => 77}})

    {:ok, state} =
      Sender.init(%{
        bot_token: "token",
        client: Fake,
        client_opts: [fake: fake],
        slot_prefix: "telegram_agent"
      })

    {:noreply, state} =
      Sender.handle_message(
        :internal,
        %{"action" => "progress", "conversation_id" => "tg:1:0", "text" => "step 1"},
        state
      )

    {:noreply, state} =
      Sender.handle_message(
        :internal,
        %{"action" => "progress", "conversation_id" => "tg:1:0", "text" => "step 2"},
        state
      )

    assert state.progress["tg:1:0"].pending == "step 2"
    {:noreply, _state} = Sender.handle_info({:progress_flush, "tg:1:0"}, state)

    [post, edit] = Fake.calls(fake)
    assert post.method == :send_message
    assert edit.method == :edit_message_text
    assert edit.payload.message_id == 77
    assert edit.payload.text == "step 2"
  end

  test "sender rejects malformed explicit conversation ids", %{fake: fake} do
    {:ok, state} =
      Sender.init(%{
        bot_token: "token",
        client: Fake,
        client_opts: [fake: fake],
        send_sources: [:cron]
      })

    {:reply, body, _state} =
      Sender.handle_message(
        :internal,
        %{"action" => "send", "conversation_id" => "tg:123:notint", "text" => "bad"},
        state
      )

    assert Jason.decode!(body)["ok"] == false
    assert Fake.calls(fake) == []
  end

  test "sender authorizes batch sends and falls back when photo delivery fails", %{fake: fake} do
    Fake.push_response(fake, {:ok, %{"message_id" => 1}})
    Fake.push_response(fake, {:ok, %{"message_id" => 2}})
    Fake.push_response(fake, {:error, {:failed, 400, "bad photo"}})
    Fake.push_response(fake, {:ok, %{"message_id" => 3}})

    {:ok, state} =
      Sender.init(%{
        bot_token: "token",
        client: Fake,
        client_opts: [fake: fake],
        batch_sources: [:cron],
        send_sources: [:cron]
      })

    {:noreply, state} =
      Sender.handle_message(
        :cron,
        %{
          "action" => "send_batch",
          "recipients" => [%{"conversation_id" => "tg:1:0"}, %{"conversation_id" => "tg:2:0"}],
          "text" => "batch"
        },
        state
      )

    assert :queue.len(state.outbox) == 2
    assert state.sent == []

    {:noreply, state} = Sender.handle_info(:pump, state)
    {:noreply, state} = Sender.handle_info(:pump, state)
    assert :queue.is_empty(state.outbox)

    {:noreply, _state} =
      Sender.handle_message(
        :cron,
        %{
          "action" => "send",
          "conversation_id" => "tg:3:0",
          "text" => "photo text",
          "photo" => "https://example.com/a.png"
        },
        state
      )

    calls = Fake.calls(fake)

    assert Enum.map(calls, & &1.method) == [
             :send_message,
             :send_message,
             :send_photo,
             :send_message
           ]

    assert Enum.at(calls, 3).payload.text == "photo text"
  end

  test "sender normalizes safe buttons and drops invalid buttons", %{fake: fake} do
    {:ok, state} =
      Sender.init(%{
        bot_token: "token",
        client: Fake,
        client_opts: [fake: fake],
        send_sources: [:cron]
      })

    {:noreply, _state} =
      Sender.handle_message(
        :cron,
        %{
          "action" => "send",
          "conversation_id" => "tg:3:0",
          "text" => "pick",
          "buttons" => [
            [%{"text" => "Open", "url" => "https://example.com"}],
            [%{"text" => "Mode", "action" => "mode quiet"}],
            [%{"text" => "App", "web_app" => "https://example.com/app"}],
            [%{"text" => "Inline", "switch_inline_query_current_chat" => "query"}],
            [%{"text" => "Copy", "copy_text" => "copy me"}],
            [%{"text" => "Bad", "url" => "javascript:alert"}],
            [%{"text" => "Long", "action" => String.duplicate("a", 65)}]
          ]
        },
        state
      )

    [call] = Fake.calls(fake)

    assert call.payload.reply_markup == %{
             inline_keyboard: [
               [%{text: "Open", url: "https://example.com"}],
               [%{text: "Mode", callback_data: "mode quiet"}],
               [%{text: "App", web_app: %{url: "https://example.com/app"}}],
               [%{text: "Inline", switch_inline_query_current_chat: "query"}],
               [%{text: "Copy", copy_text: %{text: "copy me"}}]
             ]
           }
  end

  test "sender rejects explicit targets from unauthorized sources", %{fake: fake} do
    {:ok, state} =
      Sender.init(%{
        bot_token: "token",
        client: Fake,
        client_opts: [fake: fake],
        send_sources: [:cron]
      })

    {:reply, body, _state} =
      Sender.handle_message(
        :unknown_object,
        %{"action" => "send", "conversation_id" => "tg:1:0", "text" => "no"},
        state
      )

    assert Jason.decode!(body)["ok"] == false
    assert Fake.calls(fake) == []
  end

  test "sender sends long photo messages as text instead of overlong captions", %{fake: fake} do
    {:ok, state} =
      Sender.init(%{
        bot_token: "token",
        client: Fake,
        client_opts: [fake: fake],
        send_sources: [:cron]
      })

    {:noreply, _state} =
      Sender.handle_message(
        :cron,
        %{
          "action" => "send",
          "conversation_id" => "tg:3:0",
          "text" => String.duplicate("x", 1_025),
          "photo" => "https://example.com/a.png"
        },
        state
      )

    [call] = Fake.calls(fake)
    assert call.method == :send_message
    refute Map.has_key?(call.payload, :photo)
  end

  test "sender tracks owed turns, keeps typing through bursts, and suppresses duplicate slot replies" do
    {:ok, state} =
      Sender.init(%{
        dry_run: true,
        binding_authority: :telegram_ingress,
        slot_prefix: "telegram_agent"
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

    state =
      Enum.reduce(1..3, state, fn id, acc ->
        {:noreply, next} =
          Sender.handle_message(
            :telegram_ingress,
            %{"action" => "typing", "conversation_id" => "tg:55:0", "message_id" => id},
            acc
          )

        next
      end)

    assert state.owed["tg:55:0"] == 3
    assert Map.has_key?(state.typing, "tg:55:0")

    {:noreply, state} =
      Sender.handle_message(:telegram_agent_0, %{"action" => "reply", "text" => "one"}, state)

    assert state.owed["tg:55:0"] == 2
    assert Map.has_key?(state.typing, "tg:55:0")

    {:noreply, state} =
      Sender.handle_message(:telegram_agent_0, %{"action" => "reply", "text" => "two"}, state)

    assert state.owed["tg:55:0"] == 1
    assert Map.has_key?(state.typing, "tg:55:0")

    {:noreply, state} =
      Sender.handle_message(:telegram_agent_0, %{"action" => "reply", "text" => "three"}, state)

    assert state.owed == %{}
    refute Map.has_key?(state.typing, "tg:55:0")
    assert length(state.sent) == 3

    {:noreply, state} =
      Sender.handle_message(
        :telegram_agent_0,
        %{"action" => "reply", "text" => "duplicate"},
        state
      )

    assert length(state.sent) == 3
  end

  test "sender reply cap fails open when a slot has no prior reply stamp" do
    {:ok, state} =
      Sender.init(%{
        dry_run: true,
        binding_authority: :telegram_ingress,
        slot_prefix: "telegram_agent"
      })

    {:noreply, state} =
      Sender.handle_message(
        :telegram_ingress,
        %{
          "action" => "bind_session",
          "slot" => "telegram_agent_0",
          "conversation_id" => "tg:77:0"
        },
        state
      )

    {:noreply, state} =
      Sender.handle_message(
        :telegram_agent_0,
        %{"action" => "reply", "text" => "first reply despite missing typing note"},
        state
      )

    assert length(state.sent) == 1
  end

  test "sender typing safety cap clears coupled state" do
    {:ok, state} = Sender.init(%{dry_run: true})

    state = %{
      state
      | typing: %{"tg:1:0" => 1},
        owed: %{"tg:1:0" => 2},
        last_reply_ms: %{"tg:1:0" => System.monotonic_time(:millisecond)}
    }

    {:noreply, state} = Sender.handle_info({:typing, "tg:1:0"}, state)

    assert state.typing == %{}
    assert state.owed == %{}
    assert state.last_reply_ms == %{}
  end

  test "sender outbox cap keeps queued jobs bounded and pump drains one job per tick" do
    {:ok, state} =
      Sender.init(%{
        dry_run: true,
        batch_sources: [:cron],
        outbox_max: 2
      })

    {:noreply, state} =
      Sender.handle_message(
        :cron,
        %{
          "action" => "send_batch",
          "recipients" => ["tg:1:0", "tg:2:0", "tg:3:0"],
          "text" => "batch"
        },
        state
      )

    assert :queue.len(state.outbox) == 2
    assert state.sent == []

    {:noreply, state} = Sender.handle_info(:pump, state)
    assert :queue.len(state.outbox) == 1
    assert length(state.sent) == 1

    {:noreply, state} = Sender.handle_info(:pump, state)
    assert :queue.is_empty(state.outbox)
    assert length(state.sent) == 2
  end

  test "sender public helpers cover payloads, response classification, and throttling" do
    assert Sender.chunk_text("hello") == ["hello"]
    assert ["aa", "a"] = Sender.chunk_text("aaa", 2)

    body = Sender.build_send_body("tg:-100123:9", "hi", "HTML", nil, 42)
    assert body.chat_id == "-100123"
    assert body.message_thread_id == 9
    assert body.reply_parameters == %{message_id: 42, allow_sending_without_reply: true}

    photo = Sender.build_photo_body("tg:5:0", "https://example.com/a.png", "look", "HTML")
    assert photo.chat_id == "5"
    assert photo.photo == "https://example.com/a.png"
    refute Map.has_key?(photo, :message_thread_id)

    threaded_photo =
      Sender.build_photo_body(
        "tg:-100123:9",
        "https://example.com/a.png",
        "look",
        "HTML",
        nil,
        42
      )

    assert threaded_photo.message_thread_id == 9
    assert threaded_photo.reply_parameters == %{message_id: 42, allow_sending_without_reply: true}

    assert Sender.use_photo?("https://example.com/a.png", "short")
    refute Sender.use_photo?("https://example.com/a.png", String.duplicate("a", 1_025))
    refute Sender.use_photo?(nil, "short")

    assert Sender.build_reply_markup([[%{"text" => "Open", "url" => "https://example.com"}]]) ==
             %{inline_keyboard: [[%{text: "Open", url: "https://example.com"}]]}

    assert Sender.extract_message_id(~s({"ok":true,"result":{"message_id":42}})) == {:ok, 42}
    assert Sender.classify_send_response(~s({"ok":true,"result":{}})) == :ok

    assert match?(
             {:parse_error, _},
             Sender.classify_send_response(
               ~s({"ok":false,"error_code":400,"description":"Bad Request: can't parse entities"})
             )
           )

    assert match?(
             {:unreachable, _},
             Sender.classify_send_response(
               ~s({"ok":false,"error_code":403,"description":"Forbidden: bot was blocked by the user"})
             )
           )

    assert Sender.classify_send_response(
             ~s({"ok":false,"error_code":429,"description":"Too Many Requests"})
           ) == {:retry_after, 1}

    assert Sender.permanent_dead_chat?("Bad Request: chat not found")
    assert Sender.throttle_decision([100], 200, 2) == {:proceed, [200, 100]}
    assert Sender.throttle_decision([900, 100], 1_000, 2) == {:sleep, 100, [900, 100]}
    assert Sender.mark_after_attempt?("sent")
    assert Sender.mark_after_attempt?("failed")
    refute Sender.mark_after_attempt?("unreachable")
  end

  test "ingress routes addressed messages through fake runtime and fails closed in groups", %{
    fake: fake
  } do
    parent = self()

    defmodule RuntimeForIngressTest do
      def ensure_session(cid, _opts), do: {:ok, %{slot: :telegram_agent_0, conversation_id: cid}}

      def deliver_to_session(session, text, opts) do
        send(opts.parent, {:delivered, session, text})
        :ok
      end
    end

    {:ok, state} =
      Ingress.init(%{
        bot_token: "token",
        client: Fake,
        client_opts: [fake: fake],
        session_runtime: RuntimeForIngressTest,
        session_opts: %{parent: parent},
        bot_username: nil
      })

    group_update = %{
      "update_id" => 1,
      "message" => %{"chat" => %{"id" => -100}, "text" => "hello"}
    }

    {:reply, body, state} =
      Ingress.handle_message(
        :test,
        %{"action" => "inject_update", "update" => group_update},
        state
      )

    assert Jason.decode!(body)["skipped"] == "not_addressed"
    refute_receive {:delivered, _, _}

    dm_update = %{
      "update_id" => 2,
      "message" => %{"chat" => %{"id" => 123}, "text" => "hello"}
    }

    {:reply, body, _state} =
      Ingress.handle_message(:test, %{"action" => "inject_update", "update" => dm_update}, state)

    assert Jason.decode!(body)["routed"] == true
    assert_receive {:delivered, %{conversation_id: "tg:123:0"}, text}
    assert text =~ "hello"
  end

  test "ingress binds the session before delivery when runtime supports binding", %{fake: fake} do
    parent = self()

    defmodule RuntimeForBindBeforeDeliverTest do
      def ensure_session(cid, _opts), do: {:ok, %{slot: :telegram_agent_0, conversation_id: cid}}

      def bind_session(session, cid, sinks, opts) do
        send(opts.parent, {:bound, session, cid, sinks})
        :ok
      end

      def deliver_to_session(session, text, opts) do
        send(opts.parent, {:delivered, session, text})
        :ok
      end
    end

    {:ok, state} =
      Ingress.init(%{
        bot_token: "token",
        client: Fake,
        client_opts: [fake: fake],
        session_runtime: RuntimeForBindBeforeDeliverTest,
        session_opts: %{parent: parent},
        binding_sinks: [:telegram_sender],
        bot_username: nil
      })

    update = %{
      "update_id" => 6,
      "message" => %{"chat" => %{"id" => 123}, "text" => "hello"}
    }

    {:reply, body, _state} =
      Ingress.handle_message(:test, %{"action" => "inject_update", "update" => update}, state)

    assert Jason.decode!(body)["routed"] == true
    assert_receive {:bound, %{slot: :telegram_agent_0}, "tg:123:0", [:telegram_sender]}
    assert_receive {:delivered, %{conversation_id: "tg:123:0"}, text}
    assert text =~ "hello"
  end

  test "ingress routes command router replies through the sender", %{fake: fake} do
    {:ok, state} =
      Ingress.init(%{
        bot_token: "token",
        client: Fake,
        client_opts: [fake: fake],
        bot_username: "OurBot"
      })

    update = %{
      "update_id" => 4,
      "message" => %{"chat" => %{"id" => 123}, "text" => "/help"}
    }

    assert {:send, :telegram_sender, payload, state} =
             Ingress.handle_message(
               :test,
               %{"action" => "inject_update", "update" => update},
               state
             )

    decoded = Jason.decode!(payload)
    assert decoded["action"] == "send"
    assert decoded["conversation_id"] == "tg:123:0"
    assert decoded["text"] =~ "route it to the swarm"

    assert [%{conversation_id: "tg:123:0", target: :telegram_sender, routed: true}] =
             state.replies

    assert Fake.calls(fake) == []

    sender =
      Sender.new(%{
        bot_token: "token",
        client: Fake,
        client_opts: [fake: fake],
        binding_authority: :telegram_ingress,
        rate_per_sec: 1_000
      })

    assert {:noreply, sender} = Sender.handle_message(:telegram_ingress, decoded, sender)

    [call] = Fake.calls(fake)
    assert call.method == :send_message
    assert call.payload.chat_id == "123"
    assert call.payload.text =~ "route it to the swarm"
    assert [%{conversation_id: "tg:123:0"}] = sender.sent
    assert sender.window != []
  end

  test "ingress routes leading-whitespace slash commands to command router", %{fake: fake} do
    parent = self()

    defmodule RuntimeForCommandBypassTest do
      def ensure_session(cid, _opts), do: {:ok, %{slot: :telegram_agent_0, conversation_id: cid}}

      def deliver_to_session(session, text, opts) do
        send(opts.parent, {:unexpected_command_delivery, session, text})
        :ok
      end
    end

    {:ok, state} =
      Ingress.init(%{
        bot_token: "token",
        client: Fake,
        client_opts: [fake: fake],
        session_runtime: RuntimeForCommandBypassTest,
        session_opts: %{parent: parent},
        bot_username: "OurBot"
      })

    leading_update = %{
      "update_id" => 41,
      "message" => %{"chat" => %{"id" => 123}, "text" => "   /help"}
    }

    {:send, :telegram_sender, payload, state} =
      Ingress.handle_message(
        :test,
        %{"action" => "inject_update", "update" => leading_update},
        state
      )

    assert Jason.decode!(payload)["action"] == "send"
    assert Fake.calls(fake) == []
    refute_receive {:unexpected_command_delivery, _, _}

    foreign_update = %{
      "update_id" => 42,
      "message" => %{"chat" => %{"id" => 123}, "text" => "   /help@OtherBot"}
    }

    {:reply, body, _state} =
      Ingress.handle_message(
        :test,
        %{"action" => "inject_update", "update" => foreign_update},
        state
      )

    assert Jason.decode!(body)["skipped"] == "not_addressed"
    refute_receive {:unexpected_command_delivery, _, _}
  end

  test "ingress acknowledges callback queries through the Telegram client", %{fake: fake} do
    {:ok, state} =
      Ingress.init(%{
        bot_token: "token",
        client: Fake,
        client_opts: [fake: fake],
        bot_username: "OurBot"
      })

    update = %{
      "update_id" => 5,
      "callback_query" => %{
        "id" => "cb-1",
        "from" => %{"id" => 7},
        "data" => "noop",
        "message" => %{"message_id" => 8, "chat" => %{"id" => 123}}
      }
    }

    {:reply, body, _state} =
      Ingress.handle_message(:test, %{"action" => "inject_update", "update" => update}, state)

    assert Jason.decode!(body)["command"] == true
    [call] = Fake.calls(fake)
    assert call.method == :answer_callback_query
    assert call.payload.callback_query_id == "cb-1"
  end

  test "ingress ignores slash commands explicitly addressed to another bot", %{fake: fake} do
    {:ok, state} =
      Ingress.init(%{
        bot_token: "token",
        client: Fake,
        client_opts: [fake: fake],
        bot_username: "OurBot"
      })

    update = %{
      "update_id" => 3,
      "message" => %{"chat" => %{"id" => -100}, "text" => "/help@OtherBot"}
    }

    {:reply, body, state} =
      Ingress.handle_message(:test, %{"action" => "inject_update", "update" => update}, state)

    assert Jason.decode!(body)["skipped"] == "not_addressed"
    assert state.replies == []
  end

  test "ingress poll result processes updates before committing next offset", %{fake: fake} do
    parent = self()

    defmodule RuntimeForPollResultTest do
      def ensure_session(cid, _opts), do: {:ok, %{slot: :telegram_agent_0, conversation_id: cid}}

      def deliver_to_session(session, text, opts) do
        send(opts.parent, {:poll_delivered, session, text})
        :ok
      end
    end

    {:ok, state} =
      Ingress.init(%{
        bot_token: "token",
        client: Fake,
        client_opts: [fake: fake],
        session_runtime: RuntimeForPollResultTest,
        session_opts: %{parent: parent},
        poll_enabled: false
      })

    update = %{
      "update_id" => 10,
      "message" => %{"chat" => %{"id" => 123}, "text" => "from poll"}
    }

    {:noreply, state} = Ingress.handle_info({:telegram_poll_result, {:ok, [update], 11}}, state)

    assert Genswarms.Telegram.Store.File.read_offset(state.bot_ref) == 11
    assert [%{event: %{update_id: 10}}] = state.routed
    assert_receive {:poll_delivered, %{conversation_id: "tg:123:0"}, text}
    assert text =~ "from poll"
  end

  test "ingress poll does not advance offset or dedupe failed deliveries", %{fake: fake} do
    defmodule RuntimeForPollFailureTest do
      def ensure_session(cid, _opts), do: {:ok, %{slot: :telegram_agent_0, conversation_id: cid}}
      def deliver_to_session(_session, _text, _opts), do: {:error, :downstream_down}
    end

    {:ok, state} =
      Ingress.init(%{
        bot_token: "token",
        client: Fake,
        client_opts: [fake: fake],
        session_runtime: RuntimeForPollFailureTest,
        poll_enabled: false
      })

    update = %{
      "update_id" => 20,
      "message" => %{"chat" => %{"id" => 123}, "text" => "will fail"}
    }

    {:noreply, state} = Ingress.handle_info({:telegram_poll_result, {:ok, [update], 21}}, state)
    assert state.poll_failures == 1
    assert Genswarms.Telegram.Store.File.read_offset(state.bot_ref) == 0
    refute Genswarms.Telegram.Store.File.update_seen?(state.bot_ref, 20)
  end

  test "ingress runtime admission skips are successful and deduped", %{fake: fake} do
    defmodule RuntimeForAdmissionSkipTest do
      def ensure_session(_cid, _opts), do: {:skip, :spawn_rate}
      def deliver_to_session(_session, _text, _opts), do: raise("skip should not deliver")
    end

    {:ok, state} =
      Ingress.init(%{
        bot_token: "token",
        client: Fake,
        client_opts: [fake: fake],
        session_runtime: RuntimeForAdmissionSkipTest,
        poll_enabled: false
      })

    update = %{
      "update_id" => 25,
      "message" => %{"chat" => %{"id" => 123}, "text" => "will be skipped"}
    }

    {:reply, body, state} =
      Ingress.handle_message(:test, %{"action" => "inject_update", "update" => update}, state)

    assert Jason.decode!(body)["skipped"] == "spawn_rate"
    assert Genswarms.Telegram.Store.File.update_seen?(state.bot_ref, 25)
  end

  test "ingress accepts modern session runtimes and calls routed effects", %{fake: fake} do
    parent = self()

    defmodule ModernRuntimeForIngressTest do
      @behaviour Genswarms.Telegram.SessionRuntime

      @impl true
      def ensure_session(cid, _event, _opts),
        do: {:ok, %{slot: :telegram_agent_0, conversation_id: cid}}

      @impl true
      def deliver_turn(session, turn, opts) do
        send(opts.parent, {:modern_turn, session, turn})
        :ok
      end
    end

    defmodule RoutedEffectsForIngressTest do
      @behaviour Genswarms.Telegram.InboundEffects

      @impl true
      def init(opts), do: {:ok, %{parent: opts.parent}}

      @impl true
      def before_route(event, _meta, state), do: {:cont, event, state}

      @impl true
      def after_routed(event, route, _meta, state) do
        send(state.parent, {:after_routed, event, route})
        {:ok, Map.put(state, :after_routed?, true)}
      end
    end

    {:ok, state} =
      Ingress.init(%{
        bot_token: "token",
        client: Fake,
        client_opts: [fake: fake],
        session_runtime: ModernRuntimeForIngressTest,
        session_opts: %{parent: parent},
        inbound_effects: {RoutedEffectsForIngressTest, %{parent: parent}},
        memory_policy: :none,
        poll_enabled: false
      })

    update = %{
      "update_id" => 26,
      "message" => %{"chat" => %{"id" => 123}, "text" => "modern route"}
    }

    {:reply, body, state} =
      Ingress.handle_message(:test, %{"action" => "inject_update", "update" => update}, state)

    assert Jason.decode!(body)["routed"] == true
    assert state.inbound_effects_state.after_routed? == true
    assert_receive {:modern_turn, %{conversation_id: "tg:123:0"}, %{text: "modern route"}}
    assert_receive {:after_routed, %{conversation_id: "tg:123:0"}, %{kind: :session}}
  end

  test "ingress calls routed effects for command router sends", %{fake: fake} do
    parent = self()

    defmodule SendCommandRouterForIngressTest do
      @behaviour Genswarms.Telegram.CommandRouter

      @impl true
      def handle_command(event, _state, opts \\ %{}) do
        send(opts.parent, {:command_seen, event.conversation_id})
        {:send, :commands, %{action: "command", conversation_id: event.conversation_id}}
      end

      @impl true
      def handle_callback(_event, _state, _opts \\ %{}), do: :ok
    end

    defmodule RoutedEffectsForCommandTest do
      @behaviour Genswarms.Telegram.InboundEffects

      @impl true
      def init(opts), do: {:ok, %{parent: opts.parent}}

      @impl true
      def after_routed(event, route, _meta, state) do
        send(state.parent, {:command_after_routed, event, route})
        {:ok, Map.put(state, :after_routed?, true)}
      end
    end

    {:ok, state} =
      Ingress.init(%{
        bot_token: "token",
        client: Fake,
        client_opts: [fake: fake],
        bot_username: "OurBot",
        command_router: {SendCommandRouterForIngressTest, %{parent: parent}},
        inbound_effects: {RoutedEffectsForCommandTest, %{parent: parent}},
        poll_enabled: false
      })

    update = %{
      "update_id" => 27,
      "message" => %{"chat" => %{"id" => 123}, "text" => "/start"}
    }

    {:send, :commands, payload, state} =
      Ingress.handle_message(:test, %{"action" => "inject_update", "update" => update}, state)

    assert Jason.decode!(payload)["conversation_id"] == "tg:123:0"
    assert state.inbound_effects_state.after_routed? == true
    assert_receive {:command_seen, "tg:123:0"}
    assert_receive {:command_after_routed, %{conversation_id: "tg:123:0"}, %{kind: :command}}
  end

  test "ingress registers command menus through the command router", %{fake: fake} do
    {:ok, state} =
      Ingress.init(%{
        bot_token: "token",
        client: Fake,
        client_opts: [fake: fake],
        command_router: Genswarms.Telegram.CommandRouter.Basic,
        poll_enabled: false
      })

    {:reply, body, _state} = Ingress.handle_message(:test, %{"action" => "set_commands"}, state)

    assert %{"ok" => true, "command_menus" => %{"dm" => 2, "group" => 1}} =
             Jason.decode!(body)

    [dm, group] = Fake.calls(fake)
    assert dm.method == :set_my_commands
    assert dm.payload.scope == %{type: "all_private_chats"}
    assert Enum.map(dm.payload.commands, & &1.command) == ["start", "help"]

    assert group.method == :set_my_commands
    assert group.payload.scope == %{type: "all_group_chats"}
    assert Enum.map(group.payload.commands, & &1.command) == ["help"]
  end

  test "ingress poll errors log the inspected Telegram reason", %{fake: fake} do
    {:ok, state} =
      Ingress.init(%{
        bot_token: "token",
        client: Fake,
        client_opts: [fake: fake],
        poll_enabled: false
      })

    log =
      ExUnit.CaptureLog.capture_log(fn ->
        {:noreply, state} =
          Ingress.handle_info(
            {:telegram_poll_result,
             {:error, {:failed, 409, "Conflict: terminated by other getUpdates request"}}},
            state
          )

        assert state.poll_failures == 1
      end)

    assert log =~ "telegram ingress poll error"
    assert log =~ "terminated by other getUpdates"
  end

  test "ingress poll emits command replies as sender messages", %{fake: fake} do
    {:ok, state} =
      Ingress.init(%{
        bot_token: "token",
        client: Fake,
        client_opts: [fake: fake],
        bot_username: "OurBot",
        poll_enabled: false
      })

    update = %{
      "update_id" => 30,
      "message" => %{"chat" => %{"id" => 123}, "text" => "/help"}
    }

    {:send_many, [{:send, :telegram_sender, payload}], state} =
      Ingress.handle_info({:telegram_poll_result, {:ok, [update], 31}}, state)

    decoded = Jason.decode!(payload)
    assert decoded["action"] == "send"
    assert decoded["conversation_id"] == "tg:123:0"
    assert state.poll_failures == 0
    assert Genswarms.Telegram.Store.File.read_offset(state.bot_ref) == 31
    assert Genswarms.Telegram.Store.File.update_seen?(state.bot_ref, 30)
    assert Fake.calls(fake) == []
  end

  test "default memory policy does not persist conversation memories", %{fake: fake} do
    parent = self()

    defmodule RuntimeForGroupMemoryPolicyTest do
      def ensure_session(cid, _opts), do: {:ok, %{slot: :telegram_agent_0, conversation_id: cid}}

      def deliver_to_session(session, text, opts) do
        send(opts.parent, {:group_delivered, session, text})
        :ok
      end
    end

    {:ok, state} =
      Ingress.init(%{
        bot_token: "token",
        client: Fake,
        client_opts: [fake: fake],
        session_runtime: RuntimeForGroupMemoryPolicyTest,
        session_opts: %{parent: parent},
        bot_username: "OurBot",
        poll_enabled: false
      })

    update = %{"update_id" => 40, "message" => %{"chat" => %{"id" => 100}, "text" => "hello"}}

    {:reply, body, state} =
      Ingress.handle_message(:test, %{"action" => "inject_update", "update" => update}, state)

    assert Jason.decode!(body)["routed"] == true
    assert_receive {:group_delivered, %{conversation_id: "tg:100:0"}, _text}

    refute File.exists?(
             Genswarms.Telegram.Context.MemoryMd.memory_path(state.bot_ref, "tg:100:0")
           )
  end

  test "dm-only memory policy opts into durable private chat memory", %{fake: fake} do
    parent = self()

    defmodule RuntimeForDmMemoryPolicyTest do
      def ensure_session(cid, _opts), do: {:ok, %{slot: :telegram_agent_0, conversation_id: cid}}

      def deliver_to_session(session, text, opts) do
        send(opts.parent, {:dm_delivered, session, text})
        :ok
      end
    end

    {:ok, state} =
      Ingress.init(%{
        bot_token: "token",
        client: Fake,
        client_opts: [fake: fake],
        session_runtime: RuntimeForDmMemoryPolicyTest,
        session_opts: %{parent: parent},
        memory_policy: :dm_only,
        poll_enabled: false
      })

    update = %{"update_id" => 41, "message" => %{"chat" => %{"id" => 101}, "text" => "hello"}}

    {:reply, body, state} =
      Ingress.handle_message(:test, %{"action" => "inject_update", "update" => update}, state)

    assert Jason.decode!(body)["routed"] == true
    assert_receive {:dm_delivered, %{conversation_id: "tg:101:0"}, _text}

    assert File.exists?(
             Genswarms.Telegram.Context.MemoryMd.memory_path(state.bot_ref, "tg:101:0")
           )
  end
end

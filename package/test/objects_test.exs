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

    {:noreply, _state} =
      Sender.handle_message(
        :internal,
        %{"action" => "progress", "conversation_id" => "tg:1:0", "text" => "step 2"},
        state
      )

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

  test "ingress sends command router replies through Telegram before acking", %{fake: fake} do
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

    assert {:reply, body, state} =
             Ingress.handle_message(
               :test,
               %{"action" => "inject_update", "update" => update},
               state
             )

    decoded = Jason.decode!(body)
    assert decoded["replied"] == true
    assert [%{conversation_id: "tg:123:0"}] = state.replies

    [call] = Fake.calls(fake)
    assert call.method == :send_message
    assert call.payload.chat_id == "123"
    assert call.payload.text =~ "route it to the swarm"
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

  test "ingress poll does not advance offset or dedupe failed command replies", %{fake: fake} do
    Fake.push_response(fake, {:error, {:transient, 500, "down"}})

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

    {:noreply, state} = Ingress.handle_info({:telegram_poll_result, {:ok, [update], 31}}, state)
    assert state.poll_failures == 1
    assert Genswarms.Telegram.Store.File.read_offset(state.bot_ref) == 0
    refute Genswarms.Telegram.Store.File.update_seen?(state.bot_ref, 30)
  end

  test "default memory policy does not persist group memories", %{fake: fake} do
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

    update = %{
      "update_id" => 40,
      "message" => %{"chat" => %{"id" => -100}, "text" => "@OurBot hello"}
    }

    {:reply, body, state} =
      Ingress.handle_message(:test, %{"action" => "inject_update", "update" => update}, state)

    assert Jason.decode!(body)["routed"] == true
    assert_receive {:group_delivered, %{conversation_id: "tg:-100:0"}, _text}

    refute File.exists?(
             Genswarms.Telegram.Context.MemoryMd.memory_path(state.bot_ref, "tg:-100:0")
           )
  end
end

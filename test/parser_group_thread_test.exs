defmodule Genswarms.Telegram.ParserGroupThreadTest do
  use ExUnit.Case, async: true

  alias Genswarms.Telegram.Parser

  # Telegram sets message_thread_id on ANY reply in a group — it's just the root
  # message id of the reply chain, not a real topic. Only messages flagged
  # is_topic_message (forum supergroups) name a genuine topic. Keying sessions
  # on the raw field fragments one group conversation into a session per reply
  # chain; these tests pin the contract: thread id counts ONLY for forum topics.

  defp group_message(extra) do
    %{
      "update_id" => 1,
      "message" =>
        Map.merge(
          %{
            "message_id" => 6001,
            "chat" => %{"id" => -1003762806404, "type" => "supergroup"},
            "from" => %{"id" => 5, "username" => "alice"},
            "text" => "hello"
          },
          extra
        )
    }
  end

  test "a reply chain in a regular group does NOT fork the conversation id" do
    update = group_message(%{"message_thread_id" => 5123})

    assert {:ok, event} = Parser.parse_update(update)
    assert event.conversation_id == "tg:-1003762806404:0"
    assert event.thread_id == "0"
  end

  test "a forum topic message keeps its topic as the conversation thread" do
    update = group_message(%{"message_thread_id" => 42, "is_topic_message" => true})

    assert {:ok, event} = Parser.parse_update(update)
    assert event.conversation_id == "tg:-1003762806404:42"
    assert event.thread_id == 42
  end

  test "a plain group message without threads is unchanged" do
    assert {:ok, event} = Parser.parse_update(group_message(%{}))
    assert event.conversation_id == "tg:-1003762806404:0"
  end

  test "a host synthetic batch preserves its original message ids" do
    update = Map.put(group_message(%{}), "pending_message_ids", [6000, 6001])

    assert {:ok, event} = Parser.parse_update(update)
    assert event.pending_message_ids == [6000, 6001]
  end

  test "callback queries follow the same rule: reply-chain collapses, topic sticks" do
    callback = fn message_extra ->
      %{
        "callback_query" => %{
          "id" => "cb1",
          "from" => %{"id" => 5},
          "data" => "x",
          "message" =>
            Map.merge(
              %{
                "message_id" => 10,
                "chat" => %{"id" => -1003762806404, "type" => "supergroup"}
              },
              message_extra
            )
        }
      }
    end

    assert {:ok, %{conversation_id: "tg:-1003762806404:0"}} =
             Parser.parse_update(callback.(%{"message_thread_id" => 5123}))

    assert {:ok, %{conversation_id: "tg:-1003762806404:42"}} =
             Parser.parse_update(
               callback.(%{"message_thread_id" => 42, "is_topic_message" => true})
             )
  end
end

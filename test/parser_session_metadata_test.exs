defmodule Genswarms.Telegram.ParserSessionMetadataTest do
  use ExUnit.Case, async: true
  alias Genswarms.Telegram.Parser

  defp update(fields) do
    %{
      "update_id" => 1,
      "message" =>
        Map.merge(
          %{
            "message_id" => 4,
            "chat" => %{"id" => -100, "type" => "supergroup"},
            "is_topic_message" => true,
            "message_thread_id" => 7,
            "from" => %{"id" => 42}
          },
          fields
        )
    }
  end

  test "voice preserves download metadata without treating audio as trusted text" do
    voice = %{
      "file_id" => "voice-file",
      "duration" => 9,
      "file_size" => 300,
      "unexpected" => "ignored"
    }

    assert {:ok, event} = Parser.parse_update(update(%{"voice" => voice}))
    assert event.type == :non_text
    assert event.conversation_id == "tg:-100:7"
    assert event.identity.user_id == 42
    assert event.voice == Map.delete(voice, "unexpected")
    assert event.text == ""
  end

  test "topic close and reopen remain non-text service events" do
    for {field, expected} <- [
          {"forum_topic_closed", :closed},
          {"forum_topic_reopened", :reopened}
        ] do
      assert {:ok, event} = Parser.parse_update(update(%{field => %{}}))
      assert event.topic_event == expected
      assert event.type == :non_text
      assert event.conversation_id == "tg:-100:7"
    end

    assert {:ok, event} = Parser.parse_update(update(%{"text" => "hello"}))
    refute Map.has_key?(event, :topic_event)
    refute Map.has_key?(event, :voice)
  end
end

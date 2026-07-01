defmodule Genswarms.Telegram.ParserDeliveryWebhookTest do
  use ExUnit.Case, async: true

  alias Genswarms.Telegram.{Delivery, Parser, Webhook}

  test "parser normalizes text and callback updates" do
    update = %{
      "update_id" => 1,
      "message" => %{
        "message_id" => 10,
        "chat" => %{"id" => 123, "type" => "private"},
        "from" => %{"id" => 5, "username" => "alice"},
        "text" => "hello"
      }
    }

    assert {:ok, event} = Parser.parse_update(update)
    assert event.type == :text
    assert event.conversation_id == "tg:123:0"
    assert event.chat_type == "private"
    assert event.identity.username == "alice"

    callback = %{
      "callback_query" => %{
        "id" => "cb1",
        "from" => %{"id" => 5},
        "data" => "x",
        "message" => %{"message_id" => 10, "chat" => %{"id" => 123, "type" => "private"}}
      }
    }

    assert {:ok, %{type: :callback, callback_query_id: "cb1", chat_type: "private"}} =
             Parser.parse_update(callback)

    assert :ignore = Parser.parse_update(%{"edited_message" => update["message"]})

    channel_post = %{
      "channel_post" => %{
        "chat" => %{"id" => -100, "type" => "supergroup"},
        "message_thread_id" => 4,
        "caption" => "captioned"
      }
    }

    assert {:ok,
            %{
              source: :channel_post,
              conversation_id: "tg:-100:4",
              text: "captioned",
              chat_type: "supergroup"
            }} =
             Parser.parse_update(channel_post)

    member = %{
      "my_chat_member" => %{
        "chat" => %{"id" => 123, "type" => "private"},
        "new_chat_member" => %{"status" => "kicked"}
      }
    }

    assert {:ok,
            %{type: :member, reachable?: false, conversation_id: "tg:123:0", chat_type: "private"}} =
             Parser.parse_update(member)
  end

  test "delivery builds payloads, validates buttons, and chunks by UTF-16 units" do
    payload =
      Delivery.build_send_message(%{
        conversation_id: "tg:-100:7",
        text: "**hi**",
        reply_to_message_id: 9,
        buttons: [%{text: "Open", url: "https://example.com"}]
      })

    assert payload.chat_id == "-100"
    assert payload.message_thread_id == 7
    assert payload.parse_mode == "HTML"
    assert payload.reply_parameters == %{message_id: 9, allow_sending_without_reply: true}
    assert payload.reply_markup.inline_keyboard == [[%{text: "Open", url: "https://example.com"}]]

    keyboard_payload =
      Delivery.build_send_message(%{
        conversation_id: "tg:123:0",
        text: "choose",
        reply_markup: %{
          keyboard: [
            [%{text: "Yes"}, %{text: "Location", request_location: true}],
            [%{text: "App", web_app: %{url: "https://example.com/app"}}]
          ],
          resize_keyboard: true,
          input_field_placeholder: "Choose"
        }
      })

    assert keyboard_payload.reply_markup == %{
             keyboard: [
               [%{text: "Yes"}, %{text: "Location", request_location: true}],
               [%{text: "App", web_app: %{url: "https://example.com/app"}}]
             ],
             resize_keyboard: true,
             input_field_placeholder: "Choose"
           }

    remove_payload =
      Delivery.build_send_message(%{
        conversation_id: "tg:123:0",
        text: "done",
        reply_markup: %{remove_keyboard: true}
      })

    assert remove_payload.reply_markup == %{remove_keyboard: true}

    force_payload =
      Delivery.build_send_message(%{
        conversation_id: "tg:123:0",
        text: "reply",
        reply_markup: %{force_reply: true, input_field_placeholder: "Reply"}
      })

    assert force_payload.reply_markup == %{force_reply: true, input_field_placeholder: "Reply"}

    invalid_reply =
      Delivery.build_send_message(%{
        conversation_id: "tg:123:0",
        text: "hi",
        reply_to_message_id: "9junk"
      })

    refute Map.has_key?(invalid_reply, :reply_parameters)

    assert_raise ArgumentError, fn ->
      Delivery.build_send_message(%{conversation_id: "tg:-100:-1", text: "bad topic"})
    end

    assert_raise ArgumentError, fn ->
      Delivery.reply_markup([%{text: "Bad", url: "javascript:alert(1)"}])
    end

    assert_raise ArgumentError, fn ->
      Delivery.reply_markup([%{text: "Too long", callback_data: String.duplicate("x", 65)}])
    end

    assert_raise ArgumentError, fn ->
      Delivery.reply_markup(%{
        keyboard: [[%{text: "Bad", web_app: %{url: "javascript:alert(1)"}}]]
      })
    end

    assert ["aa", "a"] = Delivery.chunk_text("aaa", 2)
    assert ["😀", "😀"] = Delivery.chunk_text("😀😀", 2)
    assert ["aaa\n", "bb"] = Delivery.chunk_text("aaa\nbb", 4)
    assert Delivery.chunk_text("\nleading", 4) |> Enum.join() == "\nleading"
    assert Delivery.chunk_text("trailing\n", 4) |> Enum.join() == "trailing\n"
  end

  test "webhook verifies Telegram secret and parses update" do
    update = %{"message" => %{"chat" => %{"id" => 1}, "text" => "hi"}}
    body = Jason.encode!(update)
    headers = [{"X-Telegram-Bot-Api-Secret-Token", "secret"}]
    assert {:ok, ^update} = Webhook.decode_update(body, headers, secret_token: "secret")
    assert {:ok, %{type: :text}} = Webhook.parse(body, headers, secret_token: "secret")
    assert {:error, :invalid_secret_token} = Webhook.parse(body, [], secret_token: "secret")
    assert :ok = Webhook.verify_secret(%{}, nil)
    assert :ok = Webhook.verify_secret(%{}, "")

    assert :ok =
             Webhook.verify_secret(
               %{"X-Telegram-Bot-Api-Secret-Token" => "secret"},
               "secret"
             )

    assert {:error, {:bad_json, %Jason.DecodeError{}}} =
             Webhook.decode_update("{bad", headers, secret_token: "secret")
  end
end

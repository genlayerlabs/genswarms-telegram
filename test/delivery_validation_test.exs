defmodule Genswarms.Telegram.DeliveryValidationTest do
  use ExUnit.Case

  alias Genswarms.Telegram.{Card, Delivery, RichMessage}

  test "reply keyboards enforce safe URLs and exactly one special button action" do
    assert Delivery.reply_markup(%{
             keyboard: [
               [
                 %{text: "Share phone", request_contact: true},
                 %{text: "Open app", web_app: %{url: "https://example.com/app"}}
               ]
             ],
             resize_keyboard: true
           }) == %{
             keyboard: [
               [
                 %{text: "Share phone", request_contact: true},
                 %{text: "Open app", web_app: %{url: "https://example.com/app"}}
               ]
             ],
             resize_keyboard: true
           }

    assert_raise ArgumentError, "unsafe keyboard web_app URL", fn ->
      Delivery.reply_markup(%{
        keyboard: [[%{text: "Bad", web_app: %{url: "javascript:alert(1)"}}]]
      })
    end

    assert_raise ArgumentError, "keyboard button can specify at most one action", fn ->
      Delivery.reply_markup(%{
        keyboard: [[%{text: "Ambiguous", request_contact: true, request_location: true}]]
      })
    end

    assert_raise ArgumentError, "invalid keyboard request_poll", fn ->
      Delivery.reply_markup(%{keyboard: [[%{text: "Poll", request_poll: "quiz"}]]})
    end
  end

  test "paid media, media groups, invoices, and reactions reject unsafe combinations early" do
    assert_raise ArgumentError, "media group must contain 2 to 10 items", fn ->
      Delivery.build_send_media_group(%{
        conversation_id: "tg:123:0",
        media: [%{type: "photo", media: "file-a"}]
      })
    end

    assert_raise ArgumentError, "audio media groups can contain only audio items", fn ->
      Delivery.build_send_media_group(%{
        conversation_id: "tg:123:0",
        media: [
          %{type: "audio", media: "file-a"},
          %{type: "photo", media: "file-b"}
        ]
      })
    end

    assert_raise ArgumentError, "paid media must contain 1 to 10 items", fn ->
      Delivery.build_send_paid_media(%{conversation_id: "tg:123:0", star_count: 1, media: []})
    end

    assert_raise ArgumentError, "Telegram Stars invoices require exactly one price", fn ->
      Delivery.build_send_invoice(%{
        conversation_id: "tg:123:0",
        title: "Access",
        description: "Premium access",
        payload: "invoice-1",
        currency: "XTR",
        prices: [%{label: "A", amount: 1}, %{label: "B", amount: 2}]
      })
    end

    assert_raise ArgumentError, "bots cannot set paid reactions", fn ->
      Delivery.build_set_message_reaction(%{
        conversation_id: "tg:123:0",
        message_id: 1,
        reaction: %{type: "paid"}
      })
    end
  end

  test "stories and cards fail closed when agents submit unsupported media or final-only blocks in drafts" do
    assert_raise ArgumentError, "story content type must be photo or video: \"animation\"", fn ->
      Delivery.build_post_story(%{
        business_connection_id: "biz-1",
        content: %{type: "animation", animation: "file-animation"},
        active_period: 86_400
      })
    end

    assert {:error,
            [
              %{
                path: "card.blocks[0]",
                reason: "thinking blocks are only allowed for streaming drafts"
              }
            ]} =
             Card.validate(%{"blocks" => [%{"kind" => "thinking", "text" => "Working"}]})

    assert :ok =
             Card.validate(
               %{"blocks" => [%{"kind" => "thinking", "text" => "Working"}]},
               %{draft?: true}
             )

    assert {:error, [%{path: "card.blocks[0].items"}]} =
             Card.validate(%{"blocks" => [%{"kind" => "list", "items" => "not-a-list"}]})
  end

  test "rich messages keep a strict single-format boundary with atom and string keys" do
    assert RichMessage.html("<p>ok</p>", is_rtl: true) == %{html: "<p>ok</p>", is_rtl: true}

    assert RichMessage.markdown("**ok**", skip_entity_detection: true) == %{
             markdown: "**ok**",
             skip_entity_detection: true
           }

    assert {:error, %{reason: "must contain exactly one of html or markdown"}} =
             RichMessage.validate(%{"html" => "<p>ok</p>", markdown: "**ok**"})

    assert {:error, %{reason: "must contain non-empty html or markdown"}} =
             RichMessage.validate(%{html: ""})
  end

  test "inline keyboards reject unsafe action payloads before Telegram sees them" do
    assert Delivery.reply_markup([]) == nil
    assert Delivery.reply_markup(%{inline_keyboard: [[%{text: "Open", url: "https://ok.test"}]]}) ==
             %{inline_keyboard: [[%{text: "Open", url: "https://ok.test"}]]}

    assert_raise ArgumentError, "invalid Telegram reply_markup: :bad", fn ->
      Delivery.reply_markup(:bad)
    end

    assert_raise ArgumentError, "inline_keyboard must contain at least one valid row", fn ->
      Delivery.reply_markup(%{inline_keyboard: []})
    end

    assert_raise ArgumentError, "unsafe web_app URL", fn ->
      Delivery.reply_markup([[%{text: "App", web_app: %{url: "javascript:alert(1)"}}]])
    end

    assert_raise ArgumentError, "switch_inline_query must be <= 256 bytes", fn ->
      Delivery.reply_markup([[%{text: "Search", switch_inline_query: String.duplicate("x", 257)}]])
    end

    assert_raise ArgumentError, "switch_inline_query_current_chat must be <= 256 bytes", fn ->
      Delivery.reply_markup([
        %{text: "Search here", switch_inline_query_current_chat: String.duplicate("x", 257)}
      ])
    end

    assert_raise ArgumentError, "switch_inline_query_chosen_chat query must be <= 256 bytes", fn ->
      Delivery.reply_markup([
        %{text: "Choose", switch_inline_query_chosen_chat: %{query: String.duplicate("x", 257)}}
      ])
    end

    assert_raise ArgumentError, "copy_text must be <= 256 bytes", fn ->
      Delivery.reply_markup([[%{text: "Copy", copy_text: %{text: String.duplicate("x", 257)}}]])
    end

    assert_raise ArgumentError, "invalid Telegram button: %{text: \"No action\"}", fn ->
      Delivery.reply_markup([[%{text: "No action"}]])
    end
  end

  test "reply keyboards reject malformed rows, buttons, styles, web apps, and placeholders" do
    assert Delivery.reply_markup(%{keyboard: [["Yes"]], input_field_placeholder: "Pick"}) == %{
             keyboard: [["Yes"]],
             input_field_placeholder: "Pick"
           }

    assert_raise ArgumentError, "invalid Telegram keyboard row: %{text: \"row\"}", fn ->
      Delivery.reply_markup(%{keyboard: [%{text: "row"}]})
    end

    assert_raise ArgumentError, "invalid Telegram keyboard button: 123", fn ->
      Delivery.reply_markup(%{keyboard: [[123]]})
    end

    assert_raise ArgumentError, "keyboard button style must be danger, success, or primary", fn ->
      Delivery.reply_markup(%{keyboard: [[%{text: "Run", style: "loud"}]]})
    end

    assert_raise ArgumentError, "invalid keyboard web_app", fn ->
      Delivery.reply_markup(%{keyboard: [[%{text: "App", web_app: %{href: "https://ok.test"}}]]})
    end

    assert_raise ArgumentError, "keyboard button text must be non-empty", fn ->
      Delivery.reply_markup(%{keyboard: [["   "]]})
    end

    assert_raise ArgumentError, "input_field_placeholder must be 1 to 64 characters", fn ->
      Delivery.reply_markup(%{
        keyboard: [["Yes"]],
        input_field_placeholder: String.duplicate("x", 65)
      })
    end

    assert_raise ArgumentError, "invalid input_field_placeholder", fn ->
      Delivery.reply_markup(%{force_reply: true, input_field_placeholder: 123})
    end
  end

  test "inline query and prepared keyboard helpers enforce exact agent-facing contracts" do
    valid_result = %{type: "article", id: "a1", title: "Title", input_message_content: %{}}

    assert Delivery.build_answer_inline_query(%{
             inline_query_id: "iq-1",
             results: [valid_result],
             button: %{text: "Open", web_app: "https://example.com/app"}
           }).button == %{text: "Open", web_app: %{url: "https://example.com/app"}}

    assert_raise ArgumentError, "inline query results must contain 1 to 50 results", fn ->
      Delivery.build_answer_inline_query(%{inline_query_id: "iq-1", results: []})
    end

    assert_raise ArgumentError, "inline query result requires non-empty type and id", fn ->
      Delivery.build_answer_inline_query(%{inline_query_id: "iq-1", results: [%{type: ""}]})
    end

    assert_raise ArgumentError, "inline query result must be an object", fn ->
      Delivery.build_answer_inline_query(%{inline_query_id: "iq-1", results: ["bad"]})
    end

    assert_raise ArgumentError, "inline query results button must use exactly one action", fn ->
      Delivery.build_answer_inline_query(%{
        inline_query_id: "iq-1",
        results: [valid_result],
        button: %{text: "Open", web_app: "https://example.com/app", start_parameter: "start"}
      })
    end

    assert_raise ArgumentError, "start_parameter must be 1 to 64 URL-safe characters", fn ->
      Delivery.build_answer_inline_query(%{
        inline_query_id: "iq-1",
        results: [valid_result],
        button: %{text: "Open", start_parameter: "bad space"}
      })
    end

    assert Delivery.build_save_prepared_keyboard_button(%{
             user_id: 123,
             button: %{text: "Choose user", request_users: %{request_id: 1}}
           }).button == %{text: "Choose user", request_users: %{request_id: 1}}

    assert_raise ArgumentError, "prepared keyboard button requires a request action", fn ->
      Delivery.build_save_prepared_keyboard_button(%{user_id: 123, button: %{text: "Choose"}})
    end

    assert_raise ArgumentError, "prepared keyboard button can specify only one request action", fn ->
      Delivery.build_save_prepared_keyboard_button(%{
        user_id: 123,
        button: %{
          text: "Choose",
          request_users: %{request_id: 1},
          request_chat: %{request_id: 2}
        }
      })
    end
  end

  test "bot command and profile builders validate admin metadata instead of passing garbage" do
    assert Delivery.build_set_my_commands(%{
             commands: [%{command: "help_1", description: "Show help"}],
             language_code: "en"
           }).commands == [%{command: "help_1", description: "Show help"}]

    assert_raise ArgumentError, "commands must contain 1 to 100 bot commands", fn ->
      Delivery.build_set_my_commands(%{commands: []})
    end

    assert_raise ArgumentError, "command must be 1 to 32 lowercase letters, digits, or underscores", fn ->
      Delivery.build_set_my_commands(%{commands: [%{command: "Bad", description: "bad"}]})
    end

    assert_raise ArgumentError, "bot command must be an object", fn ->
      Delivery.build_set_my_commands(%{commands: ["bad"]})
    end

    assert_raise ArgumentError, "language_code must be empty or a two-letter lowercase code", fn ->
      Delivery.build_get_my_commands(%{language_code: "EN"})
    end

    assert_raise ArgumentError, "scope must be an object", fn ->
      Delivery.build_delete_my_commands(%{scope: "private"})
    end
  end

  test "story, poll, and checklist builders fail closed on malformed structured content" do
    assert Delivery.build_post_story(%{
             business_connection_id: "biz-1",
             content: %{type: "video", video: "file-id", duration: "12.5"},
             active_period: 86_400,
             areas: []
           }).content.duration == 12.5

    assert_raise ArgumentError, "story content must be an object", fn ->
      Delivery.build_post_story(%{
        business_connection_id: "biz-1",
        content: "photo",
        active_period: 86_400
      })
    end

    assert_raise ArgumentError, "active_period must be 21600, 43200, 86400, or 172800", fn ->
      Delivery.build_post_story(%{
        business_connection_id: "biz-1",
        content: %{type: "photo", photo: "file-id"},
        active_period: 123
      })
    end

    assert_raise ArgumentError, "story areas must be a list", fn ->
      Delivery.build_edit_story(%{
        business_connection_id: "biz-1",
        story_id: 1,
        content: %{type: "photo", photo: "file-id"},
        areas: %{x: 1}
      })
    end

    assert_raise ArgumentError, "poll options must contain 1 to 12 options", fn ->
      Delivery.build_send_poll(%{conversation_id: "tg:123:0", question: "Q?", options: []})
    end

    assert_raise ArgumentError, "poll option text must be non-empty", fn ->
      Delivery.build_send_poll(%{
        conversation_id: "tg:123:0",
        question: "Q?",
        options: [%{text: "  "}]
      })
    end

    assert_raise ArgumentError, "invalid poll option: 42", fn ->
      Delivery.build_send_poll(%{conversation_id: "tg:123:0", question: "Q?", options: [42]})
    end

    assert_raise ArgumentError, "checklist must be an object: \"bad\"", fn ->
      Delivery.build_send_checklist(%{
        conversation_id: "tg:123:0",
        business_connection_id: "biz-1",
        checklist: "bad"
      })
    end

    assert_raise ArgumentError, "checklist task ids must be unique", fn ->
      Delivery.build_send_checklist(%{
        conversation_id: "tg:123:0",
        business_connection_id: "biz-1",
        checklist: %{title: "Todo", tasks: [%{id: 1, text: "A"}, %{id: 1, text: "B"}]}
      })
    end

    assert_raise ArgumentError, "parse_mode and title_entities cannot both be set", fn ->
      Delivery.build_send_checklist(%{
        conversation_id: "tg:123:0",
        business_connection_id: "biz-1",
        checklist: %{title: "Todo", tasks: ["A"], parse_mode: "HTML", title_entities: []}
      })
    end
  end

  test "payments, gifts, passport, and subscription helpers validate money-sensitive payloads" do
    invoice = %{
      conversation_id: "tg:123:0",
      title: "Access",
      description: "Premium access",
      payload: "invoice-1",
      currency: "usd",
      provider_token: "provider-token",
      prices: [%{label: "Access", amount: 100}]
    }

    assert Delivery.build_send_invoice(invoice).currency == "USD"

    assert_raise ArgumentError, "provider_token must be non-empty", fn ->
      Delivery.build_send_invoice(%{invoice | provider_token: "", currency: "USD"})
    end

    assert_raise ArgumentError, "currency must be a 3-letter code", fn ->
      Delivery.build_send_invoice(%{invoice | currency: "USDT"})
    end

    assert_raise ArgumentError, "suggested_tip_amounts must be strictly increasing", fn ->
      Delivery.build_send_invoice(Map.put(invoice, :suggested_tip_amounts, [100, 50]))
    end

    assert_raise ArgumentError, "subscription_period requires XTR currency", fn ->
      Delivery.build_create_invoice_link(%{
        title: "Access",
        description: "Premium access",
        payload: "invoice-1",
        currency: "USD",
        provider_token: "provider-token",
        prices: [%{label: "Access", amount: 100}],
        subscription_period: 2_592_000
      })
    end

    assert_raise ArgumentError, "shipping_options must contain at least one option", fn ->
      Delivery.build_answer_shipping_query(%{shipping_query_id: "ship-1", ok: true})
    end

    assert_raise ArgumentError, "send_gift requires exactly one of user_id or chat_id", fn ->
      Delivery.build_send_gift(%{gift_id: "gift-1", user_id: 1, chat_id: 2})
    end

    assert_raise ArgumentError, "accepted_gift_types must include at least one gift type", fn ->
      Delivery.build_set_business_account_gift_settings(%{
        business_connection_id: "biz-1",
        show_gift_button: true,
        accepted_gift_types: %{}
      })
    end

    assert_raise ArgumentError, "passport errors must contain at least one error", fn ->
      Delivery.build_set_passport_data_errors(%{user_id: 123, errors: []})
    end

    assert_raise ArgumentError, "passport error must be an object", fn ->
      Delivery.build_set_passport_data_errors(%{user_id: 123, errors: ["bad"]})
    end
  end

  test "message media, reactions, coordinates, and ids reject invalid Telegram shapes" do
    assert_raise ArgumentError, "invalid Telegram media_type: :video_note", fn ->
      Delivery.build_send_media(%{
        conversation_id: "tg:123:0",
        media_type: :video_note,
        media: "file-id"
      })
    end

    assert_raise ArgumentError,
                 "edit media requires type photo/video/animation/audio/document/live_photo and non-empty media",
                 fn ->
                   Delivery.build_edit_message_media(%{
                     conversation_id: "tg:123:0",
                     message_id: 1,
                     media: %{type: "sticker", media: "file-id"}
                   })
                 end

    assert_raise ArgumentError, "document media groups can contain only document items", fn ->
      Delivery.build_send_media_group(%{
        conversation_id: "tg:123:0",
        media: [
          %{type: "document", media: "doc-a"},
          %{type: "photo", media: "photo-b"}
        ]
      })
    end

    assert_raise ArgumentError, "message_ids must be sorted in strictly increasing order", fn ->
      Delivery.build_forward_messages(%{
        conversation_id: "tg:123:0",
        from_chat_id: 2,
        message_ids: [2, 1]
      })
    end

    assert_raise ArgumentError, "latitude must be a number", fn ->
      Delivery.build_send_location(%{
        conversation_id: "tg:123:0",
        latitude: "north",
        longitude: 2.0
      })
    end

    assert_raise ArgumentError, "invalid chat action: \"wave\"", fn ->
      Delivery.build_send_chat_action(%{conversation_id: "tg:123:0", action: "wave"})
    end

    assert_raise ArgumentError, "bots can set at most one reaction by default", fn ->
      Delivery.build_set_message_reaction(%{
        conversation_id: "tg:123:0",
        message_id: 1,
        reaction: ["👍", "🔥"]
      })
    end

    assert_raise ArgumentError, "reaction removal requires only one of user_id or actor_chat_id", fn ->
      Delivery.build_delete_message_reaction(%{
        chat_id: 1,
        message_id: 2,
        user_id: 3,
        actor_chat_id: 4
      })
    end

    assert_raise ArgumentError, "sticker_type must be regular, mask, or custom_emoji", fn ->
      Delivery.build_create_new_sticker_set(%{
        user_id: 1,
        name: "pack_by_bot",
        title: "Pack",
        stickers: [%{sticker: "file-id"}],
        sticker_type: "loud"
      })
    end
  end
end

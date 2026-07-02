defmodule Genswarms.Telegram.DeliveryBuilderContractTest do
  use ExUnit.Case

  alias Genswarms.Telegram.Delivery

  @common %{
    accepted_gift_types: %{unlimited_gifts: true},
    business_connection_id: "biz-1",
    chat_id: -100_123,
    chat_join_request_query_id: "join-query-1",
    conversation_id: "tg:123:0",
    custom_emoji_id: "emoji-1",
    custom_emoji_ids: ["emoji-1"],
    custom_title: "Lead",
    description: "Description",
    emoji_list: ["smile"],
    emoji_status_custom_emoji_id: "emoji-status-1",
    emoji_status_expiration_date: 1_800_000_000,
    errors: [%{source: "data", type: "personal_details", message: "bad data"}],
    file_id: "file-1",
    first_name: "Ada",
    format: "static",
    from_chat_id: -100_124,
    icon_color: 7_322_096,
    inline_message_id: "inline-1",
    invite_link: "https://t.me/+invite",
    is_canceled: true,
    keywords: ["ai"],
    mask_position: %{point: "forehead", x_shift: 0.0, y_shift: 0.0, scale: 1.0},
    media: "file-media",
    message_id: "5",
    message_ids: ["5", "6"],
    message_thread_id: "7",
    name: "example_by_bot",
    new_owner_chat_id: -100_126,
    old_sticker: "old-sticker",
    owned_gift_id: "owned-gift-1",
    permissions: %{can_send_messages: true},
    photo: "file-photo",
    position: 0,
    score: 10,
    sender_chat_id: -100_125,
    sticker: "file-sticker",
    sticker_format: "static",
    sticker_set_name: "example_by_bot",
    stickers: [%{sticker: "file-sticker", emoji_list: ["smile"], format: "static"}],
    subscription_period: 2_592_000,
    subscription_price: 100,
    tag: "vip",
    telegram_payment_charge_id: "charge-1",
    title: "Title",
    user_id: "123",
    result: "approve",
    username: "ada",
    web_app_url: "https://example.com/app"
  }

  test "no-argument builders produce explicit method payloads" do
    assert Delivery.build_get_my_star_balance() == %{_method: :get_my_star_balance}
    assert Delivery.build_get_available_gifts() == %{_method: :get_available_gifts}

    assert Delivery.build_get_forum_topic_icon_stickers() == %{
             _method: :get_forum_topic_icon_stickers
           }

    assert Delivery.build_remove_my_profile_photo() == %{_method: :remove_my_profile_photo}
    assert Delivery.build_delete_my_commands() == %{_method: :delete_my_commands}
  end

  test "business, gifts, payments, games, and utility builders normalize public API payloads" do
    assert_method(:build_get_star_transactions, %{offset: "0", limit: "50"})
    assert_method(:build_get_business_account_star_balance, @common)
    assert_method(:build_transfer_business_account_stars, Map.put(@common, :star_count, "10"))
    assert_method(:build_get_business_account_gifts, Map.put(@common, :limit, "10"))
    assert_method(:build_get_user_gifts, Map.put(@common, :limit, "10"))
    assert_method(:build_get_chat_gifts, Map.put(@common, :limit, "10"))
    assert_method(:build_convert_gift_to_stars, @common)
    assert_method(:build_upgrade_gift, Map.put(@common, :star_count, "0"))
    assert_method(:build_transfer_gift, Map.put(@common, :star_count, "1"))

    send_gift =
      assert_method(:build_send_gift, %{gift_id: "gift-1", user_id: "123", text: "thanks"})

    assert send_gift.user_id == 123
    refute Map.has_key?(send_gift, :chat_id)

    assert_method(:build_gift_premium_subscription, %{
      user_id: "123",
      month_count: "3",
      star_count: "1000"
    })

    assert_method(:build_verify_user, @common)
    assert_method(:build_verify_chat, @common)
    assert_method(:build_remove_user_verification, @common)
    assert_method(:build_remove_chat_verification, @common)
    assert_method(:build_read_business_message, @common)
    assert_method(:build_delete_business_messages, @common)
    assert_method(:build_set_business_account_name, Map.put(@common, :last_name, "Lovelace"))
    assert_method(:build_set_business_account_username, @common)
    assert_method(:build_set_business_account_bio, @common)

    assert_method(:build_set_business_account_profile_photo, %{
      @common
      | photo: %{type: "static", photo: "file-photo"}
    })

    assert_method(:build_remove_business_account_profile_photo, @common)

    assert_method(
      :build_set_business_account_gift_settings,
      Map.put(@common, :show_gift_button, "true")
    )

    assert_method(:build_approve_suggested_post, @common)
    assert_method(:build_decline_suggested_post, Map.put(@common, :comment, "not now"))
    assert_method(:build_set_passport_data_errors, @common)
    assert_method(:build_set_game_score, @common)
    assert_method(:build_get_game_high_scores, @common)
    assert_method(:build_refund_star_payment, @common)
    assert_method(:build_edit_user_star_subscription, @common)
    assert_method(:build_get_user_profile_photos, Map.merge(@common, %{offset: "0", limit: "2"}))
    assert_method(:build_get_user_profile_audios, Map.merge(@common, %{offset: "0", limit: "2"}))
    assert_method(:build_set_user_emoji_status, @common)
    assert_method(:build_get_file, @common)
  end

  test "chat administration, forum, and invite builders keep required ids typed" do
    for fun <- [
          :build_ban_chat_member,
          :build_unban_chat_member,
          :build_restrict_chat_member,
          :build_promote_chat_member,
          :build_set_chat_administrator_custom_title,
          :build_set_chat_member_tag,
          :build_ban_chat_sender_chat,
          :build_unban_chat_sender_chat,
          :build_set_chat_permissions,
          :build_export_chat_invite_link,
          :build_create_chat_invite_link,
          :build_edit_chat_invite_link,
          :build_create_chat_subscription_invite_link,
          :build_edit_chat_subscription_invite_link,
          :build_revoke_chat_invite_link,
          :build_approve_chat_join_request,
          :build_decline_chat_join_request,
          :build_answer_chat_join_request_query,
          :build_send_chat_join_request_web_app,
          :build_set_chat_photo,
          :build_delete_chat_photo,
          :build_set_chat_title,
          :build_set_chat_description,
          :build_pin_chat_message,
          :build_unpin_chat_message,
          :build_unpin_all_chat_messages,
          :build_leave_chat,
          :build_get_chat,
          :build_get_chat_administrators,
          :build_get_chat_member_count,
          :build_get_chat_member,
          :build_set_chat_sticker_set,
          :build_delete_chat_sticker_set,
          :build_create_forum_topic,
          :build_edit_forum_topic,
          :build_close_forum_topic,
          :build_reopen_forum_topic,
          :build_delete_forum_topic,
          :build_unpin_all_forum_topic_messages,
          :build_edit_general_forum_topic,
          :build_close_general_forum_topic,
          :build_reopen_general_forum_topic,
          :build_hide_general_forum_topic,
          :build_unhide_general_forum_topic,
          :build_unpin_all_general_forum_topic_messages,
          :build_delete_message_reaction,
          :build_delete_all_message_reactions
        ] do
      payload = assert_method(fun, @common)
      assert payload._method == expected_method(fun)
    end
  end

  test "sticker builders normalize collection names, uploaded files, and list fields" do
    for fun <- [
          :build_get_sticker_set,
          :build_get_custom_emoji_stickers,
          :build_upload_sticker_file,
          :build_create_new_sticker_set,
          :build_add_sticker_to_set,
          :build_set_sticker_position_in_set,
          :build_delete_sticker_from_set,
          :build_replace_sticker_in_set,
          :build_set_sticker_emoji_list,
          :build_set_sticker_keywords,
          :build_set_sticker_mask_position,
          :build_set_sticker_set_title,
          :build_set_sticker_set_thumbnail,
          :build_set_custom_emoji_sticker_set_thumbnail,
          :build_delete_sticker_set
        ] do
      payload = assert_method(fun, @common)
      assert payload._method == expected_method(fun)
    end
  end

  test "stories, query answers, message movement, and payments have representative builders" do
    inline_result = %{
      type: "article",
      id: "result-1",
      title: "Status",
      input_message_content: %{message_text: "Ready"}
    }

    assert_method(:build_answer_callback_query, %{callback_query_id: "cb-1", text: "Done"})

    assert_method(:build_answer_web_app_query, %{web_app_query_id: "web-1", result: inline_result})

    assert_method(:build_answer_guest_query, %{guest_query_id: "guest-1", result: inline_result})

    assert_method(:build_answer_inline_query, %{
      inline_query_id: "inline-1",
      results: [inline_result]
    })

    assert_method(:build_save_prepared_inline_message, %{
      user_id: "123",
      result: inline_result,
      allow_user_chats: true
    })

    assert_method(:build_save_prepared_keyboard_button, %{
      user_id: "123",
      button: %{text: "Pick user", request_users: %{request_id: 1}}
    })

    assert_method(:build_answer_shipping_query, %{
      shipping_query_id: "ship-1",
      ok: "false",
      error_message: "No shipping"
    })

    assert_method(:build_answer_pre_checkout_query, %{
      pre_checkout_query_id: "pre-1",
      ok: "false",
      error_message: "No payment"
    })

    assert_method(:build_post_story, %{
      business_connection_id: "biz-1",
      content: %{type: "photo", photo: "file-photo"},
      active_period: 86_400
    })

    assert_method(:build_repost_story, %{
      business_connection_id: "biz-1",
      from_chat_id: -100_124,
      from_story_id: "9",
      active_period: 43_200
    })

    assert_method(:build_edit_story, %{
      business_connection_id: "biz-1",
      story_id: "10",
      content: %{type: "video", video: "file-video"}
    })

    assert_method(:build_delete_story, %{business_connection_id: "biz-1", story_id: "10"})

    assert_method(:build_create_invoice_link, %{
      title: "Access",
      description: "Premium access",
      payload: "invoice-1",
      currency: "USD",
      provider_token: "provider",
      prices: [%{label: "Access", amount: 100}]
    })

    for fun <- [
          :build_forward_message,
          :build_forward_messages,
          :build_copy_message,
          :build_copy_messages,
          :build_delete_message,
          :build_delete_messages
        ] do
      assert_method(fun, @common)
    end
  end

  defp assert_method(fun, attrs) do
    payload = apply(Delivery, fun, [attrs_for(fun, attrs)])
    assert payload._method == expected_method(fun)
    payload
  end

  defp attrs_for(fun, attrs)
       when fun in [:build_add_sticker_to_set, :build_replace_sticker_in_set],
       do:
         Map.put(attrs, :sticker, %{
           sticker: "file-sticker",
           emoji_list: ["smile"],
           format: "static"
         })

  defp attrs_for(fun, attrs) when fun in [:build_set_game_score, :build_get_game_high_scores],
    do: Map.delete(attrs, :inline_message_id)

  defp attrs_for(_fun, attrs), do: attrs

  defp expected_method(:build_edit_live_location), do: :edit_message_live_location
  defp expected_method(:build_stop_live_location), do: :stop_message_live_location

  defp expected_method(fun) do
    fun
    |> Atom.to_string()
    |> String.replace_prefix("build_", "")
    |> String.to_atom()
  end
end

# Example agent-facing payloads for Genswarms.Telegram.Objects.Sender.
#
# These are plain maps that can be JSON-encoded and delivered to the sender
# object. Replace the conversation_id with the target conversation, or omit it
# when sending from a bound agent slot.

conversation_id = "tg:123:0"

[
  %{
    action: "stream_text",
    conversation_id: conversation_id,
    draft_id: 101,
    text: "Checking current state..."
  },
  %{
    action: "answer_callback",
    callback_query_id: "cb_123",
    text: "Done"
  },
  %{
    action: "answer_inline_query",
    inline_query_id: "inline_123",
    results: [
      %{
        type: "article",
        id: "status",
        title: "Status",
        input_message_content: %{message_text: "Ready"}
      }
    ],
    is_personal: true
  },
  %{
    action: "answer_web_app",
    web_app_query_id: "web_123",
    result: %{
      type: "article",
      id: "web-status",
      title: "Status",
      input_message_content: %{message_text: "Ready"}
    }
  },
  %{
    action: "answer_guest_query",
    guest_query_id: "guest_123",
    result: %{
      type: "article",
      id: "guest-status",
      title: "Status",
      input_message_content: %{message_text: "Ready"}
    }
  },
  %{
    action: "save_prepared_inline_message",
    user_id: 123,
    result: %{
      type: "article",
      id: "prepared-status",
      title: "Status",
      input_message_content: %{message_text: "Ready"}
    },
    allow_user_chats: true
  },
  %{
    action: "get_user_chat_boosts",
    chat_id: "@channel",
    user_id: 123
  },
  %{
    action: "get_business_connection",
    business_connection_id: "biz_123"
  },
  %{
    action: "get_managed_bot_token",
    user_id: 123
  },
  %{
    action: "replace_managed_bot_token",
    user_id: 123
  },
  %{
    action: "get_managed_bot_access_settings",
    user_id: 123
  },
  %{
    action: "set_managed_bot_access_settings",
    user_id: 123,
    is_access_restricted: true,
    added_user_ids: [456]
  },
  %{
    action: "get_user_personal_chat_messages",
    user_id: 123,
    limit: 5
  },
  %{
    action: "set_my_commands",
    commands: [%{command: "start", description: "Start the bot"}],
    language_code: "en"
  },
  %{
    action: "delete_my_commands",
    language_code: "en"
  },
  %{
    action: "get_my_commands",
    scope: %{type: "default"}
  },
  %{
    action: "set_my_name",
    name: "Wingston"
  },
  %{
    action: "get_my_name",
    language_code: "en"
  },
  %{
    action: "set_my_description",
    description: "Rally assistant"
  },
  %{
    action: "get_my_description"
  },
  %{
    action: "set_my_short_description",
    short_description: "Rally assistant"
  },
  %{
    action: "get_my_short_description"
  },
  %{
    action: "set_my_profile_photo",
    photo: %{type: "static", photo: "attach://profile"}
  },
  %{
    action: "remove_my_profile_photo"
  },
  %{
    action: "set_chat_menu_button",
    chat_id: 123,
    menu_button: %{type: "commands"}
  },
  %{
    action: "get_chat_menu_button",
    chat_id: 123
  },
  %{
    action: "set_my_default_administrator_rights",
    rights: %{can_delete_messages: true},
    for_channels: true
  },
  %{
    action: "get_my_default_administrator_rights",
    for_channels: false
  },
  %{
    action: "post_story",
    business_connection_id: "biz_123",
    content: %{type: "photo", photo: "attach://story-photo"},
    active_period: 86_400,
    caption: "Launch"
  },
  %{
    action: "edit_story",
    business_connection_id: "biz_123",
    story_id: 13,
    content: %{type: "video", video: "attach://story-video"}
  },
  %{
    action: "send_card",
    conversation_id: conversation_id,
    card: %{
      title: "Status",
      blocks: [
        %{
          kind: "paragraph",
          text: [
            "System is ",
            %{kind: "bold", text: "ready"},
            "."
          ]
        },
        %{
          kind: "table",
          bordered: true,
          headers: ["metric", "value"],
          rows: [
            ["queue", "empty"],
            ["state", %{kind: "code", text: "ok"}]
          ]
        },
        %{
          kind: "details",
          summary: "Next steps",
          blocks: [
            %{kind: "checklist", items: [%{text: "send final reply", checked: true}]}
          ]
        }
      ],
      buttons: [
        [%{text: "Open", url: "https://example.com/"}],
        [%{text: "Copy ID", copy_text: %{text: conversation_id}}]
      ]
    }
  },
  %{
    action: "stream_card",
    conversation_id: conversation_id,
    draft_id: 102,
    card: %{
      blocks: [
        %{kind: "thinking", text: "Composing rich answer..."}
      ]
    }
  },
  %{
    action: "send_media_group",
    conversation_id: conversation_id,
    media: [
      %{type: "photo", media: "https://example.com/one.jpg"},
      %{type: "photo", media: "https://example.com/two.jpg", caption: "Second image"}
    ]
  },
  %{
    action: "send_paid_media",
    conversation_id: conversation_id,
    star_count: 5,
    media: [%{type: "photo", media: "file-paid-photo-id"}],
    payload: "premium-drop-1"
  },
  %{
    action: "send_sticker",
    conversation_id: conversation_id,
    sticker: "file-sticker-id",
    emoji: "👍"
  },
  %{
    action: "send_poll",
    conversation_id: conversation_id,
    question: "Pick one",
    options: ["A", "B"],
    is_anonymous: false
  },
  %{
    action: "send_checklist",
    conversation_id: conversation_id,
    business_connection_id: "biz_123",
    title: "Launch",
    tasks: ["Draft", %{id: 4, text: "Review"}]
  },
  %{
    action: "edit_checklist",
    conversation_id: conversation_id,
    message_id: 122,
    business_connection_id: "biz_123",
    title: "Updated launch",
    tasks: ["Ship"]
  },
  %{
    action: "send_invoice",
    conversation_id: conversation_id,
    title: "Access",
    description: "Premium media access",
    payload: "invoice-1",
    currency: "XTR",
    prices: [%{label: "Access", amount: 25}],
    buttons: [[%{text: "Pay", pay: true}]]
  },
  %{
    action: "create_invoice_link",
    title: "Access",
    description: "Premium media access",
    payload: "invoice-link-1",
    currency: "XTR",
    prices: [%{label: "Access", amount: 25}]
  },
  %{
    action: "answer_pre_checkout_query",
    pre_checkout_query_id: "pre_123",
    ok: true
  },
  %{
    action: "get_my_star_balance"
  },
  %{
    action: "get_star_transactions",
    offset: 0,
    limit: 25
  },
  %{
    action: "get_available_gifts"
  },
  %{
    action: "send_gift",
    user_id: 123,
    gift_id: "gift_123",
    text: "Enjoy",
    pay_for_upgrade: true
  },
  %{
    action: "gift_premium_subscription",
    user_id: 123,
    month_count: 3,
    star_count: 1000
  },
  %{
    action: "get_business_account_star_balance",
    business_connection_id: "biz_123"
  },
  %{
    action: "transfer_business_account_stars",
    business_connection_id: "biz_123",
    star_count: 100
  },
  %{
    action: "get_business_account_gifts",
    business_connection_id: "biz_123",
    exclude_unsaved: true,
    sort_by_price: true,
    limit: 50
  },
  %{
    action: "get_user_gifts",
    user_id: 123,
    exclude_unique: true
  },
  %{
    action: "get_chat_gifts",
    chat_id: "@channel",
    sort_by_price: true
  },
  %{
    action: "convert_gift_to_stars",
    business_connection_id: "biz_123",
    owned_gift_id: "owned_gift_123"
  },
  %{
    action: "upgrade_gift",
    business_connection_id: "biz_123",
    owned_gift_id: "owned_gift_123",
    star_count: 0
  },
  %{
    action: "transfer_gift",
    business_connection_id: "biz_123",
    owned_gift_id: "owned_gift_123",
    new_owner_chat_id: 123,
    star_count: 0
  },
  %{
    action: "verify_user",
    user_id: 123,
    custom_description: "Official"
  },
  %{
    action: "verify_chat",
    chat_id: "@channel"
  },
  %{
    action: "remove_user_verification",
    user_id: 123
  },
  %{
    action: "remove_chat_verification",
    chat_id: "@channel"
  },
  %{
    action: "read_business_message",
    business_connection_id: "biz_123",
    chat_id: 123,
    message_id: 456
  },
  %{
    action: "delete_business_messages",
    business_connection_id: "biz_123",
    message_ids: [456, 457]
  },
  %{
    action: "set_business_account_name",
    business_connection_id: "biz_123",
    first_name: "Wingston",
    last_name: ""
  },
  %{
    action: "set_business_account_username",
    business_connection_id: "biz_123",
    username: "wingston"
  },
  %{
    action: "set_business_account_bio",
    business_connection_id: "biz_123",
    bio: "Rally assistant"
  },
  %{
    action: "set_business_account_profile_photo",
    business_connection_id: "biz_123",
    photo: %{type: "static", photo: "attach://profile-photo"}
  },
  %{
    action: "remove_business_account_profile_photo",
    business_connection_id: "biz_123",
    is_public: false
  },
  %{
    action: "set_business_account_gift_settings",
    business_connection_id: "biz_123",
    show_gift_button: true,
    accepted_gift_types: %{
      unlimited_gifts: true,
      limited_gifts: false,
      unique_gifts: true,
      premium_subscription: false
    }
  },
  %{
    action: "approve_suggested_post",
    chat_id: 123,
    message_id: 456
  },
  %{
    action: "decline_suggested_post",
    chat_id: 123,
    message_id: 456,
    comment: "Needs changes"
  },
  %{
    action: "set_passport_data_errors",
    user_id: 123,
    errors: [
      %{
        source: "data",
        type: "personal_details",
        field_name: "first_name",
        data_hash: "hash",
        message: "Invalid first name"
      }
    ]
  },
  %{
    action: "set_game_score",
    user_id: 123,
    score: 42,
    chat_id: "@gamechat",
    message_id: 456
  },
  %{
    action: "get_game_high_scores",
    user_id: 123,
    inline_message_id: "inline-game"
  },
  %{
    action: "send_game",
    conversation_id: conversation_id,
    game_short_name: "rally_quest"
  },
  %{
    action: "edit_message",
    conversation_id: conversation_id,
    message_id: 123,
    text: "Updated status",
    buttons: [[%{text: "Open", url: "https://example.com/"}]]
  },
  %{
    action: "edit_reply_markup",
    conversation_id: conversation_id,
    message_id: 123,
    buttons: [[%{text: "Done", callback_data: "done"}]]
  },
  %{
    action: "stop_poll",
    conversation_id: conversation_id,
    message_id: 124,
    buttons: [[%{text: "Closed", callback_data: "poll_closed"}]]
  },
  %{
    action: "edit_media",
    conversation_id: conversation_id,
    message_id: 125,
    media_type: "photo",
    media: "file-photo-id"
  },
  %{
    action: "edit_live_location",
    conversation_id: conversation_id,
    message_id: 126,
    latitude: 41.3874,
    longitude: 2.1686
  },
  %{
    action: "copy_message",
    conversation_id: conversation_id,
    from_chat_id: "@source",
    message_id: 200
  },
  %{
    action: "forward_messages",
    conversation_id: conversation_id,
    from_chat_id: "@source",
    message_ids: [201, 202]
  },
  %{
    action: "delete_messages",
    conversation_id: conversation_id,
    message_ids: [203, 204]
  },
  %{
    action: "ban_chat_member",
    chat_id: -100_123,
    user_id: 42,
    revoke_messages: true
  },
  %{
    action: "create_chat_invite_link",
    chat_id: -100_123,
    name: "Support",
    creates_join_request: true
  },
  %{
    action: "answer_chat_join_request_query",
    query_id: "join_123",
    result: "queue"
  },
  %{
    action: "delete_all_message_reactions",
    chat_id: -100_123,
    actor_chat_id: -100_456
  },
  %{
    action: "create_forum_topic",
    chat_id: -100_123,
    name: "Support",
    icon_color: 7_322_096
  },
  %{
    action: "get_file",
    file_id: "file-123"
  },
  %{
    action: "get_custom_emoji_stickers",
    custom_emoji_ids: ["emoji-1"]
  },
  %{
    action: "create_new_sticker_set",
    user_id: 42,
    name: "wingston_by_bot",
    title: "Wingston",
    stickers: [%{sticker: "attach://sticker", emoji_list: ["🪽"], format: "static"}],
    sticker_type: "regular"
  },
  %{
    action: "send",
    conversation_id: conversation_id,
    text: "Choose an option",
    reply_markup: %{
      keyboard: [
        ["Yes", "No"],
        [%{text: "Open app", web_app: %{url: "https://example.com/app"}}]
      ],
      resize_keyboard: true,
      one_time_keyboard: true
    }
  },
  %{
    action: "send_chat_action",
    conversation_id: conversation_id,
    chat_action: "upload_photo"
  },
  %{
    action: "set_reaction",
    conversation_id: conversation_id,
    message_id: 123,
    reaction: "👍"
  }
]

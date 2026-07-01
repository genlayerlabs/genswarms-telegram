defmodule Genswarms.Telegram.RichCardSenderTest do
  use ExUnit.Case

  alias Genswarms.Telegram.Client
  alias Genswarms.Telegram.Client.Fake
  alias Genswarms.Telegram.{Actions, Capabilities, Card, Delivery, RichMessage}
  alias Genswarms.Telegram.Objects.Sender

  test "client exposes rich/media/poll method names" do
    assert Client.method_name(:logout) == "logOut"
    assert Client.method_name(:close) == "close"
    assert Client.method_name(:answer_callback_query) == "answerCallbackQuery"
    assert Client.method_name(:answer_web_app_query) == "answerWebAppQuery"
    assert Client.method_name(:answer_inline_query) == "answerInlineQuery"
    assert Client.method_name(:answer_guest_query) == "answerGuestQuery"
    assert Client.method_name(:save_prepared_inline_message) == "savePreparedInlineMessage"
    assert Client.method_name(:save_prepared_keyboard_button) == "savePreparedKeyboardButton"
    assert Client.method_name(:get_user_chat_boosts) == "getUserChatBoosts"
    assert Client.method_name(:get_business_connection) == "getBusinessConnection"
    assert Client.method_name(:get_managed_bot_token) == "getManagedBotToken"
    assert Client.method_name(:replace_managed_bot_token) == "replaceManagedBotToken"

    assert Client.method_name(:get_managed_bot_access_settings) ==
             "getManagedBotAccessSettings"

    assert Client.method_name(:set_managed_bot_access_settings) ==
             "setManagedBotAccessSettings"

    assert Client.method_name(:get_user_personal_chat_messages) ==
             "getUserPersonalChatMessages"

    assert Client.method_name(:set_my_commands) == "setMyCommands"
    assert Client.method_name(:delete_my_commands) == "deleteMyCommands"
    assert Client.method_name(:get_my_commands) == "getMyCommands"
    assert Client.method_name(:set_my_name) == "setMyName"
    assert Client.method_name(:get_my_name) == "getMyName"
    assert Client.method_name(:set_my_description) == "setMyDescription"
    assert Client.method_name(:get_my_description) == "getMyDescription"
    assert Client.method_name(:set_my_short_description) == "setMyShortDescription"
    assert Client.method_name(:get_my_short_description) == "getMyShortDescription"
    assert Client.method_name(:set_my_profile_photo) == "setMyProfilePhoto"
    assert Client.method_name(:remove_my_profile_photo) == "removeMyProfilePhoto"
    assert Client.method_name(:set_chat_menu_button) == "setChatMenuButton"
    assert Client.method_name(:get_chat_menu_button) == "getChatMenuButton"

    assert Client.method_name(:set_my_default_administrator_rights) ==
             "setMyDefaultAdministratorRights"

    assert Client.method_name(:get_my_default_administrator_rights) ==
             "getMyDefaultAdministratorRights"

    assert Client.method_name(:create_invoice_link) == "createInvoiceLink"
    assert Client.method_name(:answer_shipping_query) == "answerShippingQuery"
    assert Client.method_name(:answer_pre_checkout_query) == "answerPreCheckoutQuery"
    assert Client.method_name(:get_my_star_balance) == "getMyStarBalance"
    assert Client.method_name(:get_star_transactions) == "getStarTransactions"
    assert Client.method_name(:get_available_gifts) == "getAvailableGifts"
    assert Client.method_name(:send_gift) == "sendGift"
    assert Client.method_name(:gift_premium_subscription) == "giftPremiumSubscription"

    assert Client.method_name(:get_business_account_star_balance) ==
             "getBusinessAccountStarBalance"

    assert Client.method_name(:transfer_business_account_stars) ==
             "transferBusinessAccountStars"

    assert Client.method_name(:get_business_account_gifts) == "getBusinessAccountGifts"
    assert Client.method_name(:get_user_gifts) == "getUserGifts"
    assert Client.method_name(:get_chat_gifts) == "getChatGifts"
    assert Client.method_name(:convert_gift_to_stars) == "convertGiftToStars"
    assert Client.method_name(:upgrade_gift) == "upgradeGift"
    assert Client.method_name(:transfer_gift) == "transferGift"
    assert Client.method_name(:verify_user) == "verifyUser"
    assert Client.method_name(:verify_chat) == "verifyChat"
    assert Client.method_name(:remove_user_verification) == "removeUserVerification"
    assert Client.method_name(:remove_chat_verification) == "removeChatVerification"
    assert Client.method_name(:read_business_message) == "readBusinessMessage"
    assert Client.method_name(:delete_business_messages) == "deleteBusinessMessages"
    assert Client.method_name(:set_business_account_name) == "setBusinessAccountName"
    assert Client.method_name(:set_business_account_username) == "setBusinessAccountUsername"
    assert Client.method_name(:set_business_account_bio) == "setBusinessAccountBio"

    assert Client.method_name(:set_business_account_profile_photo) ==
             "setBusinessAccountProfilePhoto"

    assert Client.method_name(:remove_business_account_profile_photo) ==
             "removeBusinessAccountProfilePhoto"

    assert Client.method_name(:set_business_account_gift_settings) ==
             "setBusinessAccountGiftSettings"

    assert Client.method_name(:approve_suggested_post) == "approveSuggestedPost"
    assert Client.method_name(:decline_suggested_post) == "declineSuggestedPost"
    assert Client.method_name(:set_passport_data_errors) == "setPassportDataErrors"
    assert Client.method_name(:set_game_score) == "setGameScore"
    assert Client.method_name(:get_game_high_scores) == "getGameHighScores"
    assert Client.method_name(:refund_star_payment) == "refundStarPayment"
    assert Client.method_name(:edit_user_star_subscription) == "editUserStarSubscription"
    assert Client.method_name(:post_story) == "postStory"
    assert Client.method_name(:repost_story) == "repostStory"
    assert Client.method_name(:edit_story) == "editStory"
    assert Client.method_name(:delete_story) == "deleteStory"
    assert Client.method_name(:send_message_draft) == "sendMessageDraft"
    assert Client.method_name(:send_rich_message) == "sendRichMessage"
    assert Client.method_name(:send_rich_message_draft) == "sendRichMessageDraft"
    assert Client.method_name(:send_live_photo) == "sendLivePhoto"
    assert Client.method_name(:send_animation) == "sendAnimation"
    assert Client.method_name(:send_video) == "sendVideo"
    assert Client.method_name(:send_audio) == "sendAudio"
    assert Client.method_name(:send_voice) == "sendVoice"
    assert Client.method_name(:send_video_note) == "sendVideoNote"
    assert Client.method_name(:send_document) == "sendDocument"
    assert Client.method_name(:send_sticker) == "sendSticker"
    assert Client.method_name(:send_media_group) == "sendMediaGroup"
    assert Client.method_name(:send_paid_media) == "sendPaidMedia"
    assert Client.method_name(:send_poll) == "sendPoll"
    assert Client.method_name(:send_checklist) == "sendChecklist"
    assert Client.method_name(:send_location) == "sendLocation"
    assert Client.method_name(:send_venue) == "sendVenue"
    assert Client.method_name(:send_contact) == "sendContact"
    assert Client.method_name(:send_dice) == "sendDice"
    assert Client.method_name(:send_invoice) == "sendInvoice"
    assert Client.method_name(:send_game) == "sendGame"
    assert Client.method_name(:send_chat_action) == "sendChatAction"
    assert Client.method_name(:set_message_reaction) == "setMessageReaction"
    assert Client.method_name(:get_user_profile_photos) == "getUserProfilePhotos"
    assert Client.method_name(:get_user_profile_audios) == "getUserProfileAudios"
    assert Client.method_name(:set_user_emoji_status) == "setUserEmojiStatus"
    assert Client.method_name(:get_file) == "getFile"
    assert Client.method_name(:forward_message) == "forwardMessage"
    assert Client.method_name(:forward_messages) == "forwardMessages"
    assert Client.method_name(:copy_message) == "copyMessage"
    assert Client.method_name(:copy_messages) == "copyMessages"
    assert Client.method_name(:delete_message) == "deleteMessage"
    assert Client.method_name(:delete_messages) == "deleteMessages"
    assert Client.method_name(:delete_message_reaction) == "deleteMessageReaction"
    assert Client.method_name(:delete_all_message_reactions) == "deleteAllMessageReactions"
    assert Client.method_name(:ban_chat_member) == "banChatMember"
    assert Client.method_name(:restrict_chat_member) == "restrictChatMember"
    assert Client.method_name(:create_chat_invite_link) == "createChatInviteLink"
    assert Client.method_name(:answer_chat_join_request_query) == "answerChatJoinRequestQuery"
    assert Client.method_name(:send_chat_join_request_web_app) == "sendChatJoinRequestWebApp"
    assert Client.method_name(:pin_chat_message) == "pinChatMessage"
    assert Client.method_name(:get_chat_administrators) == "getChatAdministrators"
    assert Client.method_name(:get_forum_topic_icon_stickers) == "getForumTopicIconStickers"
    assert Client.method_name(:create_forum_topic) == "createForumTopic"

    assert Client.method_name(:unpin_all_general_forum_topic_messages) ==
             "unpinAllGeneralForumTopicMessages"

    assert Client.method_name(:get_sticker_set) == "getStickerSet"
    assert Client.method_name(:get_custom_emoji_stickers) == "getCustomEmojiStickers"
    assert Client.method_name(:upload_sticker_file) == "uploadStickerFile"
    assert Client.method_name(:create_new_sticker_set) == "createNewStickerSet"
    assert Client.method_name(:replace_sticker_in_set) == "replaceStickerInSet"
    assert Client.method_name(:set_sticker_set_thumbnail) == "setStickerSetThumbnail"
    assert Client.method_name(:delete_sticker_set) == "deleteStickerSet"

    assert Client.method_name(:edit_message_caption) == "editMessageCaption"
    assert Client.method_name(:edit_message_media) == "editMessageMedia"
    assert Client.method_name(:edit_message_live_location) == "editMessageLiveLocation"
    assert Client.method_name(:edit_message_checklist) == "editMessageChecklist"
    assert Client.method_name(:stop_message_live_location) == "stopMessageLiveLocation"
    assert Client.method_name(:edit_message_reply_markup) == "editMessageReplyMarkup"
    assert Client.method_name(:stop_poll) == "stopPoll"
  end

  test "rich message validation requires exactly one input format" do
    assert :ok = RichMessage.validate(%{html: "<p>ok</p>"})
    assert :ok = RichMessage.validate(%{"markdown" => "### ok"})

    assert {:error, %{path: "rich_message"}} =
             RichMessage.validate(%{html: "<p>x</p>", markdown: "x"})

    assert {:error, %{path: "rich_message"}} = RichMessage.validate(%{})
  end

  test "capabilities separate agent-safe actions from restricted API areas" do
    sender = Capabilities.sender()
    catalog = Capabilities.catalog()
    interface = Sender.interface()

    assert "send_card" in sender.actions
    assert "send_contact" in sender.actions
    assert "send_media_group" in sender.actions
    assert Actions.classify("send_gift") == {:operator, :gifts}
    assert Actions.classify("get_my_star_balance") == {:operator, :payments}
    assert Actions.classify("verify_user") == {:operator, :verification}
    assert Actions.classify("set_business_account_name") == {:operator, :business}
    assert Actions.classify("answer_guest_query") == {:operator, :inline}
    assert Actions.classify("get_managed_bot_token") == {:operator, :managed_bots}
    assert Actions.classify("set_passport_data_errors") == {:operator, :passport}
    assert Actions.classify("set_game_score") == {:operator, :games}
    assert Actions.classify("set_my_commands") == {:operator, :bot_profile}
    assert Actions.classify("set_chat_menu_button") == {:operator, :bot_profile}
    assert Actions.classify("post_story") == {:operator, :stories}
    assert "business_profile" in sender.business_scoped
    assert "user_verification" in sender.organization_scoped
    assert "token_replace" in sender.managed_bot_scoped
    assert "commands" in sender.bot_profile_scoped
    assert "passport_data_errors" in sender.passport_scoped
    assert "webhooks" in sender.infrastructure_scoped
    assert "file_lookup" in sender.utility_scoped
    assert "member_bans" in sender.chat_admin_scoped
    assert "topic_create" in sender.forum_scoped
    assert "sticker_sets" in sender.sticker_scoped
    assert "gift_transfer" in sender.business_scoped
    assert "story" in sender.business_scoped
    assert Enum.all?(Actions.actions_in(:core), &(&1 in interface.actions))
    assert Enum.all?(Actions.actions_in(:media), &(&1 in interface.actions))
    assert Enum.all?(sender.actions, &(&1 in interface.actions))
    assert "sendGift" in catalog.implemented_client_methods
    assert "verifyUser" in catalog.implemented_client_methods
    assert "answerGuestQuery" in catalog.implemented_client_methods
    assert "setMyCommands" in catalog.implemented_client_methods
    assert "setPassportDataErrors" in catalog.implemented_client_methods
    assert "postStory" in catalog.implemented_client_methods
    assert "banChatMember" in catalog.implemented_client_methods
    assert "createForumTopic" in catalog.implemented_client_methods
    assert "deleteAllMessageReactions" in catalog.implemented_client_methods
    assert "getFile" in catalog.implemented_client_methods
    assert "getUpdates" in catalog.implemented_client_methods
    assert "setWebhook" in catalog.implemented_client_methods
    assert "getWebhookInfo" in catalog.implemented_client_methods
    assert "createNewStickerSet" in catalog.implemented_client_methods
    assert "ban_chat_member" in interface.actions
    assert "create_forum_topic" in interface.actions
    assert "get_file" in interface.actions
    assert "create_new_sticker_set" in interface.actions
    assert Actions.actions_in(:business) != []
    assert Actions.actions_in(:managed_bots) != []
    assert Actions.actions_in(:passport) != []
    assert Actions.actions_in(:stories) != []
    assert Actions.actions_in(:chat_admin) != []
    assert Actions.actions_in(:stickers_mgmt) != []
  end

  test "delivery builds rich, draft, edit, media, and poll payloads" do
    callback =
      Delivery.build_answer_callback_query(%{
        callback_query_id: "cb-1",
        text: "",
        show_alert: false,
        cache_time: 0
      })

    assert callback._method == :answer_callback_query
    assert callback.callback_query_id == "cb-1"
    assert callback.text == ""

    inline_result = %{
      "type" => "article",
      "id" => "result-1",
      "title" => "Status",
      "input_message_content" => %{"message_text" => "Ready"}
    }

    web_app =
      Delivery.build_answer_web_app_query(%{
        web_app_query_id: "web-1",
        result: inline_result
      })

    assert web_app._method == :answer_web_app_query
    assert web_app.result.type == "article"
    assert web_app.result.id == "result-1"

    inline =
      Delivery.build_answer_inline_query(%{
        inline_query_id: "inline-1",
        results: [inline_result],
        is_personal: true,
        next_offset: "",
        button: %{text: "Open app", web_app: %{url: "https://example.com/app"}}
      })

    assert inline._method == :answer_inline_query
    assert inline.results == [web_app.result]
    assert inline.is_personal == true
    assert inline.next_offset == ""
    assert inline.button == %{text: "Open app", web_app: %{url: "https://example.com/app"}}

    prepared =
      Delivery.build_save_prepared_inline_message(%{
        user_id: "123",
        result: inline_result,
        allow_user_chats: true
      })

    assert prepared._method == :save_prepared_inline_message
    assert prepared.user_id == 123
    assert prepared.allow_user_chats == true

    prepared_button =
      Delivery.build_save_prepared_keyboard_button(%{
        user_id: 123,
        button: %{
          text: "Choose user",
          request_users: %{request_id: 1, user_is_bot: false}
        }
      })

    assert prepared_button._method == :save_prepared_keyboard_button
    assert prepared_button.button.request_users == %{request_id: 1, user_is_bot: false}

    guest =
      Delivery.build_answer_guest_query(%{
        guest_query_id: "guest-1",
        result: inline_result
      })

    assert guest._method == :answer_guest_query
    assert guest.result.type == "article"

    boosts =
      Delivery.build_get_user_chat_boosts(%{
        chat_id: "@channel",
        user_id: "123"
      })

    assert boosts._method == :get_user_chat_boosts
    assert boosts.user_id == 123

    business_connection =
      Delivery.build_get_business_connection(%{business_connection_id: "biz-1"})

    assert business_connection._method == :get_business_connection

    managed_token = Delivery.build_get_managed_bot_token(%{user_id: "123"})
    assert managed_token._method == :get_managed_bot_token

    replace_token = Delivery.build_replace_managed_bot_token(%{user_id: 123})
    assert replace_token._method == :replace_managed_bot_token

    managed_access = Delivery.build_get_managed_bot_access_settings(%{user_id: 123})
    assert managed_access._method == :get_managed_bot_access_settings

    set_managed_access =
      Delivery.build_set_managed_bot_access_settings(%{
        user_id: 123,
        is_access_restricted: "true",
        added_user_ids: ["456", 789]
      })

    assert set_managed_access._method == :set_managed_bot_access_settings
    assert set_managed_access.is_access_restricted == true
    assert set_managed_access.added_user_ids == [456, 789]

    personal_messages =
      Delivery.build_get_user_personal_chat_messages(%{
        user_id: 123,
        limit: "5"
      })

    assert personal_messages._method == :get_user_personal_chat_messages
    assert personal_messages.limit == 5

    set_commands =
      Delivery.build_set_my_commands(%{
        commands: [%{command: "start", description: "Start the bot"}],
        language_code: "en"
      })

    assert set_commands._method == :set_my_commands
    assert set_commands.commands == [%{command: "start", description: "Start the bot"}]

    delete_commands = Delivery.build_delete_my_commands(%{language_code: ""})
    assert delete_commands._method == :delete_my_commands
    assert delete_commands.language_code == ""

    get_commands = Delivery.build_get_my_commands(%{scope: %{type: "default"}})
    assert get_commands._method == :get_my_commands
    assert get_commands.scope == %{type: "default"}

    set_name = Delivery.build_set_my_name(%{name: "Wingston", language_code: "en"})
    assert set_name._method == :set_my_name
    assert set_name.name == "Wingston"

    get_name = Delivery.build_get_my_name(%{language_code: "en"})
    assert get_name._method == :get_my_name

    set_description = Delivery.build_set_my_description(%{description: "Rally assistant"})
    assert set_description._method == :set_my_description

    get_description = Delivery.build_get_my_description(%{})
    assert get_description._method == :get_my_description

    set_short =
      Delivery.build_set_my_short_description(%{short_description: "Rally assistant"})

    assert set_short._method == :set_my_short_description

    get_short = Delivery.build_get_my_short_description(%{})
    assert get_short._method == :get_my_short_description

    set_profile_photo =
      Delivery.build_set_my_profile_photo(%{photo: %{type: "static", photo: "attach://profile"}})

    assert set_profile_photo._method == :set_my_profile_photo

    remove_profile_photo = Delivery.build_remove_my_profile_photo()
    assert remove_profile_photo._method == :remove_my_profile_photo

    set_menu =
      Delivery.build_set_chat_menu_button(%{
        chat_id: 123,
        menu_button: %{type: "web_app", text: "Open", web_app: %{url: "https://example.com"}}
      })

    assert set_menu._method == :set_chat_menu_button
    assert set_menu.chat_id == 123

    get_menu = Delivery.build_get_chat_menu_button(%{chat_id: "123"})
    assert get_menu._method == :get_chat_menu_button
    assert get_menu.chat_id == 123

    set_rights =
      Delivery.build_set_my_default_administrator_rights(%{
        rights: %{can_delete_messages: true},
        for_channels: true
      })

    assert set_rights._method == :set_my_default_administrator_rights
    assert set_rights.rights == %{can_delete_messages: true}

    get_rights = Delivery.build_get_my_default_administrator_rights(%{for_channels: false})
    assert get_rights._method == :get_my_default_administrator_rights

    story =
      Delivery.build_post_story(%{
        business_connection_id: "biz-1",
        content: %{type: "photo", photo: "attach://story-photo"},
        active_period: 86_400,
        caption: "**launch**",
        post_to_chat_page: true
      })

    assert story._method == :post_story
    assert story.content == %{type: "photo", photo: "attach://story-photo"}
    assert story.active_period == 86_400
    assert story.caption == "<b>launch</b>"
    assert story.post_to_chat_page == true

    repost =
      Delivery.build_repost_story(%{
        business_connection_id: "biz-1",
        from_chat_id: -100,
        from_story_id: "12",
        active_period: 43_200
      })

    assert repost._method == :repost_story
    assert repost.from_story_id == 12

    edit_story =
      Delivery.build_edit_story(%{
        business_connection_id: "biz-1",
        story_id: 13,
        content: %{type: "video", video: "attach://story-video", duration: "12.5"}
      })

    assert edit_story._method == :edit_story
    assert edit_story.content.duration == 12.5

    delete_story =
      Delivery.build_delete_story(%{
        business_connection_id: "biz-1",
        story_id: "14"
      })

    assert delete_story._method == :delete_story
    assert delete_story.story_id == 14

    rich =
      Delivery.build_send_rich_message(%{
        conversation_id: "tg:123:0",
        rich_message: %{html: "<h3>Hi</h3>"},
        buttons: [[%{text: "Open", url: "https://example.com"}]],
        protect_content: true
      })

    assert rich._method == :send_rich_message
    assert rich.chat_id == "123"
    assert rich.rich_message == %{html: "<h3>Hi</h3>"}
    assert rich.protect_content == true
    assert rich.reply_markup.inline_keyboard == [[%{text: "Open", url: "https://example.com"}]]

    draft =
      Delivery.build_send_rich_message_draft(%{
        conversation_id: "tg:123:0",
        draft_id: 55,
        rich_message: %{html: "<tg-thinking>work</tg-thinking>"}
      })

    assert draft._method == :send_rich_message_draft
    assert draft.draft_id == 55

    text_draft =
      Delivery.build_send_message_draft(%{
        conversation_id: "tg:123:0",
        draft_id: "56",
        text: "working"
      })

    assert text_draft._method == :send_message_draft
    assert text_draft.draft_id == 56
    assert text_draft.text == "working"
    assert text_draft.parse_mode == "HTML"

    thinking_draft =
      Delivery.build_send_message_draft(%{
        conversation_id: "tg:123:0",
        draft_id: 57,
        text: ""
      })

    assert thinking_draft.text == ""
    refute Map.has_key?(thinking_draft, :parse_mode)

    edit =
      Delivery.build_edit_rich_message(%{
        conversation_id: "tg:123:0",
        message_id: "9",
        rich_message: %{html: "<p>edited</p>"}
      })

    assert edit._method == :edit_message_text
    assert edit.message_id == 9

    edit_text =
      Delivery.build_edit_message_text(%{
        conversation_id: "tg:123:0",
        message_id: "10",
        text: "**edited**",
        buttons: [[%{text: "Open", url: "https://example.com"}]]
      })

    assert edit_text._method == :edit_message_text
    assert edit_text.message_id == 10
    assert edit_text.text == "<b>edited</b>"

    assert edit_text.reply_markup.inline_keyboard == [
             [%{text: "Open", url: "https://example.com"}]
           ]

    edit_caption =
      Delivery.build_edit_message_caption(%{
        conversation_id: "tg:123:0",
        message_id: 11,
        caption: "caption",
        show_caption_above_media: true
      })

    assert edit_caption._method == :edit_message_caption
    assert edit_caption.caption == "caption"
    assert edit_caption.show_caption_above_media == true

    edit_markup =
      Delivery.build_edit_message_reply_markup(%{
        conversation_id: "tg:123:0",
        message_id: 12,
        buttons: [[%{text: "Open", url: "https://example.com"}]]
      })

    assert edit_markup._method == :edit_message_reply_markup

    assert edit_markup.reply_markup.inline_keyboard == [
             [%{text: "Open", url: "https://example.com"}]
           ]

    stop_poll =
      Delivery.build_stop_poll(%{
        conversation_id: "tg:123:0",
        message_id: 13,
        buttons: [[%{text: "Done", callback_data: "done"}]]
      })

    assert stop_poll._method == :stop_poll
    assert stop_poll.reply_markup.inline_keyboard == [[%{text: "Done", callback_data: "done"}]]

    animation =
      Delivery.build_send_media(%{
        conversation_id: "tg:123:0",
        media_type: "animation",
        media: "https://example.com/a.mp4",
        caption: "**boot**",
        spoiler: true
      })

    assert animation._method == :send_animation
    assert animation.animation == "https://example.com/a.mp4"
    assert animation.caption == "<b>boot</b>"
    assert animation.has_spoiler == true

    video_note =
      Delivery.build_send_video_note(%{
        conversation_id: "tg:123:0",
        video_note: "file-video-note",
        duration: 10,
        length: 240
      })

    assert video_note._method == :send_video_note
    assert video_note.video_note == "file-video-note"
    assert video_note.duration == 10

    live_photo =
      Delivery.build_send_live_photo(%{
        conversation_id: "tg:123:0",
        live_photo: "file-live",
        photo: "file-photo",
        caption: "Moment"
      })

    assert live_photo._method == :send_live_photo
    assert live_photo.live_photo == "file-live"
    assert live_photo.photo == "file-photo"
    assert live_photo.caption == "Moment"

    sticker =
      Delivery.build_send_sticker(%{
        conversation_id: "tg:123:0",
        sticker: "file-sticker",
        emoji: "🪽",
        buttons: [[%{text: "Open", url: "https://example.com"}]]
      })

    assert sticker._method == :send_sticker
    assert sticker.sticker == "file-sticker"
    assert sticker.emoji == "🪽"
    assert sticker.reply_markup.inline_keyboard == [[%{text: "Open", url: "https://example.com"}]]

    media_group =
      Delivery.build_send_media_group(%{
        conversation_id: "tg:123:0",
        media: [
          %{type: "photo", media: "https://example.com/1.jpg"},
          %{type: "photo", media: "https://example.com/2.jpg", caption: "Second"}
        ]
      })

    assert media_group._method == :send_media_group
    assert length(media_group.media) == 2
    refute Map.has_key?(media_group, :reply_markup)

    paid_media =
      Delivery.build_send_paid_media(%{
        conversation_id: "tg:123:0",
        star_count: "10",
        media: [
          %{type: "photo", media: "https://example.com/paid.jpg"},
          %{type: :live_photo, media: "file-live", photo: "file-photo"}
        ],
        payload: "paid-1",
        caption: "**premium**"
      })

    assert paid_media._method == :send_paid_media
    assert paid_media.star_count == 10

    assert paid_media.media == [
             %{type: "photo", media: "https://example.com/paid.jpg"},
             %{type: "live_photo", media: "file-live", photo: "file-photo"}
           ]

    assert paid_media.payload == "paid-1"
    assert paid_media.caption == "<b>premium</b>"

    poll =
      Delivery.build_send_poll(%{
        conversation_id: "tg:123:0",
        question: "Pick",
        options: ["A"],
        is_anonymous: false,
        poll_type: "quiz",
        correct_option_id: 0,
        allows_revoting: true,
        shuffle_options: true,
        description: "One-option API smoke"
      })

    assert poll._method == :send_poll
    assert poll.options == [%{text: "A"}]
    assert poll.is_anonymous == false
    assert poll.correct_option_ids == [0]
    assert poll.allows_revoting == true
    assert poll.shuffle_options == true
    assert poll.description == "One-option API smoke"

    checklist =
      Delivery.build_send_checklist(%{
        conversation_id: "tg:123:0",
        business_connection_id: "biz-1",
        title: "Launch",
        tasks: [
          "Draft",
          %{id: 4, text: "Review", parse_mode: "HTML"}
        ],
        buttons: [[%{text: "Open", url: "https://example.com"}]]
      })

    assert checklist._method == :send_checklist
    assert checklist.business_connection_id == "biz-1"
    assert checklist.checklist.title == "Launch"

    assert checklist.checklist.tasks == [
             %{id: 1, text: "Draft"},
             %{id: 4, text: "Review", parse_mode: "HTML"}
           ]

    assert checklist.reply_markup.inline_keyboard == [
             [%{text: "Open", url: "https://example.com"}]
           ]

    edit_checklist =
      Delivery.build_edit_message_checklist(%{
        conversation_id: "tg:123:0",
        message_id: 18,
        business_connection_id: "biz-1",
        checklist: %{
          title: "Updated launch",
          tasks: [%{text: "Ship"}],
          others_can_add_tasks: true
        }
      })

    assert edit_checklist._method == :edit_message_checklist
    assert edit_checklist.message_id == 18
    assert edit_checklist.checklist.others_can_add_tasks == true
    assert edit_checklist.checklist.tasks == [%{id: 1, text: "Ship"}]

    location =
      Delivery.build_send_location(%{
        conversation_id: "tg:123:0",
        latitude: "41.3874",
        longitude: "2.1686",
        horizontal_accuracy: 20
      })

    assert location._method == :send_location
    assert location.latitude == 41.3874
    assert location.longitude == 2.1686
    assert location.horizontal_accuracy == 20

    venue =
      Delivery.build_send_venue(%{
        conversation_id: "tg:123:0",
        latitude: 41.3874,
        longitude: 2.1686,
        title: "HQ",
        address: "Barcelona"
      })

    assert venue._method == :send_venue
    assert venue.title == "HQ"
    assert venue.address == "Barcelona"

    contact =
      Delivery.build_send_contact(%{
        conversation_id: "tg:123:0",
        phone_number: "+34123456789",
        first_name: "Example",
        last_name: "Ops"
      })

    assert contact._method == :send_contact
    assert contact.phone_number == "+34123456789"
    assert contact.first_name == "Example"
    assert contact.last_name == "Ops"

    dice = Delivery.build_send_dice(%{conversation_id: "tg:123:0", emoji: "🎲"})
    assert dice._method == :send_dice
    assert dice.emoji == "🎲"

    invoice =
      Delivery.build_send_invoice(%{
        conversation_id: "tg:123:0",
        title: "Access",
        description: "Premium media",
        payload: "invoice-1",
        currency: "XTR",
        prices: [%{label: "Access", amount: 25}],
        buttons: [[%{text: "Pay", pay: true}]]
      })

    assert invoice._method == :send_invoice
    assert invoice.provider_token == ""
    assert invoice.currency == "XTR"
    assert invoice.prices == [%{label: "Access", amount: 25}]
    assert invoice.reply_markup.inline_keyboard == [[%{text: "Pay", pay: true}]]

    invoice_link =
      Delivery.build_create_invoice_link(%{
        title: "Access",
        description: "Premium media",
        payload: "invoice-link-1",
        currency: "XTR",
        prices: [%{label: "Access", amount: 25}],
        subscription_period: 2_592_000
      })

    assert invoice_link._method == :create_invoice_link
    assert invoice_link.subscription_period == 2_592_000

    shipping =
      Delivery.build_answer_shipping_query(%{
        shipping_query_id: "ship-1",
        ok: true,
        shipping_options: [
          %{id: "standard", title: "Standard", prices: [%{label: "Shipping", amount: 5}]}
        ]
      })

    assert shipping._method == :answer_shipping_query

    assert shipping.shipping_options == [
             %{id: "standard", title: "Standard", prices: [%{label: "Shipping", amount: 5}]}
           ]

    pre_checkout =
      Delivery.build_answer_pre_checkout_query(%{
        pre_checkout_query_id: "pre-1",
        ok: false,
        error_message: "Sold out"
      })

    assert pre_checkout._method == :answer_pre_checkout_query
    assert pre_checkout.error_message == "Sold out"

    star_transactions =
      Delivery.build_get_star_transactions(%{
        offset: "10",
        limit: "25"
      })

    assert star_transactions._method == :get_star_transactions
    assert star_transactions.offset == 10
    assert star_transactions.limit == 25

    available_gifts = Delivery.build_get_available_gifts()
    assert available_gifts._method == :get_available_gifts

    sent_gift =
      Delivery.build_send_gift(%{
        user_id: "123",
        gift_id: "gift-1",
        pay_for_upgrade: true,
        text: "Enjoy",
        text_parse_mode: "HTML"
      })

    assert sent_gift._method == :send_gift
    assert sent_gift.user_id == 123
    assert sent_gift.gift_id == "gift-1"
    assert sent_gift.pay_for_upgrade == true
    assert sent_gift.text == "Enjoy"

    premium_gift =
      Delivery.build_gift_premium_subscription(%{
        user_id: 123,
        month_count: "6",
        star_count: "1500",
        text: "Premium"
      })

    assert premium_gift._method == :gift_premium_subscription
    assert premium_gift.month_count == 6
    assert premium_gift.star_count == 1500

    business_balance =
      Delivery.build_get_business_account_star_balance(%{business_connection_id: "biz-1"})

    assert business_balance._method == :get_business_account_star_balance

    business_transfer =
      Delivery.build_transfer_business_account_stars(%{
        business_connection_id: "biz-1",
        star_count: "100"
      })

    assert business_transfer._method == :transfer_business_account_stars
    assert business_transfer.star_count == 100

    business_gifts =
      Delivery.build_get_business_account_gifts(%{
        business_connection_id: "biz-1",
        exclude_unsaved: true,
        sort_by_price: true,
        limit: "50"
      })

    assert business_gifts._method == :get_business_account_gifts
    assert business_gifts.limit == 50
    assert business_gifts.exclude_unsaved == true

    user_gifts =
      Delivery.build_get_user_gifts(%{
        user_id: "123",
        exclude_unique: true,
        offset: "next"
      })

    assert user_gifts._method == :get_user_gifts
    assert user_gifts.user_id == 123
    assert user_gifts.offset == "next"

    chat_gifts =
      Delivery.build_get_chat_gifts(%{
        chat_id: "@channel",
        exclude_saved: true
      })

    assert chat_gifts._method == :get_chat_gifts
    assert chat_gifts.chat_id == "@channel"

    convert_gift =
      Delivery.build_convert_gift_to_stars(%{
        business_connection_id: "biz-1",
        owned_gift_id: "owned-1"
      })

    assert convert_gift._method == :convert_gift_to_stars

    upgrade_gift =
      Delivery.build_upgrade_gift(%{
        business_connection_id: "biz-1",
        owned_gift_id: "owned-2",
        keep_original_details: true,
        star_count: "0"
      })

    assert upgrade_gift._method == :upgrade_gift
    assert upgrade_gift.star_count == 0

    transfer_gift =
      Delivery.build_transfer_gift(%{
        business_connection_id: "biz-1",
        owned_gift_id: "owned-3",
        new_owner_chat_id: 123,
        star_count: 5
      })

    assert transfer_gift._method == :transfer_gift
    assert transfer_gift.new_owner_chat_id == 123

    verify_user =
      Delivery.build_verify_user(%{
        user_id: "123",
        custom_description: "Official"
      })

    assert verify_user._method == :verify_user
    assert verify_user.custom_description == "Official"

    verify_chat =
      Delivery.build_verify_chat(%{
        chat_id: "@channel",
        custom_description: ""
      })

    assert verify_chat._method == :verify_chat
    assert verify_chat.custom_description == ""

    remove_user_verification = Delivery.build_remove_user_verification(%{user_id: 123})
    assert remove_user_verification._method == :remove_user_verification

    remove_chat_verification = Delivery.build_remove_chat_verification(%{chat_id: "@channel"})
    assert remove_chat_verification._method == :remove_chat_verification

    read_business =
      Delivery.build_read_business_message(%{
        business_connection_id: "biz-1",
        chat_id: "456",
        message_id: "78"
      })

    assert read_business._method == :read_business_message
    assert read_business.chat_id == 456
    assert read_business.message_id == 78

    delete_business =
      Delivery.build_delete_business_messages(%{
        business_connection_id: "biz-1",
        message_ids: ["1", 2]
      })

    assert delete_business._method == :delete_business_messages
    assert delete_business.message_ids == [1, 2]

    business_name =
      Delivery.build_set_business_account_name(%{
        business_connection_id: "biz-1",
        first_name: "Wingston",
        last_name: ""
      })

    assert business_name._method == :set_business_account_name
    assert business_name.last_name == ""

    business_username =
      Delivery.build_set_business_account_username(%{
        business_connection_id: "biz-1",
        username: "wingston"
      })

    assert business_username._method == :set_business_account_username

    business_bio =
      Delivery.build_set_business_account_bio(%{
        business_connection_id: "biz-1",
        bio: "Rally assistant"
      })

    assert business_bio._method == :set_business_account_bio

    business_photo =
      Delivery.build_set_business_account_profile_photo(%{
        business_connection_id: "biz-1",
        photo: %{type: "static", photo: "attach://profile-photo"},
        is_public: true
      })

    assert business_photo._method == :set_business_account_profile_photo
    assert business_photo.photo.type == "static"

    remove_business_photo =
      Delivery.build_remove_business_account_profile_photo(%{
        business_connection_id: "biz-1",
        is_public: false
      })

    assert remove_business_photo._method == :remove_business_account_profile_photo

    gift_settings =
      Delivery.build_set_business_account_gift_settings(%{
        business_connection_id: "biz-1",
        show_gift_button: "true",
        accepted_gift_types: %{
          unlimited_gifts: true,
          limited_gifts: false,
          unique_gifts: true,
          premium_subscription: false
        }
      })

    assert gift_settings._method == :set_business_account_gift_settings
    assert gift_settings.show_gift_button == true
    assert gift_settings.accepted_gift_types.unique_gifts == true

    approve_suggested =
      Delivery.build_approve_suggested_post(%{
        chat_id: 123,
        message_id: "45",
        send_date: 1_800_000_000
      })

    assert approve_suggested._method == :approve_suggested_post
    assert approve_suggested.message_id == 45

    decline_suggested =
      Delivery.build_decline_suggested_post(%{
        chat_id: "123",
        message_id: 46,
        comment: "Needs changes"
      })

    assert decline_suggested._method == :decline_suggested_post
    assert decline_suggested.comment == "Needs changes"

    passport_errors =
      Delivery.build_set_passport_data_errors(%{
        user_id: 123,
        errors: [
          %{
            "source" => "data",
            "type" => "personal_details",
            "field_name" => "first_name",
            "data_hash" => "hash",
            "message" => "Invalid name"
          }
        ]
      })

    assert passport_errors._method == :set_passport_data_errors
    assert passport_errors.errors |> hd() |> Map.get(:source) == "data"

    game_score =
      Delivery.build_set_game_score(%{
        user_id: 123,
        score: "42",
        chat_id: "@gamechat",
        message_id: "47",
        force: true
      })

    assert game_score._method == :set_game_score
    assert game_score.score == 42
    assert game_score.message_id == 47

    high_scores =
      Delivery.build_get_game_high_scores(%{
        user_id: 123,
        inline_message_id: "inline-game-1"
      })

    assert high_scores._method == :get_game_high_scores
    assert high_scores.inline_message_id == "inline-game-1"

    refund =
      Delivery.build_refund_star_payment(%{
        user_id: "123",
        telegram_payment_charge_id: "charge-1"
      })

    assert refund._method == :refund_star_payment
    assert refund.user_id == 123

    subscription =
      Delivery.build_edit_user_star_subscription(%{
        user_id: 123,
        telegram_payment_charge_id: "charge-2",
        is_canceled: "true"
      })

    assert subscription._method == :edit_user_star_subscription
    assert subscription.is_canceled == true

    game =
      Delivery.build_send_game(%{
        conversation_id: "tg:123:0",
        game_short_name: "rally_quest"
      })

    assert game._method == :send_game
    assert game.game_short_name == "rally_quest"

    chat_action =
      Delivery.build_send_chat_action(%{
        conversation_id: "tg:123:0",
        action: :upload_photo
      })

    assert chat_action._method == :send_chat_action
    assert chat_action.action == "upload_photo"

    reaction =
      Delivery.build_set_message_reaction(%{
        conversation_id: "tg:123:0",
        message_id: "123",
        reaction: "👍",
        is_big: true
      })

    assert reaction._method == :set_message_reaction
    assert reaction.message_id == 123
    assert reaction.reaction == [%{type: "emoji", emoji: "👍"}]
    assert reaction.is_big == true

    clear_reaction =
      Delivery.build_set_message_reaction(%{
        conversation_id: "tg:123:0",
        message_id: 123,
        reactions: []
      })

    assert clear_reaction.reaction == []

    delete_reactions =
      Delivery.build_delete_all_message_reactions(%{
        chat_id: "@wingston",
        actor_chat_id: -100_123
      })

    assert delete_reactions._method == :delete_all_message_reactions
    assert delete_reactions.chat_id == "@wingston"
    assert delete_reactions.actor_chat_id == -100_123

    ban =
      Delivery.build_ban_chat_member(%{
        chat_id: -100_123,
        user_id: "42",
        until_date: "0",
        revoke_messages: true
      })

    assert ban._method == :ban_chat_member
    assert ban.user_id == 42
    assert ban.until_date == 0

    invite =
      Delivery.build_create_chat_subscription_invite_link(%{
        chat_id: -100_123,
        name: "Supporters",
        subscription_period: "2592000",
        subscription_price: "100"
      })

    assert invite._method == :create_chat_subscription_invite_link
    assert invite.subscription_period == 2_592_000
    assert invite.subscription_price == 100

    join_query =
      Delivery.build_answer_chat_join_request_query(%{
        chat_join_request_query_id: "join-1",
        result: :queue
      })

    assert join_query._method == :answer_chat_join_request_query
    assert join_query.result == "queue"

    web_app =
      Delivery.build_send_chat_join_request_web_app(%{
        chat_join_request_query_id: "join-1",
        web_app_url: "https://example.com/join"
      })

    assert web_app.web_app_url == "https://example.com/join"

    topic =
      Delivery.build_create_forum_topic(%{
        chat_id: -100_123,
        name: "Support",
        icon_color: "7322096"
      })

    assert topic._method == :create_forum_topic
    assert topic.icon_color == 7_322_096

    edit_topic =
      Delivery.build_edit_forum_topic(%{
        chat_id: -100_123,
        message_thread_id: "5",
        name: ""
      })

    assert edit_topic._method == :edit_forum_topic
    assert edit_topic.message_thread_id == 5
    assert edit_topic.name == ""

    file = Delivery.build_get_file(%{file_id: "file-123"})
    assert file == %{_method: :get_file, file_id: "file-123"}

    profile_audios =
      Delivery.build_get_user_profile_audios(%{user_id: "42", offset: 0, limit: "10"})

    assert profile_audios._method == :get_user_profile_audios
    assert profile_audios.user_id == 42
    assert profile_audios.limit == 10

    emoji_status =
      Delivery.build_set_user_emoji_status(%{
        user_id: 42,
        emoji_status_custom_emoji_id: "emoji-1",
        emoji_status_expiration_date: "0"
      })

    assert emoji_status._method == :set_user_emoji_status
    assert emoji_status.emoji_status_custom_emoji_id == "emoji-1"

    sticker_set = Delivery.build_get_sticker_set(%{name: "wingston_by_bot"})
    assert sticker_set == %{_method: :get_sticker_set, name: "wingston_by_bot"}

    custom_emoji =
      Delivery.build_get_custom_emoji_stickers(%{custom_emoji_ids: ["emoji-1", "emoji-2"]})

    assert custom_emoji.custom_emoji_ids == ["emoji-1", "emoji-2"]

    upload =
      Delivery.build_upload_sticker_file(%{
        user_id: 42,
        sticker: "attach://sticker",
        sticker_format: :static
      })

    assert upload.sticker_format == "static"

    new_set =
      Delivery.build_create_new_sticker_set(%{
        user_id: 42,
        name: "wingston_by_bot",
        title: "Wingston",
        stickers: [%{sticker: "attach://sticker", emoji_list: ["🪽"], format: "static"}],
        sticker_type: :regular
      })

    assert new_set._method == :create_new_sticker_set
    assert new_set.sticker_type == "regular"
    assert length(new_set.stickers) == 1

    replace_sticker =
      Delivery.build_replace_sticker_in_set(%{
        user_id: 42,
        name: "wingston_by_bot",
        old_sticker: "old-file",
        sticker: %{sticker: "attach://new", emoji_list: ["🪽"], format: "static"}
      })

    assert replace_sticker.old_sticker == "old-file"

    keywords = Delivery.build_set_sticker_keywords(%{sticker: "file-1", keywords: ["wingston"]})
    assert keywords.keywords == ["wingston"]

    thumbnail =
      Delivery.build_set_sticker_set_thumbnail(%{
        name: "wingston_by_bot",
        user_id: 42,
        thumbnail: "attach://thumb",
        format: "static"
      })

    assert thumbnail.thumbnail == "attach://thumb"

    assert_raise ArgumentError, ~r/media group must contain 2 to 10 items/, fn ->
      Delivery.build_send_media_group(%{
        conversation_id: "tg:123:0",
        media: [%{type: "photo", media: "https://example.com/1.jpg"}]
      })
    end

    assert_raise ArgumentError, ~r/text must be 0 to 200 characters/, fn ->
      Delivery.build_answer_callback_query(%{
        callback_query_id: "cb-1",
        text: String.duplicate("x", 201)
      })
    end

    assert_raise ArgumentError, ~r/inline query result requires non-empty type and id/, fn ->
      Delivery.build_answer_inline_query(%{
        inline_query_id: "inline-1",
        results: [%{type: "article"}]
      })
    end

    assert_raise ArgumentError,
                 ~r/prepared keyboard button can specify only one request action/,
                 fn ->
                   Delivery.build_save_prepared_keyboard_button(%{
                     user_id: 1,
                     button: %{
                       text: "Choose",
                       request_users: %{request_id: 1},
                       request_chat: %{request_id: 2}
                     }
                   })
                 end

    assert_raise ArgumentError, ~r/added_user_ids must contain at most 10 user ids/, fn ->
      Delivery.build_set_managed_bot_access_settings(%{
        user_id: 1,
        is_access_restricted: true,
        added_user_ids: Enum.to_list(1..11)
      })
    end

    assert_raise ArgumentError, ~r/reaction removal requires only one/, fn ->
      Delivery.build_delete_message_reaction(%{
        chat_id: -100_123,
        message_id: 10,
        user_id: 1,
        actor_chat_id: -100_123
      })
    end

    assert_raise ArgumentError, ~r/subscription_period must be 2592000/, fn ->
      Delivery.build_create_chat_subscription_invite_link(%{
        chat_id: -100_123,
        subscription_period: 86_400,
        subscription_price: 100
      })
    end

    assert_raise ArgumentError, ~r/join request query result/, fn ->
      Delivery.build_answer_chat_join_request_query(%{
        chat_join_request_query_id: "join-1",
        result: "maybe"
      })
    end

    assert_raise ArgumentError, ~r/icon_color must be one of/, fn ->
      Delivery.build_create_forum_topic(%{
        chat_id: -100_123,
        name: "Support",
        icon_color: 1
      })
    end

    assert_raise ArgumentError, ~r/file_id must be non-empty/, fn ->
      Delivery.build_get_file(%{file_id: ""})
    end

    assert_raise ArgumentError, ~r/custom_emoji_ids must contain 1 to 200/, fn ->
      Delivery.build_get_custom_emoji_stickers(%{custom_emoji_ids: []})
    end

    assert_raise ArgumentError, ~r/sticker_format must be static/, fn ->
      Delivery.build_upload_sticker_file(%{
        user_id: 42,
        sticker: "attach://sticker",
        sticker_format: "photo"
      })
    end

    assert_raise ArgumentError, ~r/stickers must contain 1 to 50/, fn ->
      Delivery.build_create_new_sticker_set(%{
        user_id: 42,
        name: "wingston_by_bot",
        title: "Wingston",
        stickers: []
      })
    end

    assert_raise ArgumentError, ~r/limit must be 1 to 20/, fn ->
      Delivery.build_get_user_personal_chat_messages(%{user_id: 1, limit: 21})
    end

    assert_raise ArgumentError, ~r/commands must contain 1 to 100 bot commands/, fn ->
      Delivery.build_set_my_commands(%{commands: []})
    end

    assert_raise ArgumentError, ~r/command must be 1 to 32 lowercase/, fn ->
      Delivery.build_set_my_commands(%{
        commands: [%{command: "Start", description: "Start the bot"}]
      })
    end

    assert_raise ArgumentError,
                 ~r/language_code must be empty or a two-letter lowercase code/,
                 fn ->
                   Delivery.build_set_my_name(%{name: "Wingston", language_code: "eng"})
                 end

    assert_raise ArgumentError, ~r/description must be 0 to 512 characters/, fn ->
      Delivery.build_set_my_description(%{description: String.duplicate("x", 513)})
    end

    assert_raise ArgumentError, ~r/active_period must be 21600, 43200, 86400, or 172800/, fn ->
      Delivery.build_post_story(%{
        business_connection_id: "biz-1",
        content: %{type: "photo", photo: "attach://story-photo"},
        active_period: 100
      })
    end

    assert_raise ArgumentError, ~r/story content type must be photo or video/, fn ->
      Delivery.build_post_story(%{
        business_connection_id: "biz-1",
        content: %{type: "audio", audio: "attach://story-audio"},
        active_period: 86_400
      })
    end

    assert_raise ArgumentError, ~r/draft_id must be a non-zero integer/, fn ->
      Delivery.build_send_message_draft(%{
        conversation_id: "tg:123:0",
        draft_id: 0,
        text: "invalid"
      })
    end

    assert_raise ArgumentError, ~r/text must be non-empty/, fn ->
      Delivery.build_edit_message_text(%{conversation_id: "tg:123:0", message_id: 10, text: ""})
    end

    assert_raise ArgumentError, ~r/edit reply_markup must be an inline keyboard/, fn ->
      Delivery.build_edit_message_reply_markup(%{
        conversation_id: "tg:123:0",
        message_id: 10,
        reply_markup: %{force_reply: true}
      })
    end

    assert_raise ArgumentError, ~r/sticker must be non-empty/, fn ->
      Delivery.build_send_sticker(%{conversation_id: "tg:123:0", sticker: ""})
    end

    assert_raise ArgumentError, ~r/audio media groups can contain only audio items/, fn ->
      Delivery.build_send_media_group(%{
        conversation_id: "tg:123:0",
        media: [
          %{type: "audio", media: "file-audio"},
          %{type: "photo", media: "https://example.com/1.jpg"}
        ]
      })
    end

    assert_raise ArgumentError, ~r/star_count must be 1 to 25000/, fn ->
      Delivery.build_send_paid_media(%{
        conversation_id: "tg:123:0",
        star_count: 0,
        media: [%{type: "photo", media: "file-photo"}]
      })
    end

    assert_raise ArgumentError, ~r/paid media must contain 1 to 10 items/, fn ->
      Delivery.build_send_paid_media(%{
        conversation_id: "tg:123:0",
        star_count: 1,
        media: []
      })
    end

    assert_raise ArgumentError, ~r/Telegram Stars invoices require exactly one price/, fn ->
      Delivery.build_send_invoice(%{
        conversation_id: "tg:123:0",
        title: "Access",
        description: "Premium",
        payload: "invoice",
        currency: "XTR",
        prices: [%{label: "One", amount: 1}, %{label: "Two", amount: 2}]
      })
    end

    assert_raise ArgumentError, ~r/first button must be a pay button/, fn ->
      Delivery.build_send_invoice(%{
        conversation_id: "tg:123:0",
        title: "Access",
        description: "Premium",
        payload: "invoice",
        currency: "XTR",
        prices: [%{label: "Access", amount: 1}],
        buttons: [[%{text: "Open", url: "https://example.com"}]]
      })
    end

    assert_raise ArgumentError, ~r/subscription_period requires XTR currency/, fn ->
      Delivery.build_create_invoice_link(%{
        title: "Access",
        description: "Premium",
        payload: "invoice",
        provider_token: "provider",
        currency: "USD",
        prices: [%{label: "Access", amount: 1}],
        subscription_period: 2_592_000
      })
    end

    assert_raise ArgumentError, ~r/shipping_options must contain at least one option/, fn ->
      Delivery.build_answer_shipping_query(%{
        shipping_query_id: "ship-1",
        ok: true,
        shipping_options: []
      })
    end

    assert_raise ArgumentError, ~r/error_message must be 1 to 200 characters/, fn ->
      Delivery.build_answer_pre_checkout_query(%{
        pre_checkout_query_id: "pre-1",
        ok: false
      })
    end

    assert_raise ArgumentError, ~r/exactly one of user_id or chat_id/, fn ->
      Delivery.build_send_gift(%{gift_id: "gift-1", user_id: 1, chat_id: "@channel"})
    end

    assert_raise ArgumentError, ~r/1000 Stars for 3 months/, fn ->
      Delivery.build_gift_premium_subscription(%{
        user_id: 1,
        month_count: 3,
        star_count: 1500
      })
    end

    assert_raise ArgumentError, ~r/star_count must be 1 to 10000/, fn ->
      Delivery.build_transfer_business_account_stars(%{
        business_connection_id: "biz-1",
        star_count: 0
      })
    end

    assert_raise ArgumentError, ~r/limit must be 1 to 100/, fn ->
      Delivery.build_get_user_gifts(%{user_id: 1, limit: 101})
    end

    assert_raise ArgumentError, ~r/custom_description must be 0 to 70 characters/, fn ->
      Delivery.build_verify_user(%{user_id: 1, custom_description: String.duplicate("x", 71)})
    end

    assert_raise ArgumentError, ~r/message_ids must contain 1 to 100/, fn ->
      Delivery.build_delete_business_messages(%{business_connection_id: "biz-1", message_ids: []})
    end

    assert_raise ArgumentError, ~r/first_name must be 1 to 64 characters/, fn ->
      Delivery.build_set_business_account_name(%{
        business_connection_id: "biz-1",
        first_name: ""
      })
    end

    assert_raise ArgumentError, ~r/accepted_gift_types must include at least one gift type/, fn ->
      Delivery.build_set_business_account_gift_settings(%{
        business_connection_id: "biz-1",
        show_gift_button: true,
        accepted_gift_types: %{}
      })
    end

    assert_raise ArgumentError, ~r/comment must be 0 to 128 characters/, fn ->
      Delivery.build_decline_suggested_post(%{
        chat_id: 1,
        message_id: 1,
        comment: String.duplicate("x", 129)
      })
    end

    assert_raise ArgumentError, ~r/passport errors must contain at least one error/, fn ->
      Delivery.build_set_passport_data_errors(%{user_id: 1, errors: []})
    end

    assert_raise ArgumentError, ~r/game score target requires/, fn ->
      Delivery.build_set_game_score(%{user_id: 1, score: 1, chat_id: 1})
    end

    assert_raise ArgumentError, ~r/score must be non-negative/, fn ->
      Delivery.build_set_game_score(%{user_id: 1, score: -1, inline_message_id: "inline"})
    end

    assert_raise ArgumentError, ~r/invalid chat action/, fn ->
      Delivery.build_send_chat_action(%{conversation_id: "tg:123:0", action: "wave"})
    end

    assert_raise ArgumentError, ~r/at most one reaction/, fn ->
      Delivery.build_set_message_reaction(%{
        conversation_id: "tg:123:0",
        message_id: 123,
        reaction: ["👍", "🔥"]
      })
    end

    assert_raise ArgumentError, ~r/paid reactions/, fn ->
      Delivery.build_set_message_reaction(%{
        conversation_id: "tg:123:0",
        message_id: 123,
        reaction: %{type: "paid"}
      })
    end

    assert_raise ArgumentError, ~r/business_connection_id must be non-empty/, fn ->
      Delivery.build_send_checklist(%{
        conversation_id: "tg:123:0",
        title: "Missing business",
        tasks: ["Task"]
      })
    end

    assert_raise ArgumentError, ~r/checklist tasks must contain 1 to 30 tasks/, fn ->
      Delivery.build_send_checklist(%{
        conversation_id: "tg:123:0",
        business_connection_id: "biz-1",
        title: "Empty",
        tasks: []
      })
    end

    assert_raise ArgumentError, ~r/checklist task ids must be unique/, fn ->
      Delivery.build_send_checklist(%{
        conversation_id: "tg:123:0",
        business_connection_id: "biz-1",
        title: "Duplicate",
        tasks: [%{id: 1, text: "A"}, %{id: 1, text: "B"}]
      })
    end
  end

  test "delivery builds lifecycle and native edit payloads" do
    copy =
      Delivery.build_copy_message(%{
        conversation_id: "tg:123:0",
        from_chat_id: "@source",
        message_id: "20",
        caption: "**copied**",
        buttons: [[%{text: "Open", url: "https://example.com"}]]
      })

    assert copy._method == :copy_message
    assert copy.chat_id == "123"
    assert copy.from_chat_id == "@source"
    assert copy.message_id == 20
    assert copy.caption == "<b>copied</b>"
    assert copy.reply_markup.inline_keyboard == [[%{text: "Open", url: "https://example.com"}]]

    copy_many =
      Delivery.build_copy_messages(%{
        conversation_id: "tg:123:0",
        from_chat_id: "-1001",
        message_ids: ["21", 22]
      })

    assert copy_many._method == :copy_messages
    assert copy_many.message_ids == [21, 22]

    forward =
      Delivery.build_forward_message(%{
        conversation_id: "tg:123:0",
        from_chat_id: -1001,
        message_id: 23
      })

    assert forward._method == :forward_message
    assert forward.from_chat_id == -1001

    forward_many =
      Delivery.build_forward_messages(%{
        conversation_id: "tg:123:0",
        from_chat_id: "@source",
        message_ids: [24, 25]
      })

    assert forward_many._method == :forward_messages
    assert forward_many.message_ids == [24, 25]

    delete = Delivery.build_delete_message(%{conversation_id: "tg:123:0", message_id: "26"})
    assert delete._method == :delete_message
    assert delete.message_id == 26

    delete_many =
      Delivery.build_delete_messages(%{conversation_id: "tg:123:0", message_ids: [27, "28"]})

    assert delete_many._method == :delete_messages
    assert delete_many.message_ids == [27, 28]

    edit_media =
      Delivery.build_edit_message_media(%{
        conversation_id: "tg:123:0",
        message_id: 29,
        media: %{type: :photo, media: "file-photo", caption: "**updated**"},
        buttons: [[%{text: "Done", callback_data: "done"}]]
      })

    assert edit_media._method == :edit_message_media

    assert edit_media.media == %{
             type: "photo",
             media: "file-photo",
             caption: "<b>updated</b>",
             parse_mode: "HTML"
           }

    assert edit_media.reply_markup.inline_keyboard == [[%{text: "Done", callback_data: "done"}]]

    live =
      Delivery.build_edit_live_location(%{
        conversation_id: "tg:123:0",
        message_id: 30,
        latitude: "41.38",
        longitude: "2.17",
        heading: 90
      })

    assert live._method == :edit_message_live_location
    assert live.latitude == 41.38
    assert live.longitude == 2.17
    assert live.heading == 90

    stop_live =
      Delivery.build_stop_live_location(%{
        conversation_id: "tg:123:0",
        message_id: 31
      })

    assert stop_live._method == :stop_message_live_location

    assert_raise ArgumentError, ~r/sorted in strictly increasing order/, fn ->
      Delivery.build_forward_messages(%{
        conversation_id: "tg:123:0",
        from_chat_id: "@source",
        message_ids: [3, 2]
      })
    end

    assert_raise ArgumentError, ~r/edit media requires type/, fn ->
      Delivery.build_edit_message_media(%{
        conversation_id: "tg:123:0",
        message_id: 1,
        media: %{type: "voice", media: "file-voice"}
      })
    end
  end

  test "card renderer validates agent-facing schema and renders safe rich HTML" do
    card = %{
      "title" => "Operator <Snapshot>",
      "blocks" => [
        %{
          "kind" => "paragraph",
          "text" => [
            "Spend ",
            %{"kind" => "bold", "text" => "< cap"},
            " and ",
            %{"kind" => "link", "text" => "open", "url" => "https://example.com/report"},
            " with ",
            %{"kind" => "spoiler", "text" => "care"}
          ]
        },
        %{
          "kind" => "table",
          "bordered" => true,
          "striped" => true,
          "headers" => ["identity", "state"],
          "rows" => [["global", "ok"]]
        },
        %{
          "kind" => "details",
          "summary" => "More",
          "open" => true,
          "blocks" => [
            %{"kind" => "list", "items" => ["router", "budget"]}
          ]
        },
        %{
          "kind" => "checklist",
          "items" => [
            %{
              "text" => [
                %{"kind" => "custom_emoji", "emoji_id" => "5368324170671202286", "text" => "🙂"},
                " identity"
              ],
              "checked" => true
            },
            %{"text" => "router", "checked" => false}
          ]
        },
        %{
          "kind" => "media",
          "media_type" => "animation",
          "url" => "https://example.com/a.mp4",
          "caption" => "Boot",
          "spoiler" => true
        },
        %{
          "kind" => "map",
          "latitude" => "41.3874",
          "longitude" => "2.1686",
          "zoom" => 14,
          "caption" => "Barcelona"
        },
        %{
          "kind" => "time",
          "unix" => 1_647_531_900,
          "format" => "wDT",
          "text" => [
            %{"kind" => "mention", "user_id" => 123_456_789, "text" => "operator"},
            " at 22:45"
          ]
        },
        %{
          "kind" => "slideshow",
          "slides" => [
            %{"kind" => "media", "media_type" => "photo", "url" => "https://example.com/1.jpg"},
            %{"kind" => "media", "media_type" => "video", "url" => "https://example.com/2.mp4"}
          ]
        }
      ]
    }

    assert {:ok, %{html: html}} = Card.to_rich_message(card)
    assert html =~ "<h3>Operator &lt;Snapshot&gt;</h3>"

    assert html =~
             ~s(<p>Spend <b>&lt; cap</b> and <a href="https://example.com/report">open</a> with <tg-spoiler>care</tg-spoiler></p>)

    assert html =~ "<table bordered striped>"
    assert html =~ "<details open><summary>More</summary>"
    assert html =~ "<li>router</li>"

    assert html =~
             ~s(<input type="checkbox" checked/><tg-emoji emoji-id="5368324170671202286">🙂</tg-emoji> identity)

    assert html =~
             ~s(<figure><video tg-spoiler src="https://example.com/a.mp4"></video><figcaption>Boot</figcaption></figure>)

    assert html =~
             ~s(<figure><tg-map lat="41.3874" long="2.1686" zoom="14"/><figcaption>Barcelona</figcaption></figure>)

    assert html =~
             ~s(<tg-time unix="1647531900" format="wDT"><a href="tg://user?id=123456789">operator</a> at 22:45</tg-time>)

    assert html =~
             ~s(<tg-slideshow><img src="https://example.com/1.jpg"/><video src="https://example.com/2.mp4"></video></tg-slideshow>)

    refute html =~ "<section>"

    invalid = %{
      "blocks" => [%{"kind" => "media", "media_type" => "photo", "url" => "file:///tmp/x"}]
    }

    assert {:error, [%{path: "card.blocks[0].url"}]} = Card.validate(invalid)

    invalid_map = %{"blocks" => [%{"kind" => "map", "longitude" => "2.1686"}]}
    assert {:error, [%{path: "card.blocks[0].latitude"}]} = Card.validate(invalid_map)

    invalid_inline = %{
      "blocks" => [
        %{
          "kind" => "paragraph",
          "text" => [%{"kind" => "link", "text" => "bad", "url" => "javascript:alert(1)"}]
        }
      ]
    }

    assert {:error, [%{path: "card.blocks[0].text[0].url"}]} = Card.validate(invalid_inline)

    invalid_collage_caption = %{
      "blocks" => [
        %{
          "kind" => "collage",
          "items" => [
            %{
              "media_type" => "photo",
              "url" => "https://example.com/1.jpg",
              "caption" => [
                %{"kind" => "link", "text" => "bad", "url" => "javascript:alert(1)"}
              ]
            }
          ]
        }
      ]
    }

    assert {:error, [%{path: "card.blocks[0].items[0].caption[0].url"}]} =
             Card.validate(invalid_collage_caption)

    draft = %{"blocks" => [%{"kind" => "thinking", "text" => "Checking..."}]}
    assert {:error, [%{path: "card.blocks[0]"}]} = Card.validate(draft)
    assert :ok = Card.validate(draft, %{draft?: true})
  end

  test "card renderer covers expanded Bot API rich text and block aliases" do
    card = %{
      "blocks" => [
        %{"kind" => "anchor", "name" => "top"},
        %{
          "kind" => "paragraph",
          "text" => [
            %{"kind" => "email_address", "email_address" => "ops@example.com", "text" => "email"},
            " ",
            %{"kind" => "phone_number", "phone_number" => "+34123456789"},
            " ",
            %{"kind" => "mathematical_expression", "expression" => "x^2"},
            " ",
            %{"kind" => "hashtag", "hashtag" => "build"},
            " ",
            %{"kind" => "cashtag", "cashtag" => "GLR"},
            " ",
            %{"kind" => "bot_command", "bot_command" => "start"},
            " ",
            %{"kind" => "mention", "username" => "operator"},
            " ",
            %{"kind" => "anchor_link", "anchor_name" => "top", "text" => "top"},
            " ",
            %{"kind" => "reference", "reference_name" => "docs", "text" => "docs"},
            " ",
            %{"kind" => "reference_link", "reference_name" => "docs", "text" => "[1]"}
          ]
        },
        %{"kind" => "math", "expression" => "a+b=c"},
        %{
          "kind" => "list",
          "ordered" => true,
          "start" => 3,
          "list_type" => "A",
          "items" => [%{"text" => "third", "value" => 3}]
        },
        %{
          "kind" => "blockquote",
          "blocks" => [%{"kind" => "paragraph", "text" => "Nested"}],
          "credit" => "Credit"
        },
        %{
          "kind" => "collage",
          "blocks" => [
            %{"kind" => "media", "media_type" => "photo", "url" => "https://example.com/c.jpg"}
          ]
        },
        %{
          "kind" => "slideshow",
          "blocks" => [
            %{"kind" => "media", "media_type" => "photo", "url" => "https://example.com/s.jpg"}
          ]
        }
      ]
    }

    assert {:ok, %{html: html}} = Card.to_rich_message(card)

    assert html =~ ~s(<a name="top"></a>)
    assert html =~ ~s(<a href="mailto:ops@example.com">email</a>)
    assert html =~ ~s(<a href="tel:+34123456789">+34123456789</a>)
    assert html =~ ~s(<tg-math>x^2</tg-math>)
    assert html =~ "#build"
    assert html =~ "$GLR"
    assert html =~ "/start"
    assert html =~ "@operator"
    assert html =~ ~s(<a href="#top">top</a>)
    assert html =~ ~s(<tg-reference name="docs">docs</tg-reference>)
    assert html =~ ~s(<a href="#docs">[1]</a>)
    assert html =~ ~s(<tg-math-block>a+b=c</tg-math-block>)
    assert html =~ ~s(<ol start="3" type="A"><li value="3">third</li></ol>)
    assert html =~ ~s(<blockquote><p>Nested</p><cite>Credit</cite></blockquote>)
    assert html =~ ~s(<tg-collage><img src="https://example.com/c.jpg"/></tg-collage>)
    assert html =~ ~s(<tg-slideshow><img src="https://example.com/s.jpg"/></tg-slideshow>)

    invalid_email = %{
      "blocks" => [
        %{
          "kind" => "paragraph",
          "text" => [%{"kind" => "email_address", "email_address" => "not-email"}]
        }
      ]
    }

    assert {:error, [%{path: "card.blocks[0].text[0].email_address"}]} =
             Card.validate(invalid_email)

    invalid_anchor = %{"blocks" => [%{"kind" => "anchor", "name" => ""}]}
    assert {:error, [%{path: "card.blocks[0].name"}]} = Card.validate(invalid_anchor)
  end

  test "sender reports capabilities and validates cards without Telegram calls" do
    {:ok, fake} = Fake.start_link()
    {:ok, state} = sender(fake)

    {:reply, body, state} =
      Sender.handle_message(:telegram_ingress, %{"action" => "capabilities"}, state)

    assert Jason.decode!(body)["ok"] == true

    {:reply, body, _state} =
      Sender.handle_message(
        :telegram_ingress,
        %{
          "action" => "validate_card",
          "card" => %{
            "blocks" => [%{"kind" => "media", "media_type" => "photo", "url" => "ftp://x"}]
          }
        },
        state
      )

    decoded = Jason.decode!(body)
    assert decoded["ok"] == false
    assert hd(decoded["errors"])["path"] == "card.blocks[0].url"
    assert Fake.calls(fake) == []
  end

  test "sender returns structured invalid payload errors without Telegram calls" do
    {:ok, fake} = Fake.start_link()
    {:ok, state} = sender(fake)

    {:reply, body, state} =
      Sender.handle_message(
        :telegram_ingress,
        %{
          "action" => "send_media",
          "conversation_id" => "tg:123:0",
          "media_type" => "animation",
          "media" => ""
        },
        state
      )

    decoded = Jason.decode!(body)
    assert decoded["ok"] == false
    assert decoded["error"] == "invalid_payload"
    assert decoded["reason"] =~ "animation must be non-empty"

    {:reply, body, state} =
      Sender.handle_message(
        :telegram_ingress,
        %{
          "action" => "stream_text",
          "conversation_id" => "tg:123:0",
          "draft_id" => 0,
          "text" => "Working"
        },
        state
      )

    decoded = Jason.decode!(body)
    assert decoded["ok"] == false
    assert decoded["error"] == "invalid_payload"
    assert decoded["reason"] =~ "draft_id must be a non-zero integer"

    {:reply, body, state} =
      Sender.handle_message(
        :telegram_ingress,
        %{
          "action" => "stream_card",
          "conversation_id" => "tg:123:0",
          "draft_id" => 0,
          "card" => %{"blocks" => [%{"kind" => "thinking", "text" => "Working"}]}
        },
        state
      )

    decoded = Jason.decode!(body)
    assert decoded["ok"] == false
    assert decoded["error"] == "invalid_payload"
    assert decoded["reason"] =~ "draft_id must be a non-zero integer"

    {:reply, body, state} =
      Sender.handle_message(
        :telegram_ingress,
        %{
          "action" => "edit_card",
          "conversation_id" => "tg:123:0",
          "message_id" => "not-an-int",
          "card" => %{"blocks" => [%{"kind" => "paragraph", "text" => "Edited"}]}
        },
        state
      )

    decoded = Jason.decode!(body)
    assert decoded["ok"] == false
    assert decoded["error"] == "invalid_payload"
    assert decoded["reason"] =~ "message_id must be an integer"

    {:reply, body, _state} =
      Sender.handle_message(
        :telegram_ingress,
        %{
          "action" => "send_media_group",
          "conversation_id" => "tg:123:0",
          "media" => [%{"type" => "photo", "media" => "https://example.com/1.jpg"}]
        },
        state
      )

    decoded = Jason.decode!(body)
    assert decoded["ok"] == false
    assert decoded["error"] == "invalid_payload"
    assert decoded["reason"] =~ "media group must contain 2 to 10 items"
    assert Fake.calls(fake) == []
  end

  test "sender dispatches chat admin and forum actions through the client" do
    {:ok, fake} = Fake.start_link()

    state =
      Sender.new(%{client: Fake, client_opts: [fake: fake], action_grants: operator_grants()})

    {:noreply, state} =
      Sender.handle_message(
        :telegram_ingress,
        %{
          "action" => "ban_chat_member",
          "chat_id" => -100_123,
          "user_id" => "42",
          "revoke_messages" => true
        },
        state
      )

    {:noreply, state} =
      Sender.handle_message(
        :telegram_ingress,
        %{
          "action" => "answer_chat_join_request_query",
          "query_id" => "join-1",
          "result" => "approve"
        },
        state
      )

    {:noreply, state} =
      Sender.handle_message(
        :telegram_ingress,
        %{
          "action" => "create_forum_topic",
          "chat_id" => -100_123,
          "name" => "Support",
          "icon_color" => 7_322_096
        },
        state
      )

    {:noreply, _state} =
      Sender.handle_message(
        :telegram_ingress,
        %{"action" => "get_forum_topic_icon_stickers"},
        state
      )

    calls = Fake.calls(fake)

    assert Enum.map(calls, & &1.method) == [
             :ban_chat_member,
             :answer_chat_join_request_query,
             :create_forum_topic,
             :get_forum_topic_icon_stickers
           ]

    assert Enum.at(calls, 0).payload.user_id == 42
    assert Enum.at(calls, 1).payload.chat_join_request_query_id == "join-1"
    assert Enum.at(calls, 1).payload.result == "approve"
    assert Enum.at(calls, 2).payload.name == "Support"
    assert Enum.at(calls, 3).payload == %{}
  end

  test "sender dispatches utility and sticker actions through the client" do
    {:ok, fake} = Fake.start_link()

    state =
      Sender.new(%{client: Fake, client_opts: [fake: fake], action_grants: operator_grants()})

    {:noreply, state} =
      Sender.handle_message(
        :telegram_ingress,
        %{"action" => "get_file", "file_id" => "file-123"},
        state
      )

    {:noreply, state} =
      Sender.handle_message(
        :telegram_ingress,
        %{
          "action" => "create_new_sticker_set",
          "user_id" => 42,
          "name" => "wingston_by_bot",
          "title" => "Wingston",
          "stickers" => [
            %{"sticker" => "attach://sticker", "emoji_list" => ["🪽"], "format" => "static"}
          ],
          "sticker_type" => "regular"
        },
        state
      )

    {:noreply, _state} =
      Sender.handle_message(
        :telegram_ingress,
        %{"action" => "delete_sticker_set", "name" => "wingston_by_bot"},
        state
      )

    calls = Fake.calls(fake)

    assert Enum.map(calls, & &1.method) == [
             :get_file,
             :create_new_sticker_set,
             :delete_sticker_set
           ]

    assert Enum.at(calls, 0).payload.file_id == "file-123"
    assert Enum.at(calls, 1).payload.name == "wingston_by_bot"
    assert Enum.at(calls, 2).payload.name == "wingston_by_bot"
  end

  test "sender accepts safe reply markup beyond inline buttons" do
    {:ok, fake} = Fake.start_link()
    {:ok, state} = sender(fake)

    {:noreply, state} =
      Sender.handle_message(
        :telegram_ingress,
        %{
          "action" => "send",
          "conversation_id" => "tg:123:0",
          "text" => "Choose",
          "reply_markup" => %{
            "keyboard" => [
              ["Yes"],
              [%{"text" => "Location", "request_location" => true}]
            ],
            "resize_keyboard" => true
          }
        },
        state
      )

    {:noreply, _state} =
      Sender.handle_message(
        :telegram_ingress,
        %{
          "action" => "send",
          "conversation_id" => "tg:123:0",
          "text" => "Reply",
          "reply_markup" => %{"force_reply" => true, "input_field_placeholder" => "Answer"}
        },
        state
      )

    [keyboard, force_reply] = Fake.calls(fake)

    assert keyboard.payload.reply_markup == %{
             keyboard: [[%{text: "Yes"}], [%{text: "Location", request_location: true}]],
             resize_keyboard: true
           }

    assert force_reply.payload.reply_markup == %{
             force_reply: true,
             input_field_placeholder: "Answer"
           }
  end

  test "sender forces bound slots for rich actions and rejects unbound agent-like origins" do
    {:ok, fake} = Fake.start_link()

    {:ok, state} =
      Sender.init(%{
        bot_token: "token",
        client: Fake,
        client_opts: [fake: fake],
        binding_authority: :telegram_ingress,
        send_sources: [:telegram_ingress],
        slot_prefix: "telegram_agent",
        rate_per_sec: 1_000
      })

    {:noreply, state} =
      Sender.handle_message(
        :telegram_ingress,
        %{
          "action" => "bind_session",
          "slot" => "telegram_agent_0",
          "conversation_id" => "tg:123:0"
        },
        state
      )

    {:noreply, state} =
      Sender.handle_message(
        :telegram_agent_0,
        %{
          "action" => "send_card",
          "conversation_id" => "tg:999:0",
          "card" => %{"blocks" => [%{"kind" => "paragraph", "text" => "Bound"}]}
        },
        state
      )

    [call] = Fake.calls(fake)
    assert call.method == :send_rich_message
    assert call.payload.chat_id == "123"
    assert hd(state.sent).conversation_id == "tg:123:0"

    {:reply, body, _state} =
      Sender.handle_message(
        :telegram_agent_9,
        %{
          "action" => "stream_text",
          "conversation_id" => "tg:999:0",
          "draft_id" => 1,
          "text" => "no"
        },
        state
      )

    assert Jason.decode!(body)["ok"] == false
    assert length(Fake.calls(fake)) == 1
  end

  test "sender sends, streams, edits cards, media, structured messages, and raw rich messages" do
    {:ok, fake} =
      Fake.start_link([
        {:ok, %{"message_id" => 10}},
        {:ok, true},
        {:ok, true},
        {:ok, %{"message_id" => 10}},
        {:ok, %{"message_id" => 11}},
        {:ok, %{"message_id" => 12}},
        {:ok, %{"message_id" => 13}},
        {:ok, %{"message_id" => 14}},
        {:ok, %{"message_id" => 15}},
        {:ok, %{"message_id" => 16}},
        {:ok, %{"message_id" => 17}},
        {:ok, %{"message_id" => 18}},
        {:ok, [%{"message_id" => 19}, %{"message_id" => 20}]},
        {:ok, %{"message_id" => 21}}
      ])

    {:ok, state} = sender(fake)

    card = %{
      "title" => "Welcome",
      "blocks" => [
        %{"kind" => "paragraph", "text" => "Ready"},
        %{"kind" => "media", "media_type" => "animation", "url" => "https://example.com/a.mp4"}
      ],
      "buttons" => [[%{"text" => "Open", "url" => "https://example.com"}]]
    }

    {:noreply, state} =
      Sender.handle_message(
        :telegram_ingress,
        %{"action" => "send_card", "conversation_id" => "tg:123:0", "card" => card},
        state
      )

    {:noreply, state} =
      Sender.handle_message(
        :telegram_ingress,
        %{
          "action" => "stream_card",
          "conversation_id" => "tg:123:0",
          "draft_id" => 77,
          "card" => %{"blocks" => [%{"kind" => "thinking", "text" => "Working"}]}
        },
        state
      )

    {:noreply, state} =
      Sender.handle_message(
        :telegram_ingress,
        %{
          "action" => "stream_text",
          "conversation_id" => "tg:123:0",
          "draft_id" => 78,
          "text" => "Working"
        },
        state
      )

    {:noreply, state} =
      Sender.handle_message(
        :telegram_ingress,
        %{
          "action" => "send_video_note",
          "conversation_id" => "tg:123:0",
          "video_note" => "file-video-note"
        },
        state
      )

    {:noreply, state} =
      Sender.handle_message(
        :telegram_ingress,
        %{
          "action" => "send_live_photo",
          "conversation_id" => "tg:123:0",
          "live_photo" => "file-live",
          "photo" => "file-photo",
          "caption" => "Moment"
        },
        state
      )

    {:noreply, state} =
      Sender.handle_message(
        :telegram_ingress,
        %{
          "action" => "send_sticker",
          "conversation_id" => "tg:123:0",
          "sticker" => "file-sticker",
          "emoji" => "🪽"
        },
        state
      )

    {:noreply, state} =
      Sender.handle_message(
        :telegram_ingress,
        %{
          "action" => "send_media_group",
          "conversation_id" => "tg:123:0",
          "media" => [
            %{"type" => "photo", "media" => "https://example.com/1.jpg"},
            %{"type" => "photo", "media" => "https://example.com/2.jpg"}
          ]
        },
        state
      )

    {:noreply, state} =
      Sender.handle_message(
        :telegram_ingress,
        %{
          "action" => "edit_card",
          "conversation_id" => "tg:123:0",
          "message_id" => 10,
          "card" => %{
            "title" => "Edited",
            "blocks" => [%{"kind" => "paragraph", "text" => "Done"}]
          }
        },
        state
      )

    {:noreply, state} =
      Sender.handle_message(
        :telegram_ingress,
        %{
          "action" => "edit_message",
          "conversation_id" => "tg:123:0",
          "message_id" => 11,
          "text" => "Plain edit",
          "buttons" => [[%{"text" => "Open", "url" => "https://example.com"}]]
        },
        state
      )

    {:noreply, state} =
      Sender.handle_message(
        :telegram_ingress,
        %{
          "action" => "edit_caption",
          "conversation_id" => "tg:123:0",
          "message_id" => 12,
          "caption" => "Caption edit"
        },
        state
      )

    {:noreply, state} =
      Sender.handle_message(
        :telegram_ingress,
        %{
          "action" => "edit_reply_markup",
          "conversation_id" => "tg:123:0",
          "message_id" => 13,
          "buttons" => [[%{"text" => "Done", "action" => "done"}]]
        },
        state
      )

    {:noreply, state} =
      Sender.handle_message(
        :telegram_ingress,
        %{
          "action" => "stop_poll",
          "conversation_id" => "tg:123:0",
          "message_id" => 14
        },
        state
      )

    {:noreply, state} =
      Sender.handle_message(
        :telegram_ingress,
        %{
          "action" => "send_media",
          "conversation_id" => "tg:123:0",
          "media_type" => "animation",
          "media" => "https://example.com/a.mp4",
          "caption" => "Boot"
        },
        state
      )

    {:noreply, state} =
      Sender.handle_message(
        :telegram_ingress,
        %{
          "action" => "send_poll",
          "conversation_id" => "tg:123:0",
          "question" => "Pick",
          "options" => ["A", "B"],
          "is_anonymous" => false
        },
        state
      )

    {:noreply, state} =
      Sender.handle_message(
        :telegram_ingress,
        %{
          "action" => "send_location",
          "conversation_id" => "tg:123:0",
          "latitude" => "41.3874",
          "longitude" => "2.1686"
        },
        state
      )

    {:noreply, state} =
      Sender.handle_message(
        :telegram_ingress,
        %{
          "action" => "send_venue",
          "conversation_id" => "tg:123:0",
          "latitude" => 41.3874,
          "longitude" => 2.1686,
          "title" => "Example HQ",
          "address" => "Barcelona"
        },
        state
      )

    {:noreply, state} =
      Sender.handle_message(
        :telegram_ingress,
        %{
          "action" => "send_contact",
          "conversation_id" => "tg:123:0",
          "phone_number" => "+34123456789",
          "first_name" => "Example"
        },
        state
      )

    {:noreply, state} =
      Sender.handle_message(
        :telegram_ingress,
        %{
          "action" => "send_dice",
          "conversation_id" => "tg:123:0",
          "emoji" => "🎲"
        },
        state
      )

    {:noreply, state} =
      Sender.handle_message(
        :telegram_ingress,
        %{
          "action" => "send_chat_action",
          "conversation_id" => "tg:123:0",
          "chat_action" => "upload_photo"
        },
        state
      )

    {:noreply, state} =
      Sender.handle_message(
        :telegram_ingress,
        %{
          "action" => "set_reaction",
          "conversation_id" => "tg:123:0",
          "message_id" => 123,
          "reaction" => "👍",
          "is_big" => true
        },
        state
      )

    {:noreply, _state} =
      Sender.handle_message(
        :telegram_ingress,
        %{
          "action" => "send_rich_raw",
          "conversation_id" => "tg:123:0",
          "rich_message" => %{"html" => "<h3>Raw</h3>"}
        },
        state
      )

    calls = Fake.calls(fake)

    assert Enum.map(calls, & &1.method) == [
             :send_rich_message,
             :send_rich_message_draft,
             :send_message_draft,
             :send_video_note,
             :send_live_photo,
             :send_sticker,
             :send_media_group,
             :edit_message_text,
             :edit_message_text,
             :edit_message_caption,
             :edit_message_reply_markup,
             :stop_poll,
             :send_animation,
             :send_poll,
             :send_location,
             :send_venue,
             :send_contact,
             :send_dice,
             :send_chat_action,
             :set_message_reaction,
             :send_rich_message
           ]

    [send_card | _] = calls
    refute Map.has_key?(send_card.payload, :_method)
    assert send_card.payload.rich_message.html =~ "<h3>Welcome</h3>"

    assert send_card.payload.reply_markup.inline_keyboard == [
             [%{text: "Open", url: "https://example.com"}]
           ]

    draft = Enum.at(calls, 1)
    assert draft.payload.draft_id == 77
    assert draft.payload.rich_message.html =~ "<tg-thinking>Working</tg-thinking>"

    text_draft = Enum.at(calls, 2)
    assert text_draft.payload.draft_id == 78
    assert text_draft.payload.text == "Working"
    assert text_draft.payload.parse_mode == "HTML"

    video_note = Enum.at(calls, 3)
    assert video_note.payload.video_note == "file-video-note"

    live_photo = Enum.at(calls, 4)
    assert live_photo.payload.live_photo == "file-live"
    assert live_photo.payload.photo == "file-photo"

    sticker = Enum.at(calls, 5)
    assert sticker.payload.sticker == "file-sticker"
    assert sticker.payload.emoji == "🪽"

    media_group = Enum.at(calls, 6)
    assert length(media_group.payload.media) == 2

    edit_message = Enum.at(calls, 8)
    assert edit_message.payload.text == "Plain edit"

    assert edit_message.payload.reply_markup.inline_keyboard == [
             [%{text: "Open", url: "https://example.com"}]
           ]

    edit_caption = Enum.at(calls, 9)
    assert edit_caption.payload.caption == "Caption edit"

    edit_reply_markup = Enum.at(calls, 10)

    assert edit_reply_markup.payload.reply_markup.inline_keyboard == [
             [%{text: "Done", callback_data: "done"}]
           ]

    stop_poll = Enum.at(calls, 11)
    assert stop_poll.payload.message_id == 14

    media = Enum.at(calls, 12)
    assert media.payload.animation == "https://example.com/a.mp4"
    assert media.payload.caption == "Boot"

    poll = Enum.at(calls, 13)
    assert poll.payload.is_anonymous == false

    location = Enum.at(calls, 14)
    assert location.payload.latitude == 41.3874
    assert location.payload.longitude == 2.1686

    venue = Enum.at(calls, 15)
    assert venue.payload.title == "Example HQ"
    assert venue.payload.address == "Barcelona"

    contact = Enum.at(calls, 16)
    assert contact.payload.phone_number == "+34123456789"
    assert contact.payload.first_name == "Example"

    dice = Enum.at(calls, 17)
    assert dice.payload.emoji == "🎲"

    chat_action = Enum.at(calls, 18)
    assert chat_action.payload.action == "upload_photo"

    reaction = Enum.at(calls, 19)
    assert reaction.payload.message_id == 123
    assert reaction.payload.reaction == [%{type: "emoji", emoji: "👍"}]
    assert reaction.payload.is_big == true
  end

  test "sender dispatches inline and web-app query actions" do
    {:ok, fake} = Fake.start_link()
    {:ok, state} = sender(fake)

    inline_result = %{
      "type" => "article",
      "id" => "result-1",
      "title" => "Status",
      "input_message_content" => %{"message_text" => "Ready"}
    }

    actions = [
      %{
        "action" => "answer_callback",
        "callback_query_id" => "cb-1",
        "text" => "Done"
      },
      %{
        "action" => "answer_web_app",
        "web_app_query_id" => "web-1",
        "result" => inline_result
      },
      %{
        "action" => "answer_inline_query",
        "inline_query_id" => "inline-1",
        "results" => [inline_result]
      },
      %{
        "action" => "save_prepared_inline_message",
        "user_id" => 123,
        "result" => inline_result,
        "allow_user_chats" => true
      },
      %{
        "action" => "save_prepared_keyboard_button",
        "user_id" => 123,
        "button" => %{
          "text" => "Choose user",
          "request_users" => %{"request_id" => 1}
        }
      }
    ]

    final_state =
      Enum.reduce(actions, state, fn action, acc ->
        assert {:noreply, next} = Sender.handle_message(:telegram_ingress, action, acc)
        next
      end)

    calls = Fake.calls(fake)

    assert Enum.map(calls, & &1.method) == [
             :answer_callback_query,
             :answer_web_app_query,
             :answer_inline_query,
             :save_prepared_inline_message,
             :save_prepared_keyboard_button
           ]

    assert Enum.at(calls, 0).payload.callback_query_id == "cb-1"
    assert Enum.at(calls, 1).payload.result.type == "article"
    assert Enum.at(calls, 2).payload.results == [Enum.at(calls, 1).payload.result]
    assert Enum.at(calls, 3).payload.allow_user_chats == true
    assert Enum.at(calls, 4).payload.button.request_users == %{"request_id" => 1}
    assert length(final_state.sent) == 5
  end

  test "sender dispatches utility, managed bot, passport, suggested post, and game actions" do
    {:ok, fake} = Fake.start_link()
    {:ok, state} = sender(fake)

    inline_result = %{
      "type" => "article",
      "id" => "result-1",
      "title" => "Status",
      "input_message_content" => %{"message_text" => "Ready"}
    }

    actions = [
      %{
        "action" => "answer_guest_query",
        "guest_query_id" => "guest-1",
        "result" => inline_result
      },
      %{"action" => "get_user_chat_boosts", "chat_id" => "@channel", "user_id" => 123},
      %{"action" => "get_business_connection", "business_connection_id" => "biz-1"},
      %{"action" => "get_managed_bot_token", "user_id" => 123},
      %{"action" => "replace_managed_bot_token", "user_id" => 123},
      %{"action" => "get_managed_bot_access_settings", "user_id" => 123},
      %{
        "action" => "set_managed_bot_access_settings",
        "user_id" => 123,
        "is_access_restricted" => true,
        "added_user_ids" => [456]
      },
      %{"action" => "get_user_personal_chat_messages", "user_id" => 123, "limit" => 5},
      %{"action" => "approve_suggested_post", "chat_id" => 123, "message_id" => 44},
      %{
        "action" => "decline_suggested_post",
        "chat_id" => 123,
        "message_id" => 45,
        "comment" => "Needs changes"
      },
      %{
        "action" => "set_passport_data_errors",
        "user_id" => 123,
        "errors" => [
          %{
            "source" => "data",
            "type" => "personal_details",
            "field_name" => "first_name",
            "data_hash" => "hash",
            "message" => "Invalid name"
          }
        ]
      },
      %{
        "action" => "set_game_score",
        "user_id" => 123,
        "score" => 42,
        "chat_id" => "@gamechat",
        "message_id" => 46
      },
      %{
        "action" => "get_game_high_scores",
        "user_id" => 123,
        "inline_message_id" => "inline-game"
      }
    ]

    final_state =
      Enum.reduce(actions, state, fn action, acc ->
        assert {:noreply, next} = Sender.handle_message(:telegram_ingress, action, acc)
        next
      end)

    calls = Fake.calls(fake)

    assert Enum.map(calls, & &1.method) == [
             :answer_guest_query,
             :get_user_chat_boosts,
             :get_business_connection,
             :get_managed_bot_token,
             :replace_managed_bot_token,
             :get_managed_bot_access_settings,
             :set_managed_bot_access_settings,
             :get_user_personal_chat_messages,
             :approve_suggested_post,
             :decline_suggested_post,
             :set_passport_data_errors,
             :set_game_score,
             :get_game_high_scores
           ]

    assert Enum.at(calls, 0).payload.result.type == "article"
    assert Enum.at(calls, 6).payload.added_user_ids == [456]
    assert Enum.at(calls, 7).payload.limit == 5
    assert Enum.at(calls, 9).payload.comment == "Needs changes"
    assert Enum.at(calls, 10).payload.errors |> hd() |> Map.get(:source) == "data"
    assert Enum.at(calls, 11).payload.score == 42
    assert Enum.at(calls, 12).payload.inline_message_id == "inline-game"
    assert length(final_state.sent) == 13
  end

  test "sender dispatches bot profile and configuration actions" do
    {:ok, fake} = Fake.start_link()
    {:ok, state} = sender(fake)

    actions = [
      %{
        "action" => "set_my_commands",
        "commands" => [%{"command" => "start", "description" => "Start the bot"}]
      },
      %{"action" => "delete_my_commands", "language_code" => "en"},
      %{"action" => "get_my_commands", "scope" => %{"type" => "default"}},
      %{"action" => "set_my_name", "name" => "Wingston"},
      %{"action" => "get_my_name", "language_code" => "en"},
      %{"action" => "set_my_description", "description" => "Rally assistant"},
      %{"action" => "get_my_description"},
      %{"action" => "set_my_short_description", "short_description" => "Rally assistant"},
      %{"action" => "get_my_short_description"},
      %{
        "action" => "set_my_profile_photo",
        "photo" => %{"type" => "static", "photo" => "attach://profile"}
      },
      %{"action" => "remove_my_profile_photo"},
      %{
        "action" => "set_chat_menu_button",
        "chat_id" => 123,
        "menu_button" => %{"type" => "commands"}
      },
      %{"action" => "get_chat_menu_button", "chat_id" => 123},
      %{
        "action" => "set_my_default_administrator_rights",
        "rights" => %{"can_delete_messages" => true},
        "for_channels" => true
      },
      %{"action" => "get_my_default_administrator_rights", "for_channels" => false}
    ]

    final_state =
      Enum.reduce(actions, state, fn action, acc ->
        assert {:noreply, next} = Sender.handle_message(:telegram_ingress, action, acc)
        next
      end)

    calls = Fake.calls(fake)

    assert Enum.map(calls, & &1.method) == [
             :set_my_commands,
             :delete_my_commands,
             :get_my_commands,
             :set_my_name,
             :get_my_name,
             :set_my_description,
             :get_my_description,
             :set_my_short_description,
             :get_my_short_description,
             :set_my_profile_photo,
             :remove_my_profile_photo,
             :set_chat_menu_button,
             :get_chat_menu_button,
             :set_my_default_administrator_rights,
             :get_my_default_administrator_rights
           ]

    assert Enum.at(calls, 0).payload.commands == [
             %{command: "start", description: "Start the bot"}
           ]

    assert Enum.at(calls, 3).payload.name == "Wingston"
    assert Enum.at(calls, 9).payload.photo == %{"type" => "static", "photo" => "attach://profile"}
    assert Enum.at(calls, 10).payload == %{}
    assert Enum.at(calls, 11).payload.menu_button == %{"type" => "commands"}
    assert Enum.at(calls, 13).payload.rights == %{"can_delete_messages" => true}
    assert length(final_state.sent) == 15
  end

  test "sender dispatches payment lifecycle actions" do
    {:ok, fake} = Fake.start_link()
    {:ok, state} = sender(fake)

    actions = [
      %{
        "action" => "create_invoice_link",
        "title" => "Access",
        "description" => "Premium",
        "payload" => "invoice-link-1",
        "currency" => "XTR",
        "prices" => [%{"label" => "Access", "amount" => 5}]
      },
      %{
        "action" => "answer_shipping_query",
        "shipping_query_id" => "ship-1",
        "ok" => true,
        "shipping_options" => [
          %{
            "id" => "standard",
            "title" => "Standard",
            "prices" => [%{"label" => "Shipping", "amount" => 1}]
          }
        ]
      },
      %{
        "action" => "answer_pre_checkout_query",
        "pre_checkout_query_id" => "pre-1",
        "ok" => true
      },
      %{
        "action" => "refund_star_payment",
        "user_id" => 123,
        "telegram_payment_charge_id" => "charge-1"
      },
      %{
        "action" => "edit_user_star_subscription",
        "user_id" => 123,
        "telegram_payment_charge_id" => "charge-2",
        "is_canceled" => true
      }
    ]

    final_state =
      Enum.reduce(actions, state, fn action, acc ->
        assert {:noreply, next} = Sender.handle_message(:telegram_ingress, action, acc)
        next
      end)

    calls = Fake.calls(fake)

    assert Enum.map(calls, & &1.method) == [
             :create_invoice_link,
             :answer_shipping_query,
             :answer_pre_checkout_query,
             :refund_star_payment,
             :edit_user_star_subscription
           ]

    assert Enum.at(calls, 0).payload.currency == "XTR"
    assert Enum.at(calls, 1).payload.shipping_options |> hd() |> Map.get(:id) == "standard"
    assert Enum.at(calls, 2).payload.ok == true
    assert Enum.at(calls, 3).payload.telegram_payment_charge_id == "charge-1"
    assert Enum.at(calls, 4).payload.is_canceled == true
    assert length(final_state.sent) == 5
  end

  test "sender dispatches Stars and Gifts actions" do
    {:ok, fake} = Fake.start_link()
    {:ok, state} = sender(fake)

    actions = [
      %{"action" => "get_my_star_balance"},
      %{"action" => "get_star_transactions", "offset" => 1, "limit" => 10},
      %{"action" => "get_available_gifts"},
      %{"action" => "send_gift", "user_id" => 123, "gift_id" => "gift-1"},
      %{
        "action" => "gift_premium_subscription",
        "user_id" => 123,
        "month_count" => 3,
        "star_count" => 1000
      },
      %{"action" => "get_business_account_star_balance", "business_connection_id" => "biz-1"},
      %{
        "action" => "transfer_business_account_stars",
        "business_connection_id" => "biz-1",
        "star_count" => 25
      },
      %{
        "action" => "get_business_account_gifts",
        "business_connection_id" => "biz-1",
        "limit" => 5
      },
      %{"action" => "get_user_gifts", "user_id" => 123, "exclude_unique" => true},
      %{"action" => "get_chat_gifts", "chat_id" => "@channel", "sort_by_price" => true},
      %{
        "action" => "convert_gift_to_stars",
        "business_connection_id" => "biz-1",
        "owned_gift_id" => "owned-1"
      },
      %{
        "action" => "upgrade_gift",
        "business_connection_id" => "biz-1",
        "owned_gift_id" => "owned-2",
        "star_count" => 0
      },
      %{
        "action" => "transfer_gift",
        "business_connection_id" => "biz-1",
        "owned_gift_id" => "owned-3",
        "new_owner_chat_id" => 456,
        "star_count" => 5
      }
    ]

    final_state =
      Enum.reduce(actions, state, fn action, acc ->
        assert {:noreply, next} = Sender.handle_message(:telegram_ingress, action, acc)
        next
      end)

    calls = Fake.calls(fake)

    assert Enum.map(calls, & &1.method) == [
             :get_my_star_balance,
             :get_star_transactions,
             :get_available_gifts,
             :send_gift,
             :gift_premium_subscription,
             :get_business_account_star_balance,
             :transfer_business_account_stars,
             :get_business_account_gifts,
             :get_user_gifts,
             :get_chat_gifts,
             :convert_gift_to_stars,
             :upgrade_gift,
             :transfer_gift
           ]

    assert Enum.at(calls, 0).payload == %{}
    assert Enum.at(calls, 1).payload.limit == 10
    assert Enum.at(calls, 3).payload.gift_id == "gift-1"
    assert Enum.at(calls, 4).payload.star_count == 1000
    assert Enum.at(calls, 6).payload.star_count == 25
    assert Enum.at(calls, 7).payload.business_connection_id == "biz-1"
    assert Enum.at(calls, 8).payload.exclude_unique == true
    assert Enum.at(calls, 9).payload.sort_by_price == true
    assert Enum.at(calls, 12).payload.new_owner_chat_id == 456
    assert length(final_state.sent) == 13
  end

  test "sender dispatches business and verification actions" do
    {:ok, fake} = Fake.start_link()
    {:ok, state} = sender(fake)

    actions = [
      %{"action" => "verify_user", "user_id" => 123, "custom_description" => "Official"},
      %{"action" => "verify_chat", "chat_id" => "@channel"},
      %{"action" => "remove_user_verification", "user_id" => 123},
      %{"action" => "remove_chat_verification", "chat_id" => "@channel"},
      %{
        "action" => "read_business_message",
        "business_connection_id" => "biz-1",
        "chat_id" => 456,
        "message_id" => 10
      },
      %{
        "action" => "delete_business_messages",
        "business_connection_id" => "biz-1",
        "message_ids" => [11, 12]
      },
      %{
        "action" => "set_business_account_name",
        "business_connection_id" => "biz-1",
        "first_name" => "Wingston"
      },
      %{
        "action" => "set_business_account_username",
        "business_connection_id" => "biz-1",
        "username" => "wingston"
      },
      %{
        "action" => "set_business_account_bio",
        "business_connection_id" => "biz-1",
        "bio" => "Rally assistant"
      },
      %{
        "action" => "set_business_account_profile_photo",
        "business_connection_id" => "biz-1",
        "photo" => %{"type" => "static", "photo" => "attach://profile-photo"},
        "is_public" => true
      },
      %{
        "action" => "remove_business_account_profile_photo",
        "business_connection_id" => "biz-1",
        "is_public" => false
      },
      %{
        "action" => "set_business_account_gift_settings",
        "business_connection_id" => "biz-1",
        "show_gift_button" => true,
        "accepted_gift_types" => %{
          "unlimited_gifts" => true,
          "limited_gifts" => false,
          "unique_gifts" => true,
          "premium_subscription" => false
        }
      }
    ]

    final_state =
      Enum.reduce(actions, state, fn action, acc ->
        assert {:noreply, next} = Sender.handle_message(:telegram_ingress, action, acc)
        next
      end)

    calls = Fake.calls(fake)

    assert Enum.map(calls, & &1.method) == [
             :verify_user,
             :verify_chat,
             :remove_user_verification,
             :remove_chat_verification,
             :read_business_message,
             :delete_business_messages,
             :set_business_account_name,
             :set_business_account_username,
             :set_business_account_bio,
             :set_business_account_profile_photo,
             :remove_business_account_profile_photo,
             :set_business_account_gift_settings
           ]

    assert Enum.at(calls, 0).payload.custom_description == "Official"
    assert Enum.at(calls, 4).payload.message_id == 10
    assert Enum.at(calls, 5).payload.message_ids == [11, 12]
    assert Enum.at(calls, 6).payload.first_name == "Wingston"

    assert Enum.at(calls, 9).payload.photo == %{
             "type" => "static",
             "photo" => "attach://profile-photo"
           }

    assert Enum.at(calls, 11).payload.accepted_gift_types.unique_gifts == true
    assert length(final_state.sent) == 12
  end

  test "sender dispatches story actions" do
    {:ok, fake} = Fake.start_link()
    {:ok, state} = sender(fake)

    actions = [
      %{
        "action" => "post_story",
        "business_connection_id" => "biz-1",
        "content" => %{"type" => "photo", "photo" => "attach://story-photo"},
        "active_period" => 86_400,
        "caption" => "Launch"
      },
      %{
        "action" => "repost_story",
        "business_connection_id" => "biz-1",
        "from_chat_id" => -100,
        "from_story_id" => 12,
        "active_period" => 43_200
      },
      %{
        "action" => "edit_story",
        "business_connection_id" => "biz-1",
        "story_id" => 13,
        "content" => %{"type" => "video", "video" => "attach://story-video"}
      },
      %{
        "action" => "delete_story",
        "business_connection_id" => "biz-1",
        "story_id" => 14
      }
    ]

    final_state =
      Enum.reduce(actions, state, fn action, acc ->
        assert {:noreply, next} = Sender.handle_message(:telegram_ingress, action, acc)
        next
      end)

    calls = Fake.calls(fake)

    assert Enum.map(calls, & &1.method) == [
             :post_story,
             :repost_story,
             :edit_story,
             :delete_story
           ]

    assert Enum.at(calls, 0).payload.content == %{type: "photo", photo: "attach://story-photo"}
    assert Enum.at(calls, 1).payload.from_story_id == 12
    assert Enum.at(calls, 2).payload.content.video == "attach://story-video"
    assert Enum.at(calls, 3).payload.story_id == 14
    assert length(final_state.sent) == 4
  end

  test "sender dispatches lifecycle and native edit actions" do
    {:ok, fake} = Fake.start_link()
    {:ok, state} = sender(fake)

    actions = [
      %{
        "action" => "copy_message",
        "conversation_id" => "tg:123:0",
        "from_chat_id" => "@source",
        "message_id" => 20
      },
      %{
        "action" => "copy_messages",
        "conversation_id" => "tg:123:0",
        "from_chat_id" => "@source",
        "message_ids" => [21, 22]
      },
      %{
        "action" => "forward_message",
        "conversation_id" => "tg:123:0",
        "from_chat_id" => "@source",
        "message_id" => 23
      },
      %{
        "action" => "forward_messages",
        "conversation_id" => "tg:123:0",
        "from_chat_id" => "@source",
        "message_ids" => [24, 25]
      },
      %{
        "action" => "edit_media",
        "conversation_id" => "tg:123:0",
        "message_id" => 26,
        "media_type" => "photo",
        "media" => "file-photo"
      },
      %{
        "action" => "edit_live_location",
        "conversation_id" => "tg:123:0",
        "message_id" => 27,
        "latitude" => 41.38,
        "longitude" => 2.17
      },
      %{
        "action" => "edit_checklist",
        "conversation_id" => "tg:123:0",
        "message_id" => 27,
        "business_connection_id" => "biz-1",
        "title" => "Updated",
        "tasks" => ["Done"]
      },
      %{
        "action" => "stop_live_location",
        "conversation_id" => "tg:123:0",
        "message_id" => 28
      },
      %{
        "action" => "send_checklist",
        "conversation_id" => "tg:123:0",
        "business_connection_id" => "biz-1",
        "title" => "Launch",
        "tasks" => ["Draft", "Review"]
      },
      %{
        "action" => "send_paid_media",
        "conversation_id" => "tg:123:0",
        "star_count" => 5,
        "media" => [%{"type" => "photo", "media" => "file-paid-photo"}]
      },
      %{
        "action" => "send_invoice",
        "conversation_id" => "tg:123:0",
        "title" => "Access",
        "description" => "Premium",
        "payload" => "invoice-1",
        "currency" => "XTR",
        "prices" => [%{"label" => "Access", "amount" => 5}],
        "buttons" => [[%{"text" => "Pay", "pay" => true}]]
      },
      %{
        "action" => "send_game",
        "conversation_id" => "tg:123:0",
        "game_short_name" => "rally_quest"
      },
      %{
        "action" => "delete_message",
        "conversation_id" => "tg:123:0",
        "message_id" => 29
      },
      %{
        "action" => "delete_messages",
        "conversation_id" => "tg:123:0",
        "message_ids" => [30, 31]
      }
    ]

    final_state =
      Enum.reduce(actions, state, fn action, acc ->
        assert {:noreply, next} = Sender.handle_message(:telegram_ingress, action, acc)
        next
      end)

    calls = Fake.calls(fake)

    assert Enum.map(calls, & &1.method) == [
             :copy_message,
             :copy_messages,
             :forward_message,
             :forward_messages,
             :edit_message_media,
             :edit_message_live_location,
             :edit_message_checklist,
             :stop_message_live_location,
             :send_checklist,
             :send_paid_media,
             :send_invoice,
             :send_game,
             :delete_message,
             :delete_messages
           ]

    assert Enum.at(calls, 0).payload.from_chat_id == "@source"
    assert Enum.at(calls, 1).payload.message_ids == [21, 22]
    assert Enum.at(calls, 4).payload.media == %{type: "photo", media: "file-photo"}
    assert Enum.at(calls, 5).payload.latitude == 41.38
    assert Enum.at(calls, 6).payload.checklist.tasks == [%{id: 1, text: "Done"}]

    assert Enum.at(calls, 8).payload.checklist.tasks == [
             %{id: 1, text: "Draft"},
             %{id: 2, text: "Review"}
           ]

    assert Enum.at(calls, 9).payload.star_count == 5
    assert Enum.at(calls, 10).payload.currency == "XTR"
    assert Enum.at(calls, 11).payload.game_short_name == "rally_quest"
    assert Enum.at(calls, 13).payload.message_ids == [30, 31]
    assert length(final_state.sent) == 14
  end

  defp sender(fake) do
    Sender.init(%{
      bot_token: "token",
      client: Fake,
      client_opts: [fake: fake],
      binding_authority: :telegram_ingress,
      send_sources: [:telegram_ingress],
      progress_sources: [:telegram_ingress],
      action_grants: operator_grants(),
      rate_per_sec: 1_000
    })
  end

  defp operator_grants(source \\ :telegram_ingress) do
    %{
      chat_admin: [source],
      message_ops: [source],
      payments: [source],
      gifts: [source],
      business: [source],
      stories: [source],
      stickers_mgmt: [source],
      bot_profile: [source],
      managed_bots: [source],
      inline: [source],
      verification: [source],
      passport: [source],
      games: [source],
      utility: [source],
      infra: [source]
    }
  end
end

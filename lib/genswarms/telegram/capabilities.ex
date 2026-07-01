defmodule Genswarms.Telegram.Capabilities do
  @moduledoc """
  Machine-readable Telegram capabilities exposed by this package.

  The sender-facing catalog is intentionally smaller than Telegram's full Bot
  API. It lists the operations that are currently agent-safe in the package and
  separately names areas that need host-level policy or credentials before an
  agent should be allowed to use them.
  """

  @agent_actions ~w(
    capabilities
    examples
    validate_card
    stream_text
    answer_callback
    answer_web_app
    answer_inline_query
    answer_guest_query
    save_prepared_inline_message
    save_prepared_keyboard_button
    get_user_chat_boosts
    get_business_connection
    get_managed_bot_token
    replace_managed_bot_token
    get_managed_bot_access_settings
    set_managed_bot_access_settings
    get_user_personal_chat_messages
    set_my_commands
    delete_my_commands
    get_my_commands
    set_my_name
    get_my_name
    set_my_description
    get_my_description
    set_my_short_description
    get_my_short_description
    set_my_profile_photo
    remove_my_profile_photo
    set_chat_menu_button
    get_chat_menu_button
    set_my_default_administrator_rights
    get_my_default_administrator_rights
    create_invoice_link
    answer_shipping_query
    answer_pre_checkout_query
    get_my_star_balance
    get_star_transactions
    get_available_gifts
    send_gift
    gift_premium_subscription
    get_business_account_star_balance
    transfer_business_account_stars
    get_business_account_gifts
    get_user_gifts
    get_chat_gifts
    convert_gift_to_stars
    upgrade_gift
    transfer_gift
    verify_user
    verify_chat
    remove_user_verification
    remove_chat_verification
    read_business_message
    delete_business_messages
    set_business_account_name
    set_business_account_username
    set_business_account_bio
    set_business_account_profile_photo
    remove_business_account_profile_photo
    set_business_account_gift_settings
    approve_suggested_post
    decline_suggested_post
    set_passport_data_errors
    set_game_score
    get_game_high_scores
    refund_star_payment
    edit_user_star_subscription
    post_story
    repost_story
    edit_story
    delete_story
    send_card
    stream_card
    edit_card
    edit_message
    edit_caption
    edit_media
    edit_live_location
    stop_live_location
    edit_checklist
    edit_reply_markup
    stop_poll
    copy_message
    copy_messages
    forward_message
    forward_messages
    delete_message
    delete_messages
    send_media
    send_video_note
    send_live_photo
    send_sticker
    send_media_group
    send_paid_media
    send_poll
    send_checklist
    send_invoice
    send_game
    send_location
    send_venue
    send_contact
    send_dice
    send_chat_action
    set_reaction
    send_rich_raw
  )

  @chat_admin_actions ~w(
    delete_message_reaction
    delete_all_message_reactions
    ban_chat_member
    unban_chat_member
    restrict_chat_member
    promote_chat_member
    set_chat_administrator_custom_title
    set_chat_member_tag
    ban_chat_sender_chat
    unban_chat_sender_chat
    set_chat_permissions
    export_chat_invite_link
    create_chat_invite_link
    edit_chat_invite_link
    create_chat_subscription_invite_link
    edit_chat_subscription_invite_link
    revoke_chat_invite_link
    approve_chat_join_request
    decline_chat_join_request
    answer_chat_join_request_query
    send_chat_join_request_web_app
    set_chat_photo
    delete_chat_photo
    set_chat_title
    set_chat_description
    pin_chat_message
    unpin_chat_message
    unpin_all_chat_messages
    leave_chat
    get_chat
    get_chat_administrators
    get_chat_member_count
    get_chat_member
    set_chat_sticker_set
    delete_chat_sticker_set
    get_forum_topic_icon_stickers
    create_forum_topic
    edit_forum_topic
    close_forum_topic
    reopen_forum_topic
    delete_forum_topic
    unpin_all_forum_topic_messages
    edit_general_forum_topic
    close_general_forum_topic
    reopen_general_forum_topic
    hide_general_forum_topic
    unhide_general_forum_topic
    unpin_all_general_forum_topic_messages
  )

  @chat_admin_client_methods ~w(
    deleteMessageReaction
    deleteAllMessageReactions
    banChatMember
    unbanChatMember
    restrictChatMember
    promoteChatMember
    setChatAdministratorCustomTitle
    setChatMemberTag
    banChatSenderChat
    unbanChatSenderChat
    setChatPermissions
    exportChatInviteLink
    createChatInviteLink
    editChatInviteLink
    createChatSubscriptionInviteLink
    editChatSubscriptionInviteLink
    revokeChatInviteLink
    approveChatJoinRequest
    declineChatJoinRequest
    answerChatJoinRequestQuery
    sendChatJoinRequestWebApp
    setChatPhoto
    deleteChatPhoto
    setChatTitle
    setChatDescription
    pinChatMessage
    unpinChatMessage
    unpinAllChatMessages
    leaveChat
    getChat
    getChatAdministrators
    getChatMemberCount
    getChatMember
    setChatStickerSet
    deleteChatStickerSet
    getForumTopicIconStickers
    createForumTopic
    editForumTopic
    closeForumTopic
    reopenForumTopic
    deleteForumTopic
    unpinAllForumTopicMessages
    editGeneralForumTopic
    closeGeneralForumTopic
    reopenGeneralForumTopic
    hideGeneralForumTopic
    unhideGeneralForumTopic
    unpinAllGeneralForumTopicMessages
  )

  @utility_actions ~w(
    get_user_profile_photos
    get_user_profile_audios
    set_user_emoji_status
    get_file
  )

  @utility_client_methods ~w(
    close
    logOut
    getUserProfileAudios
    getUserProfilePhotos
    getFile
    setUserEmojiStatus
  )

  @infrastructure_client_methods ~w(
    deleteWebhook
    getMe
    getUpdates
    getWebhookInfo
    setWebhook
  )

  @sticker_actions ~w(
    get_sticker_set
    get_custom_emoji_stickers
    upload_sticker_file
    create_new_sticker_set
    add_sticker_to_set
    set_sticker_position_in_set
    delete_sticker_from_set
    replace_sticker_in_set
    set_sticker_emoji_list
    set_sticker_keywords
    set_sticker_mask_position
    set_sticker_set_title
    set_sticker_set_thumbnail
    set_custom_emoji_sticker_set_thumbnail
    delete_sticker_set
  )

  @sticker_client_methods ~w(
    getStickerSet
    getCustomEmojiStickers
    uploadStickerFile
    createNewStickerSet
    addStickerToSet
    setStickerPositionInSet
    deleteStickerFromSet
    replaceStickerInSet
    setStickerEmojiList
    setStickerKeywords
    setStickerMaskPosition
    setStickerSetTitle
    setStickerSetThumbnail
    setCustomEmojiStickerSetThumbnail
    deleteStickerSet
  )

  @rich_blocks ~w(
    heading
    paragraph
    list
    checklist
    table
    details
    quote
    blockquote
    pullquote
    code
    pre
    footer
    divider
    mathematical_expression
    anchor
    media
    collage
    slideshow
    references
    time
    map
  )

  @media_kinds ~w(photo live_photo video animation audio voice voice_note document sticker media_group)

  @doc "Capabilities that the sender object exposes to agents today."
  def sender do
    %{
      actions: @agent_actions ++ @utility_actions ++ @chat_admin_actions ++ @sticker_actions,
      delivery_modes:
        ~w(text media rich streaming_draft edit lifecycle inline web_app story batch place contact poll_control monetization chat_action reaction chat_admin forum_management utility sticker_management),
      blocks: @rich_blocks,
      inline:
        ~w(bold italic underline strikethrough spoiler mark code sub sup links date_time custom_emoji text_mention mention mathematical_expression email_address phone_number bank_card_number hashtag cashtag bot_command anchor anchor_link reference reference_link),
      interactions:
        ~w(url_buttons callback_buttons web_app_buttons switch_inline_query_buttons inline_query_answers guest_query_answers prepared_inline_messages prepared_keyboard_buttons reply_keyboard remove_keyboard force_reply),
      media: @media_kinds,
      structured_messages:
        ~w(poll quiz checklist invoice game story location venue contact dice chat_action reaction),
      monetization:
        ~w(paid_media invoice invoice_link shipping_query pre_checkout_query star_balance star_transactions gifts premium_gift star_refund star_subscription paid_broadcast),
      business_scoped:
        ~w(native_checklist story business_connection business_message_read business_message_delete business_profile business_gift_settings business_star_balance business_star_transfer business_gifts gift_convert gift_upgrade gift_transfer suggested_posts),
      organization_scoped: ~w(user_verification chat_verification),
      managed_bot_scoped: ~w(token_read token_replace access_settings personal_chat_messages),
      infrastructure_scoped: ~w(get_me polling webhooks),
      bot_profile_scoped:
        ~w(commands name description short_description profile_photo menu_button default_administrator_rights),
      utility_scoped:
        ~w(file_lookup user_profile_photos user_profile_audios user_emoji_status session_close),
      passport_scoped: ~w(passport_data_errors),
      chat_admin_scoped:
        ~w(member_bans member_restrictions promotions tags permissions invite_links join_requests chat_profile pins chat_info reactions),
      forum_scoped:
        ~w(topic_icons topic_create topic_edit topic_close topic_reopen topic_delete topic_unpin general_topic),
      sticker_scoped:
        ~w(sticker_sets custom_emoji upload add replace delete emoji_list keywords mask_position thumbnails),
      prepared_not_agent_safe_by_default:
        ~w(admin_chat_management business_account managed_bot inline_query passport sticker_set_management),
      validations: [
        "media URLs must be http/https",
        "inline link URLs must be http/https",
        "inline custom emoji spans require emoji_id",
        "inline date_time spans require unix",
        "inline text_mention spans require user_id",
        "inline mention spans require user_id or username",
        "inline mathematical_expression spans require expression",
        "inline email_address spans require a valid email",
        "inline phone_number spans require phone_number",
        "inline anchor/reference spans require names",
        "reply_markup accepts inline_keyboard, keyboard, remove_keyboard, or force_reply",
        "reply keyboard buttons can specify at most one action",
        "reply keyboard Web App URLs must be http/https",
        "mathematical_expression blocks require expression",
        "anchor blocks require name",
        "stream_text uses a non-zero draft_id and should be followed by a persistent send",
        "stream_card is private-chat oriented and may include thinking blocks",
        "final cards must not include thinking blocks",
        "raw rich messages must contain exactly one of html or markdown",
        "answer_callback text must be 0 to 200 characters",
        "inline query answers require 1 to 50 raw InlineQueryResult objects",
        "raw InlineQueryResult objects require non-empty type and id",
        "inline query next_offset must be 0 to 64 bytes",
        "guest query answers require a raw InlineQueryResult object with non-empty type and id",
        "prepared keyboard buttons require exactly one request action",
        "managed bot access settings accept at most 10 added_user_ids",
        "user personal chat message reads require limit 1 to 20",
        "bot commands require 1 to 100 commands with lowercase command names and descriptions",
        "bot profile names are 0 to 64 characters, descriptions 0 to 512, and short descriptions 0 to 120",
        "bot profile photos require a non-empty InputProfilePhoto object",
        "bot menu buttons and default administrator rights use raw Telegram objects",
        "stories require business_connection_id and can_manage_stories business bot right",
        "story active_period must be 21600, 43200, 86400, or 172800 seconds",
        "story content supports photo or video input story content",
        "edit actions and stop_poll accept inline keyboards only",
        "forward/copy message batches require 1 to 100 sorted message_ids",
        "delete message batches require 1 to 100 message_ids",
        "edit_media supports photo/video/animation/audio/document/live_photo input media",
        "polls must contain 1 to 12 options",
        "native checklists require business_connection_id and contain 1 to 30 tasks",
        "native checklist task text must be 1 to 100 characters",
        "quiz poll correct_option_id is normalized to correct_option_ids",
        "media groups must contain 2 to 10 photo/video/audio/document/live_photo items",
        "paid media requires 1 to 25000 Telegram Stars and 1 to 10 paid media items",
        "paid media payload must be 0 to 128 bytes",
        "invoices require title, description, payload, currency, and at least one labeled price",
        "Telegram Stars invoices use XTR currency and exactly one labeled price",
        "subscription invoice links require XTR currency and subscription_period 2592000",
        "shipping query answers require shipping_options when ok=true and error_message when ok=false",
        "pre-checkout query failures require error_message",
        "star transaction queries accept offset and limit 1 to 100",
        "send_gift requires exactly one of user_id or chat_id and gift text is 0 to 128 characters",
        "premium gifts require 1000 Stars for 3 months, 1500 for 6, or 2500 for 12",
        "business star transfers require business_connection_id and 1 to 10000 Stars",
        "gift list queries accept Telegram gift filters and limit 1 to 100",
        "gift conversion, upgrade, and transfer require owned_gift_id and relevant business bot rights",
        "organization verification descriptions must be 0 to 70 characters",
        "business message reads require business_connection_id, chat_id, and message_id",
        "business message deletes require 1 to 100 message_ids",
        "business account names are 1 to 64 characters for first_name and 0 to 64 for last_name",
        "business usernames are 0 to 32 characters and bios are 0 to 140 characters",
        "business account profile photo changes require a non-empty InputProfilePhoto object",
        "business gift settings require show_gift_button and accepted_gift_types",
        "suggested post decline comments must be 0 to 128 characters",
        "passport data errors require user_id and at least one error with source, type, and message",
        "game scores require non-negative score and either inline_message_id or chat_id with message_id",
        "star refunds and subscription edits require user_id and telegram_payment_charge_id",
        "invoice reply_markup first button must be a pay button",
        "games require game_short_name configured via BotFather",
        "stickers require a non-empty sticker file_id, attach reference, or supported URL",
        "audio and document media groups cannot be mixed with other media types",
        "location and venue coordinates must be numeric",
        "venue title/address and contact phone_number/first_name must be non-empty",
        "chat actions must be one of Telegram's supported sendChatAction values",
        "bots can set at most one reaction by default",
        "paid reactions are not agent-safe",
        "reaction deletion accepts at most one actor selector: user_id or actor_chat_id",
        "chat admin actions require the corresponding Telegram administrator rights",
        "chat invite link names are 0 to 32 characters and member_limit is 1 to 99999",
        "subscription invite links require subscription_period 2592000 and price 1 to 10000 Stars",
        "join request query result must be approve, decline, or queue",
        "send_chat_join_request_web_app requires an http/https web_app_url",
        "chat titles and descriptions are limited to 255 characters",
        "forum topic names are 1 to 128 characters when creating or editing the general topic",
        "forum topic icon_color must be one of Telegram's supported RGB constants",
        "profile photo/audio queries use limit 1 to 100",
        "get_file requires a non-empty file_id",
        "sticker_format must be static, animated, or video",
        "sticker_type must be regular, mask, or custom_emoji",
        "custom emoji sticker lookup accepts 1 to 200 custom_emoji_ids",
        "new sticker sets require 1 to 50 InputSticker objects",
        "sticker emoji lists accept 1 to 20 non-empty strings",
        "sticker keywords accept 0 to 20 non-empty strings"
      ]
    }
  end

  @doc "Higher-level Bot API capability areas tracked by the package."
  def catalog do
    %{
      implemented_agent_safe:
        @agent_actions ++ @utility_actions ++ @chat_admin_actions ++ @sticker_actions,
      implemented_client_methods:
        ~w(answerCallbackQuery answerWebAppQuery answerInlineQuery answerGuestQuery savePreparedInlineMessage savePreparedKeyboardButton getUserChatBoosts getBusinessConnection getManagedBotToken replaceManagedBotToken getManagedBotAccessSettings setManagedBotAccessSettings getUserPersonalChatMessages setMyCommands deleteMyCommands getMyCommands setMyName getMyName setMyDescription getMyDescription setMyShortDescription getMyShortDescription setMyProfilePhoto removeMyProfilePhoto setChatMenuButton getChatMenuButton setMyDefaultAdministratorRights getMyDefaultAdministratorRights createInvoiceLink answerShippingQuery answerPreCheckoutQuery getMyStarBalance getStarTransactions getAvailableGifts sendGift giftPremiumSubscription getBusinessAccountStarBalance transferBusinessAccountStars getBusinessAccountGifts getUserGifts getChatGifts convertGiftToStars upgradeGift transferGift verifyUser verifyChat removeUserVerification removeChatVerification readBusinessMessage deleteBusinessMessages setBusinessAccountName setBusinessAccountUsername setBusinessAccountBio setBusinessAccountProfilePhoto removeBusinessAccountProfilePhoto setBusinessAccountGiftSettings approveSuggestedPost declineSuggestedPost setPassportDataErrors setGameScore getGameHighScores refundStarPayment editUserStarSubscription postStory repostStory editStory deleteStory sendMessage sendMessageDraft sendPhoto sendLivePhoto sendVideo sendAnimation sendAudio sendVoice sendVideoNote sendDocument sendSticker sendMediaGroup sendPaidMedia sendPoll sendChecklist sendInvoice sendGame sendLocation sendVenue sendContact sendDice sendChatAction setMessageReaction forwardMessage forwardMessages copyMessage copyMessages deleteMessage deleteMessages sendRichMessage sendRichMessageDraft editMessageText editMessageCaption editMessageMedia editMessageLiveLocation editMessageChecklist stopMessageLiveLocation editMessageReplyMarkup stopPoll) ++
          @infrastructure_client_methods ++
          @utility_client_methods ++
          @chat_admin_client_methods ++
          @sticker_client_methods,
      prepared_restricted: %{
        commerce: [],
        stories: [],
        inline: [],
        chat_admin: [],
        business: [],
        managed_bots: [],
        passport: [],
        stickers: []
      }
    }
  end
end

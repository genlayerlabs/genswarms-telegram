defmodule Genswarms.Telegram.Client do
  @moduledoc """
  Telegram Bot API client behaviour and dispatch helpers.
  """

  @type method ::
          :get_me
          | :get_updates
          | :logout
          | :close
          | :answer_callback_query
          | :answer_web_app_query
          | :answer_inline_query
          | :answer_guest_query
          | :save_prepared_inline_message
          | :save_prepared_keyboard_button
          | :get_user_chat_boosts
          | :get_business_connection
          | :get_managed_bot_token
          | :replace_managed_bot_token
          | :get_managed_bot_access_settings
          | :set_managed_bot_access_settings
          | :get_user_personal_chat_messages
          | :create_invoice_link
          | :answer_shipping_query
          | :answer_pre_checkout_query
          | :get_my_star_balance
          | :get_star_transactions
          | :get_available_gifts
          | :send_gift
          | :gift_premium_subscription
          | :get_business_account_star_balance
          | :transfer_business_account_stars
          | :get_business_account_gifts
          | :get_user_gifts
          | :get_chat_gifts
          | :convert_gift_to_stars
          | :upgrade_gift
          | :transfer_gift
          | :verify_user
          | :verify_chat
          | :remove_user_verification
          | :remove_chat_verification
          | :read_business_message
          | :delete_business_messages
          | :set_business_account_name
          | :set_business_account_username
          | :set_business_account_bio
          | :set_business_account_profile_photo
          | :remove_business_account_profile_photo
          | :set_business_account_gift_settings
          | :approve_suggested_post
          | :decline_suggested_post
          | :set_passport_data_errors
          | :set_game_score
          | :get_game_high_scores
          | :refund_star_payment
          | :edit_user_star_subscription
          | :post_story
          | :repost_story
          | :edit_story
          | :delete_story
          | :set_my_commands
          | :delete_my_commands
          | :get_my_commands
          | :set_my_name
          | :get_my_name
          | :set_my_description
          | :get_my_description
          | :set_my_short_description
          | :get_my_short_description
          | :set_my_profile_photo
          | :remove_my_profile_photo
          | :set_chat_menu_button
          | :get_chat_menu_button
          | :set_my_default_administrator_rights
          | :get_my_default_administrator_rights
          | :set_webhook
          | :delete_webhook
          | :get_webhook_info
          | :send_message
          | :send_message_draft
          | :send_photo
          | :send_live_photo
          | :send_video
          | :send_animation
          | :send_audio
          | :send_voice
          | :send_video_note
          | :send_document
          | :send_sticker
          | :send_media_group
          | :send_paid_media
          | :send_poll
          | :send_checklist
          | :send_location
          | :send_venue
          | :send_contact
          | :send_dice
          | :send_invoice
          | :send_game
          | :send_rich_message
          | :send_rich_message_draft
          | :send_chat_action
          | :set_message_reaction
          | :get_user_profile_photos
          | :get_user_profile_audios
          | :set_user_emoji_status
          | :get_file
          | :forward_message
          | :forward_messages
          | :copy_message
          | :copy_messages
          | :delete_message
          | :delete_messages
          | :delete_message_reaction
          | :delete_all_message_reactions
          | :ban_chat_member
          | :unban_chat_member
          | :restrict_chat_member
          | :promote_chat_member
          | :set_chat_administrator_custom_title
          | :set_chat_member_tag
          | :ban_chat_sender_chat
          | :unban_chat_sender_chat
          | :set_chat_permissions
          | :export_chat_invite_link
          | :create_chat_invite_link
          | :edit_chat_invite_link
          | :create_chat_subscription_invite_link
          | :edit_chat_subscription_invite_link
          | :revoke_chat_invite_link
          | :approve_chat_join_request
          | :decline_chat_join_request
          | :answer_chat_join_request_query
          | :send_chat_join_request_web_app
          | :set_chat_photo
          | :delete_chat_photo
          | :set_chat_title
          | :set_chat_description
          | :pin_chat_message
          | :unpin_chat_message
          | :unpin_all_chat_messages
          | :leave_chat
          | :get_chat
          | :get_chat_administrators
          | :get_chat_member_count
          | :get_chat_member
          | :set_chat_sticker_set
          | :delete_chat_sticker_set
          | :get_forum_topic_icon_stickers
          | :create_forum_topic
          | :edit_forum_topic
          | :close_forum_topic
          | :reopen_forum_topic
          | :delete_forum_topic
          | :unpin_all_forum_topic_messages
          | :edit_general_forum_topic
          | :close_general_forum_topic
          | :reopen_general_forum_topic
          | :hide_general_forum_topic
          | :unhide_general_forum_topic
          | :unpin_all_general_forum_topic_messages
          | :get_sticker_set
          | :get_custom_emoji_stickers
          | :upload_sticker_file
          | :create_new_sticker_set
          | :add_sticker_to_set
          | :set_sticker_position_in_set
          | :delete_sticker_from_set
          | :replace_sticker_in_set
          | :set_sticker_emoji_list
          | :set_sticker_keywords
          | :set_sticker_mask_position
          | :set_sticker_set_title
          | :set_sticker_set_thumbnail
          | :set_custom_emoji_sticker_set_thumbnail
          | :delete_sticker_set
          | :edit_message_text
          | :edit_message_caption
          | :edit_message_media
          | :edit_message_live_location
          | :edit_message_checklist
          | :stop_message_live_location
          | :edit_message_reply_markup
          | :stop_poll

  @type result :: {:ok, term()} | {:error, term()}

  @callback request(method(), map(), keyword()) :: result()

  @method_names %{
    get_me: "getMe",
    get_updates: "getUpdates",
    logout: "logOut",
    close: "close",
    answer_callback_query: "answerCallbackQuery",
    answer_web_app_query: "answerWebAppQuery",
    answer_inline_query: "answerInlineQuery",
    answer_guest_query: "answerGuestQuery",
    save_prepared_inline_message: "savePreparedInlineMessage",
    save_prepared_keyboard_button: "savePreparedKeyboardButton",
    get_user_chat_boosts: "getUserChatBoosts",
    get_business_connection: "getBusinessConnection",
    get_managed_bot_token: "getManagedBotToken",
    replace_managed_bot_token: "replaceManagedBotToken",
    get_managed_bot_access_settings: "getManagedBotAccessSettings",
    set_managed_bot_access_settings: "setManagedBotAccessSettings",
    get_user_personal_chat_messages: "getUserPersonalChatMessages",
    create_invoice_link: "createInvoiceLink",
    answer_shipping_query: "answerShippingQuery",
    answer_pre_checkout_query: "answerPreCheckoutQuery",
    get_my_star_balance: "getMyStarBalance",
    get_star_transactions: "getStarTransactions",
    get_available_gifts: "getAvailableGifts",
    send_gift: "sendGift",
    gift_premium_subscription: "giftPremiumSubscription",
    get_business_account_star_balance: "getBusinessAccountStarBalance",
    transfer_business_account_stars: "transferBusinessAccountStars",
    get_business_account_gifts: "getBusinessAccountGifts",
    get_user_gifts: "getUserGifts",
    get_chat_gifts: "getChatGifts",
    convert_gift_to_stars: "convertGiftToStars",
    upgrade_gift: "upgradeGift",
    transfer_gift: "transferGift",
    verify_user: "verifyUser",
    verify_chat: "verifyChat",
    remove_user_verification: "removeUserVerification",
    remove_chat_verification: "removeChatVerification",
    read_business_message: "readBusinessMessage",
    delete_business_messages: "deleteBusinessMessages",
    set_business_account_name: "setBusinessAccountName",
    set_business_account_username: "setBusinessAccountUsername",
    set_business_account_bio: "setBusinessAccountBio",
    set_business_account_profile_photo: "setBusinessAccountProfilePhoto",
    remove_business_account_profile_photo: "removeBusinessAccountProfilePhoto",
    set_business_account_gift_settings: "setBusinessAccountGiftSettings",
    approve_suggested_post: "approveSuggestedPost",
    decline_suggested_post: "declineSuggestedPost",
    set_passport_data_errors: "setPassportDataErrors",
    set_game_score: "setGameScore",
    get_game_high_scores: "getGameHighScores",
    refund_star_payment: "refundStarPayment",
    edit_user_star_subscription: "editUserStarSubscription",
    post_story: "postStory",
    repost_story: "repostStory",
    edit_story: "editStory",
    delete_story: "deleteStory",
    set_my_commands: "setMyCommands",
    delete_my_commands: "deleteMyCommands",
    get_my_commands: "getMyCommands",
    set_my_name: "setMyName",
    get_my_name: "getMyName",
    set_my_description: "setMyDescription",
    get_my_description: "getMyDescription",
    set_my_short_description: "setMyShortDescription",
    get_my_short_description: "getMyShortDescription",
    set_my_profile_photo: "setMyProfilePhoto",
    remove_my_profile_photo: "removeMyProfilePhoto",
    set_chat_menu_button: "setChatMenuButton",
    get_chat_menu_button: "getChatMenuButton",
    set_my_default_administrator_rights: "setMyDefaultAdministratorRights",
    get_my_default_administrator_rights: "getMyDefaultAdministratorRights",
    set_webhook: "setWebhook",
    delete_webhook: "deleteWebhook",
    get_webhook_info: "getWebhookInfo",
    send_message: "sendMessage",
    send_message_draft: "sendMessageDraft",
    send_photo: "sendPhoto",
    send_live_photo: "sendLivePhoto",
    send_video: "sendVideo",
    send_animation: "sendAnimation",
    send_audio: "sendAudio",
    send_voice: "sendVoice",
    send_video_note: "sendVideoNote",
    send_document: "sendDocument",
    send_sticker: "sendSticker",
    send_media_group: "sendMediaGroup",
    send_paid_media: "sendPaidMedia",
    send_poll: "sendPoll",
    send_checklist: "sendChecklist",
    send_location: "sendLocation",
    send_venue: "sendVenue",
    send_contact: "sendContact",
    send_dice: "sendDice",
    send_invoice: "sendInvoice",
    send_game: "sendGame",
    send_rich_message: "sendRichMessage",
    send_rich_message_draft: "sendRichMessageDraft",
    send_chat_action: "sendChatAction",
    set_message_reaction: "setMessageReaction",
    get_user_profile_photos: "getUserProfilePhotos",
    get_user_profile_audios: "getUserProfileAudios",
    set_user_emoji_status: "setUserEmojiStatus",
    get_file: "getFile",
    forward_message: "forwardMessage",
    forward_messages: "forwardMessages",
    copy_message: "copyMessage",
    copy_messages: "copyMessages",
    delete_message: "deleteMessage",
    delete_messages: "deleteMessages",
    delete_message_reaction: "deleteMessageReaction",
    delete_all_message_reactions: "deleteAllMessageReactions",
    ban_chat_member: "banChatMember",
    unban_chat_member: "unbanChatMember",
    restrict_chat_member: "restrictChatMember",
    promote_chat_member: "promoteChatMember",
    set_chat_administrator_custom_title: "setChatAdministratorCustomTitle",
    set_chat_member_tag: "setChatMemberTag",
    ban_chat_sender_chat: "banChatSenderChat",
    unban_chat_sender_chat: "unbanChatSenderChat",
    set_chat_permissions: "setChatPermissions",
    export_chat_invite_link: "exportChatInviteLink",
    create_chat_invite_link: "createChatInviteLink",
    edit_chat_invite_link: "editChatInviteLink",
    create_chat_subscription_invite_link: "createChatSubscriptionInviteLink",
    edit_chat_subscription_invite_link: "editChatSubscriptionInviteLink",
    revoke_chat_invite_link: "revokeChatInviteLink",
    approve_chat_join_request: "approveChatJoinRequest",
    decline_chat_join_request: "declineChatJoinRequest",
    answer_chat_join_request_query: "answerChatJoinRequestQuery",
    send_chat_join_request_web_app: "sendChatJoinRequestWebApp",
    set_chat_photo: "setChatPhoto",
    delete_chat_photo: "deleteChatPhoto",
    set_chat_title: "setChatTitle",
    set_chat_description: "setChatDescription",
    pin_chat_message: "pinChatMessage",
    unpin_chat_message: "unpinChatMessage",
    unpin_all_chat_messages: "unpinAllChatMessages",
    leave_chat: "leaveChat",
    get_chat: "getChat",
    get_chat_administrators: "getChatAdministrators",
    get_chat_member_count: "getChatMemberCount",
    get_chat_member: "getChatMember",
    set_chat_sticker_set: "setChatStickerSet",
    delete_chat_sticker_set: "deleteChatStickerSet",
    get_forum_topic_icon_stickers: "getForumTopicIconStickers",
    create_forum_topic: "createForumTopic",
    edit_forum_topic: "editForumTopic",
    close_forum_topic: "closeForumTopic",
    reopen_forum_topic: "reopenForumTopic",
    delete_forum_topic: "deleteForumTopic",
    unpin_all_forum_topic_messages: "unpinAllForumTopicMessages",
    edit_general_forum_topic: "editGeneralForumTopic",
    close_general_forum_topic: "closeGeneralForumTopic",
    reopen_general_forum_topic: "reopenGeneralForumTopic",
    hide_general_forum_topic: "hideGeneralForumTopic",
    unhide_general_forum_topic: "unhideGeneralForumTopic",
    unpin_all_general_forum_topic_messages: "unpinAllGeneralForumTopicMessages",
    get_sticker_set: "getStickerSet",
    get_custom_emoji_stickers: "getCustomEmojiStickers",
    upload_sticker_file: "uploadStickerFile",
    create_new_sticker_set: "createNewStickerSet",
    add_sticker_to_set: "addStickerToSet",
    set_sticker_position_in_set: "setStickerPositionInSet",
    delete_sticker_from_set: "deleteStickerFromSet",
    replace_sticker_in_set: "replaceStickerInSet",
    set_sticker_emoji_list: "setStickerEmojiList",
    set_sticker_keywords: "setStickerKeywords",
    set_sticker_mask_position: "setStickerMaskPosition",
    set_sticker_set_title: "setStickerSetTitle",
    set_sticker_set_thumbnail: "setStickerSetThumbnail",
    set_custom_emoji_sticker_set_thumbnail: "setCustomEmojiStickerSetThumbnail",
    delete_sticker_set: "deleteStickerSet",
    edit_message_text: "editMessageText",
    edit_message_caption: "editMessageCaption",
    edit_message_media: "editMessageMedia",
    edit_message_live_location: "editMessageLiveLocation",
    edit_message_checklist: "editMessageChecklist",
    stop_message_live_location: "stopMessageLiveLocation",
    edit_message_reply_markup: "editMessageReplyMarkup",
    stop_poll: "stopPoll"
  }

  def request(adapter, method, payload, opts \\ []) when is_atom(adapter) and is_atom(method) do
    adapter.request(method, payload, opts)
  end

  def get_me(adapter, opts \\ []), do: request(adapter, :get_me, %{}, opts)
  def get_updates(adapter, payload, opts \\ []), do: request(adapter, :get_updates, payload, opts)
  def logout(adapter, opts \\ []), do: request(adapter, :logout, %{}, opts)
  def close(adapter, opts \\ []), do: request(adapter, :close, %{}, opts)

  def answer_callback_query(adapter, payload, opts \\ []),
    do: request(adapter, :answer_callback_query, payload, opts)

  def answer_web_app_query(adapter, payload, opts \\ []),
    do: request(adapter, :answer_web_app_query, payload, opts)

  def answer_inline_query(adapter, payload, opts \\ []),
    do: request(adapter, :answer_inline_query, payload, opts)

  def answer_guest_query(adapter, payload, opts \\ []),
    do: request(adapter, :answer_guest_query, payload, opts)

  def save_prepared_inline_message(adapter, payload, opts \\ []),
    do: request(adapter, :save_prepared_inline_message, payload, opts)

  def save_prepared_keyboard_button(adapter, payload, opts \\ []),
    do: request(adapter, :save_prepared_keyboard_button, payload, opts)

  def get_user_chat_boosts(adapter, payload, opts \\ []),
    do: request(adapter, :get_user_chat_boosts, payload, opts)

  def get_business_connection(adapter, payload, opts \\ []),
    do: request(adapter, :get_business_connection, payload, opts)

  def get_managed_bot_token(adapter, payload, opts \\ []),
    do: request(adapter, :get_managed_bot_token, payload, opts)

  def replace_managed_bot_token(adapter, payload, opts \\ []),
    do: request(adapter, :replace_managed_bot_token, payload, opts)

  def get_managed_bot_access_settings(adapter, payload, opts \\ []),
    do: request(adapter, :get_managed_bot_access_settings, payload, opts)

  def set_managed_bot_access_settings(adapter, payload, opts \\ []),
    do: request(adapter, :set_managed_bot_access_settings, payload, opts)

  def get_user_personal_chat_messages(adapter, payload, opts \\ []),
    do: request(adapter, :get_user_personal_chat_messages, payload, opts)

  def create_invoice_link(adapter, payload, opts \\ []),
    do: request(adapter, :create_invoice_link, payload, opts)

  def answer_shipping_query(adapter, payload, opts \\ []),
    do: request(adapter, :answer_shipping_query, payload, opts)

  def answer_pre_checkout_query(adapter, payload, opts \\ []),
    do: request(adapter, :answer_pre_checkout_query, payload, opts)

  def get_my_star_balance(adapter, opts \\ []),
    do: request(adapter, :get_my_star_balance, %{}, opts)

  def get_star_transactions(adapter, payload, opts \\ []),
    do: request(adapter, :get_star_transactions, payload, opts)

  def get_available_gifts(adapter, opts \\ []),
    do: request(adapter, :get_available_gifts, %{}, opts)

  def send_gift(adapter, payload, opts \\ []), do: request(adapter, :send_gift, payload, opts)

  def gift_premium_subscription(adapter, payload, opts \\ []),
    do: request(adapter, :gift_premium_subscription, payload, opts)

  def get_business_account_star_balance(adapter, payload, opts \\ []),
    do: request(adapter, :get_business_account_star_balance, payload, opts)

  def transfer_business_account_stars(adapter, payload, opts \\ []),
    do: request(adapter, :transfer_business_account_stars, payload, opts)

  def get_business_account_gifts(adapter, payload, opts \\ []),
    do: request(adapter, :get_business_account_gifts, payload, opts)

  def get_user_gifts(adapter, payload, opts \\ []),
    do: request(adapter, :get_user_gifts, payload, opts)

  def get_chat_gifts(adapter, payload, opts \\ []),
    do: request(adapter, :get_chat_gifts, payload, opts)

  def convert_gift_to_stars(adapter, payload, opts \\ []),
    do: request(adapter, :convert_gift_to_stars, payload, opts)

  def upgrade_gift(adapter, payload, opts \\ []),
    do: request(adapter, :upgrade_gift, payload, opts)

  def transfer_gift(adapter, payload, opts \\ []),
    do: request(adapter, :transfer_gift, payload, opts)

  def verify_user(adapter, payload, opts \\ []), do: request(adapter, :verify_user, payload, opts)

  def verify_chat(adapter, payload, opts \\ []), do: request(adapter, :verify_chat, payload, opts)

  def remove_user_verification(adapter, payload, opts \\ []),
    do: request(adapter, :remove_user_verification, payload, opts)

  def remove_chat_verification(adapter, payload, opts \\ []),
    do: request(adapter, :remove_chat_verification, payload, opts)

  def read_business_message(adapter, payload, opts \\ []),
    do: request(adapter, :read_business_message, payload, opts)

  def delete_business_messages(adapter, payload, opts \\ []),
    do: request(adapter, :delete_business_messages, payload, opts)

  def set_business_account_name(adapter, payload, opts \\ []),
    do: request(adapter, :set_business_account_name, payload, opts)

  def set_business_account_username(adapter, payload, opts \\ []),
    do: request(adapter, :set_business_account_username, payload, opts)

  def set_business_account_bio(adapter, payload, opts \\ []),
    do: request(adapter, :set_business_account_bio, payload, opts)

  def set_business_account_profile_photo(adapter, payload, opts \\ []),
    do: request(adapter, :set_business_account_profile_photo, payload, opts)

  def remove_business_account_profile_photo(adapter, payload, opts \\ []),
    do: request(adapter, :remove_business_account_profile_photo, payload, opts)

  def set_business_account_gift_settings(adapter, payload, opts \\ []),
    do: request(adapter, :set_business_account_gift_settings, payload, opts)

  def approve_suggested_post(adapter, payload, opts \\ []),
    do: request(adapter, :approve_suggested_post, payload, opts)

  def decline_suggested_post(adapter, payload, opts \\ []),
    do: request(adapter, :decline_suggested_post, payload, opts)

  def set_passport_data_errors(adapter, payload, opts \\ []),
    do: request(adapter, :set_passport_data_errors, payload, opts)

  def set_game_score(adapter, payload, opts \\ []),
    do: request(adapter, :set_game_score, payload, opts)

  def get_game_high_scores(adapter, payload, opts \\ []),
    do: request(adapter, :get_game_high_scores, payload, opts)

  def refund_star_payment(adapter, payload, opts \\ []),
    do: request(adapter, :refund_star_payment, payload, opts)

  def edit_user_star_subscription(adapter, payload, opts \\ []),
    do: request(adapter, :edit_user_star_subscription, payload, opts)

  def post_story(adapter, payload, opts \\ []), do: request(adapter, :post_story, payload, opts)

  def repost_story(adapter, payload, opts \\ []),
    do: request(adapter, :repost_story, payload, opts)

  def edit_story(adapter, payload, opts \\ []), do: request(adapter, :edit_story, payload, opts)

  def delete_story(adapter, payload, opts \\ []),
    do: request(adapter, :delete_story, payload, opts)

  def set_my_commands(adapter, payload, opts \\ []),
    do: request(adapter, :set_my_commands, payload, opts)

  def delete_my_commands(adapter, payload, opts \\ []),
    do: request(adapter, :delete_my_commands, payload, opts)

  def get_my_commands(adapter, payload, opts \\ []),
    do: request(adapter, :get_my_commands, payload, opts)

  def set_my_name(adapter, payload, opts \\ []),
    do: request(adapter, :set_my_name, payload, opts)

  def get_my_name(adapter, payload, opts \\ []),
    do: request(adapter, :get_my_name, payload, opts)

  def set_my_description(adapter, payload, opts \\ []),
    do: request(adapter, :set_my_description, payload, opts)

  def get_my_description(adapter, payload, opts \\ []),
    do: request(adapter, :get_my_description, payload, opts)

  def set_my_short_description(adapter, payload, opts \\ []),
    do: request(adapter, :set_my_short_description, payload, opts)

  def get_my_short_description(adapter, payload, opts \\ []),
    do: request(adapter, :get_my_short_description, payload, opts)

  def set_my_profile_photo(adapter, payload, opts \\ []),
    do: request(adapter, :set_my_profile_photo, payload, opts)

  def remove_my_profile_photo(adapter, payload \\ %{}, opts \\ []),
    do: request(adapter, :remove_my_profile_photo, payload, opts)

  def set_chat_menu_button(adapter, payload, opts \\ []),
    do: request(adapter, :set_chat_menu_button, payload, opts)

  def get_chat_menu_button(adapter, payload, opts \\ []),
    do: request(adapter, :get_chat_menu_button, payload, opts)

  def set_my_default_administrator_rights(adapter, payload, opts \\ []),
    do: request(adapter, :set_my_default_administrator_rights, payload, opts)

  def get_my_default_administrator_rights(adapter, payload, opts \\ []),
    do: request(adapter, :get_my_default_administrator_rights, payload, opts)

  def set_webhook(adapter, payload, opts \\ []),
    do: request(adapter, :set_webhook, payload, opts)

  def delete_webhook(adapter, payload \\ %{}, opts \\ []),
    do: request(adapter, :delete_webhook, payload, opts)

  def get_webhook_info(adapter, opts \\ []), do: request(adapter, :get_webhook_info, %{}, opts)

  def send_message(adapter, payload, opts \\ []),
    do: request(adapter, :send_message, payload, opts)

  def send_message_draft(adapter, payload, opts \\ []),
    do: request(adapter, :send_message_draft, payload, opts)

  def send_photo(adapter, payload, opts \\ []), do: request(adapter, :send_photo, payload, opts)

  def send_live_photo(adapter, payload, opts \\ []),
    do: request(adapter, :send_live_photo, payload, opts)

  def send_video(adapter, payload, opts \\ []), do: request(adapter, :send_video, payload, opts)

  def send_animation(adapter, payload, opts \\ []),
    do: request(adapter, :send_animation, payload, opts)

  def send_audio(adapter, payload, opts \\ []), do: request(adapter, :send_audio, payload, opts)

  def send_voice(adapter, payload, opts \\ []), do: request(adapter, :send_voice, payload, opts)

  def send_video_note(adapter, payload, opts \\ []),
    do: request(adapter, :send_video_note, payload, opts)

  def send_document(adapter, payload, opts \\ []),
    do: request(adapter, :send_document, payload, opts)

  def send_sticker(adapter, payload, opts \\ []),
    do: request(adapter, :send_sticker, payload, opts)

  def send_media_group(adapter, payload, opts \\ []),
    do: request(adapter, :send_media_group, payload, opts)

  def send_paid_media(adapter, payload, opts \\ []),
    do: request(adapter, :send_paid_media, payload, opts)

  def send_poll(adapter, payload, opts \\ []), do: request(adapter, :send_poll, payload, opts)

  def send_checklist(adapter, payload, opts \\ []),
    do: request(adapter, :send_checklist, payload, opts)

  def send_location(adapter, payload, opts \\ []),
    do: request(adapter, :send_location, payload, opts)

  def send_venue(adapter, payload, opts \\ []), do: request(adapter, :send_venue, payload, opts)

  def send_contact(adapter, payload, opts \\ []),
    do: request(adapter, :send_contact, payload, opts)

  def send_dice(adapter, payload, opts \\ []), do: request(adapter, :send_dice, payload, opts)

  def send_invoice(adapter, payload, opts \\ []),
    do: request(adapter, :send_invoice, payload, opts)

  def send_game(adapter, payload, opts \\ []), do: request(adapter, :send_game, payload, opts)

  def send_rich_message(adapter, payload, opts \\ []),
    do: request(adapter, :send_rich_message, payload, opts)

  def send_rich_message_draft(adapter, payload, opts \\ []),
    do: request(adapter, :send_rich_message_draft, payload, opts)

  def send_chat_action(adapter, payload, opts \\ []),
    do: request(adapter, :send_chat_action, payload, opts)

  def set_message_reaction(adapter, payload, opts \\ []),
    do: request(adapter, :set_message_reaction, payload, opts)

  def get_user_profile_photos(adapter, payload, opts \\ []),
    do: request(adapter, :get_user_profile_photos, payload, opts)

  def get_user_profile_audios(adapter, payload, opts \\ []),
    do: request(adapter, :get_user_profile_audios, payload, opts)

  def set_user_emoji_status(adapter, payload, opts \\ []),
    do: request(adapter, :set_user_emoji_status, payload, opts)

  def get_file(adapter, payload, opts \\ []), do: request(adapter, :get_file, payload, opts)

  def forward_message(adapter, payload, opts \\ []),
    do: request(adapter, :forward_message, payload, opts)

  def forward_messages(adapter, payload, opts \\ []),
    do: request(adapter, :forward_messages, payload, opts)

  def copy_message(adapter, payload, opts \\ []),
    do: request(adapter, :copy_message, payload, opts)

  def copy_messages(adapter, payload, opts \\ []),
    do: request(adapter, :copy_messages, payload, opts)

  def delete_message(adapter, payload, opts \\ []),
    do: request(adapter, :delete_message, payload, opts)

  def delete_messages(adapter, payload, opts \\ []),
    do: request(adapter, :delete_messages, payload, opts)

  def delete_message_reaction(adapter, payload, opts \\ []),
    do: request(adapter, :delete_message_reaction, payload, opts)

  def delete_all_message_reactions(adapter, payload, opts \\ []),
    do: request(adapter, :delete_all_message_reactions, payload, opts)

  def ban_chat_member(adapter, payload, opts \\ []),
    do: request(adapter, :ban_chat_member, payload, opts)

  def unban_chat_member(adapter, payload, opts \\ []),
    do: request(adapter, :unban_chat_member, payload, opts)

  def restrict_chat_member(adapter, payload, opts \\ []),
    do: request(adapter, :restrict_chat_member, payload, opts)

  def promote_chat_member(adapter, payload, opts \\ []),
    do: request(adapter, :promote_chat_member, payload, opts)

  def set_chat_administrator_custom_title(adapter, payload, opts \\ []),
    do: request(adapter, :set_chat_administrator_custom_title, payload, opts)

  def set_chat_member_tag(adapter, payload, opts \\ []),
    do: request(adapter, :set_chat_member_tag, payload, opts)

  def ban_chat_sender_chat(adapter, payload, opts \\ []),
    do: request(adapter, :ban_chat_sender_chat, payload, opts)

  def unban_chat_sender_chat(adapter, payload, opts \\ []),
    do: request(adapter, :unban_chat_sender_chat, payload, opts)

  def set_chat_permissions(adapter, payload, opts \\ []),
    do: request(adapter, :set_chat_permissions, payload, opts)

  def export_chat_invite_link(adapter, payload, opts \\ []),
    do: request(adapter, :export_chat_invite_link, payload, opts)

  def create_chat_invite_link(adapter, payload, opts \\ []),
    do: request(adapter, :create_chat_invite_link, payload, opts)

  def edit_chat_invite_link(adapter, payload, opts \\ []),
    do: request(adapter, :edit_chat_invite_link, payload, opts)

  def create_chat_subscription_invite_link(adapter, payload, opts \\ []),
    do: request(adapter, :create_chat_subscription_invite_link, payload, opts)

  def edit_chat_subscription_invite_link(adapter, payload, opts \\ []),
    do: request(adapter, :edit_chat_subscription_invite_link, payload, opts)

  def revoke_chat_invite_link(adapter, payload, opts \\ []),
    do: request(adapter, :revoke_chat_invite_link, payload, opts)

  def approve_chat_join_request(adapter, payload, opts \\ []),
    do: request(adapter, :approve_chat_join_request, payload, opts)

  def decline_chat_join_request(adapter, payload, opts \\ []),
    do: request(adapter, :decline_chat_join_request, payload, opts)

  def answer_chat_join_request_query(adapter, payload, opts \\ []),
    do: request(adapter, :answer_chat_join_request_query, payload, opts)

  def send_chat_join_request_web_app(adapter, payload, opts \\ []),
    do: request(adapter, :send_chat_join_request_web_app, payload, opts)

  def set_chat_photo(adapter, payload, opts \\ []),
    do: request(adapter, :set_chat_photo, payload, opts)

  def delete_chat_photo(adapter, payload, opts \\ []),
    do: request(adapter, :delete_chat_photo, payload, opts)

  def set_chat_title(adapter, payload, opts \\ []),
    do: request(adapter, :set_chat_title, payload, opts)

  def set_chat_description(adapter, payload, opts \\ []),
    do: request(adapter, :set_chat_description, payload, opts)

  def pin_chat_message(adapter, payload, opts \\ []),
    do: request(adapter, :pin_chat_message, payload, opts)

  def unpin_chat_message(adapter, payload, opts \\ []),
    do: request(adapter, :unpin_chat_message, payload, opts)

  def unpin_all_chat_messages(adapter, payload, opts \\ []),
    do: request(adapter, :unpin_all_chat_messages, payload, opts)

  def leave_chat(adapter, payload, opts \\ []), do: request(adapter, :leave_chat, payload, opts)

  def get_chat(adapter, payload, opts \\ []), do: request(adapter, :get_chat, payload, opts)

  def get_chat_administrators(adapter, payload, opts \\ []),
    do: request(adapter, :get_chat_administrators, payload, opts)

  def get_chat_member_count(adapter, payload, opts \\ []),
    do: request(adapter, :get_chat_member_count, payload, opts)

  def get_chat_member(adapter, payload, opts \\ []),
    do: request(adapter, :get_chat_member, payload, opts)

  def set_chat_sticker_set(adapter, payload, opts \\ []),
    do: request(adapter, :set_chat_sticker_set, payload, opts)

  def delete_chat_sticker_set(adapter, payload, opts \\ []),
    do: request(adapter, :delete_chat_sticker_set, payload, opts)

  def get_forum_topic_icon_stickers(adapter, opts \\ []),
    do: request(adapter, :get_forum_topic_icon_stickers, %{}, opts)

  def create_forum_topic(adapter, payload, opts \\ []),
    do: request(adapter, :create_forum_topic, payload, opts)

  def edit_forum_topic(adapter, payload, opts \\ []),
    do: request(adapter, :edit_forum_topic, payload, opts)

  def close_forum_topic(adapter, payload, opts \\ []),
    do: request(adapter, :close_forum_topic, payload, opts)

  def reopen_forum_topic(adapter, payload, opts \\ []),
    do: request(adapter, :reopen_forum_topic, payload, opts)

  def delete_forum_topic(adapter, payload, opts \\ []),
    do: request(adapter, :delete_forum_topic, payload, opts)

  def unpin_all_forum_topic_messages(adapter, payload, opts \\ []),
    do: request(adapter, :unpin_all_forum_topic_messages, payload, opts)

  def edit_general_forum_topic(adapter, payload, opts \\ []),
    do: request(adapter, :edit_general_forum_topic, payload, opts)

  def close_general_forum_topic(adapter, payload, opts \\ []),
    do: request(adapter, :close_general_forum_topic, payload, opts)

  def reopen_general_forum_topic(adapter, payload, opts \\ []),
    do: request(adapter, :reopen_general_forum_topic, payload, opts)

  def hide_general_forum_topic(adapter, payload, opts \\ []),
    do: request(adapter, :hide_general_forum_topic, payload, opts)

  def unhide_general_forum_topic(adapter, payload, opts \\ []),
    do: request(adapter, :unhide_general_forum_topic, payload, opts)

  def unpin_all_general_forum_topic_messages(adapter, payload, opts \\ []),
    do: request(adapter, :unpin_all_general_forum_topic_messages, payload, opts)

  def get_sticker_set(adapter, payload, opts \\ []),
    do: request(adapter, :get_sticker_set, payload, opts)

  def get_custom_emoji_stickers(adapter, payload, opts \\ []),
    do: request(adapter, :get_custom_emoji_stickers, payload, opts)

  def upload_sticker_file(adapter, payload, opts \\ []),
    do: request(adapter, :upload_sticker_file, payload, opts)

  def create_new_sticker_set(adapter, payload, opts \\ []),
    do: request(adapter, :create_new_sticker_set, payload, opts)

  def add_sticker_to_set(adapter, payload, opts \\ []),
    do: request(adapter, :add_sticker_to_set, payload, opts)

  def set_sticker_position_in_set(adapter, payload, opts \\ []),
    do: request(adapter, :set_sticker_position_in_set, payload, opts)

  def delete_sticker_from_set(adapter, payload, opts \\ []),
    do: request(adapter, :delete_sticker_from_set, payload, opts)

  def replace_sticker_in_set(adapter, payload, opts \\ []),
    do: request(adapter, :replace_sticker_in_set, payload, opts)

  def set_sticker_emoji_list(adapter, payload, opts \\ []),
    do: request(adapter, :set_sticker_emoji_list, payload, opts)

  def set_sticker_keywords(adapter, payload, opts \\ []),
    do: request(adapter, :set_sticker_keywords, payload, opts)

  def set_sticker_mask_position(adapter, payload, opts \\ []),
    do: request(adapter, :set_sticker_mask_position, payload, opts)

  def set_sticker_set_title(adapter, payload, opts \\ []),
    do: request(adapter, :set_sticker_set_title, payload, opts)

  def set_sticker_set_thumbnail(adapter, payload, opts \\ []),
    do: request(adapter, :set_sticker_set_thumbnail, payload, opts)

  def set_custom_emoji_sticker_set_thumbnail(adapter, payload, opts \\ []),
    do: request(adapter, :set_custom_emoji_sticker_set_thumbnail, payload, opts)

  def delete_sticker_set(adapter, payload, opts \\ []),
    do: request(adapter, :delete_sticker_set, payload, opts)

  def edit_message_text(adapter, payload, opts \\ []),
    do: request(adapter, :edit_message_text, payload, opts)

  def edit_message_caption(adapter, payload, opts \\ []),
    do: request(adapter, :edit_message_caption, payload, opts)

  def edit_message_media(adapter, payload, opts \\ []),
    do: request(adapter, :edit_message_media, payload, opts)

  def edit_message_live_location(adapter, payload, opts \\ []),
    do: request(adapter, :edit_message_live_location, payload, opts)

  def edit_message_checklist(adapter, payload, opts \\ []),
    do: request(adapter, :edit_message_checklist, payload, opts)

  def stop_message_live_location(adapter, payload, opts \\ []),
    do: request(adapter, :stop_message_live_location, payload, opts)

  def edit_message_reply_markup(adapter, payload, opts \\ []),
    do: request(adapter, :edit_message_reply_markup, payload, opts)

  def stop_poll(adapter, payload, opts \\ []),
    do: request(adapter, :stop_poll, payload, opts)

  def method_name(method), do: Map.fetch!(@method_names, method)

  @doc "Classify a Telegram HTTP response body."
  def classify_response(status, body) when is_integer(status) and is_binary(body) do
    with {:ok, decoded} <- Jason.decode(body) do
      classify_decoded(status, decoded)
    else
      {:error, _} -> {:error, {:bad_json, status, String.slice(body, 0, 200)}}
    end
  end

  def classify_response(status, body), do: classify_response(status, to_string(body))

  defp classify_decoded(status, %{"ok" => true, "result" => result}) when status in 200..299,
    do: {:ok, result}

  defp classify_decoded(status, %{"ok" => true} = body) when status in 200..299,
    do: {:ok, Map.get(body, "result", body)}

  defp classify_decoded(_status, %{"ok" => false, "error_code" => 429} = body) do
    retry_after = get_in(body, ["parameters", "retry_after"]) || 1
    {:error, {:rate_limited, retry_after, Map.get(body, "description", "")}}
  end

  defp classify_decoded(_status, %{"ok" => false, "error_code" => code} = body)
       when code in [400, 403] do
    description = Map.get(body, "description", "")

    cond do
      parse_error_description?(description) ->
        {:error, {:parse_error, description}}

      dead_chat_description?(description) ->
        {:error, {:dead_chat, code, description}}

      true ->
        {:error, {:failed, code, description}}
    end
  end

  defp classify_decoded(_status, %{"ok" => false, "error_code" => code} = body)
       when is_integer(code) and code >= 500,
       do: {:error, {:transient, code, Map.get(body, "description", "")}}

  defp classify_decoded(status, %{"ok" => false} = body) when status >= 500,
    do: {:error, {:transient, status, Map.get(body, "description", "")}}

  defp classify_decoded(status, %{"ok" => false} = body),
    do: {:error, {:failed, Map.get(body, "error_code", status), Map.get(body, "description", "")}}

  defp classify_decoded(status, body) when status >= 500, do: {:error, {:transient, status, body}}
  defp classify_decoded(status, body), do: {:error, {:unexpected_response, status, body}}

  @dead_chat_markers [
    "bot was blocked",
    "chat not found",
    "user is deactivated",
    "bot was kicked",
    "peer_id_invalid",
    "group chat was upgraded",
    "chat was deleted"
  ]

  @doc "True when a Telegram error description names a permanently dead recipient."
  def dead_chat_description?(description) when is_binary(description) do
    down = String.downcase(description)
    Enum.any?(@dead_chat_markers, &String.contains?(down, &1))
  end

  def dead_chat_description?(_), do: false

  defp parse_error_description?(description) do
    down = String.downcase(to_string(description))
    String.contains?(down, "parse") or String.contains?(down, "entities")
  end
end

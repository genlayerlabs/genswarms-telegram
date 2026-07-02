defmodule Genswarms.Telegram.Delivery do
  @moduledoc """
  Pure Telegram outbound payload helpers.
  """

  defdelegate build_add_sticker_to_set(arg1), to: Genswarms.Telegram.Delivery.Stickers
  defdelegate build_answer_callback_query(arg1), to: Genswarms.Telegram.Delivery.Inline
  defdelegate build_answer_chat_join_request_query(arg1), to: Genswarms.Telegram.Delivery.Admin
  defdelegate build_answer_guest_query(arg1), to: Genswarms.Telegram.Delivery.Inline
  defdelegate build_answer_inline_query(arg1), to: Genswarms.Telegram.Delivery.Inline
  defdelegate build_answer_pre_checkout_query(arg1), to: Genswarms.Telegram.Delivery.Payments
  defdelegate build_answer_shipping_query(arg1), to: Genswarms.Telegram.Delivery.Payments
  defdelegate build_answer_web_app_query(arg1), to: Genswarms.Telegram.Delivery.Inline
  defdelegate build_approve_chat_join_request(arg1), to: Genswarms.Telegram.Delivery.Admin
  defdelegate build_approve_suggested_post(arg1), to: Genswarms.Telegram.Delivery.Business
  defdelegate build_ban_chat_member(arg1), to: Genswarms.Telegram.Delivery.Admin
  defdelegate build_ban_chat_sender_chat(arg1), to: Genswarms.Telegram.Delivery.Admin
  defdelegate build_close_forum_topic(arg1), to: Genswarms.Telegram.Delivery.Admin
  defdelegate build_close_general_forum_topic(arg1), to: Genswarms.Telegram.Delivery.Admin
  defdelegate build_convert_gift_to_stars(arg1), to: Genswarms.Telegram.Delivery.Gifts
  defdelegate build_copy_message(arg1), to: Genswarms.Telegram.Delivery.MessageOps
  defdelegate build_copy_messages(arg1), to: Genswarms.Telegram.Delivery.MessageOps
  defdelegate build_create_chat_invite_link(arg1), to: Genswarms.Telegram.Delivery.Admin

  defdelegate build_create_chat_subscription_invite_link(arg1),
    to: Genswarms.Telegram.Delivery.Admin

  defdelegate build_create_forum_topic(arg1), to: Genswarms.Telegram.Delivery.Admin
  defdelegate build_create_invoice_link(arg1), to: Genswarms.Telegram.Delivery.Payments
  defdelegate build_create_new_sticker_set(arg1), to: Genswarms.Telegram.Delivery.Stickers
  defdelegate build_decline_chat_join_request(arg1), to: Genswarms.Telegram.Delivery.Admin
  defdelegate build_decline_suggested_post(arg1), to: Genswarms.Telegram.Delivery.Business
  defdelegate build_delete_all_message_reactions(arg1), to: Genswarms.Telegram.Delivery.Reactions
  defdelegate build_delete_business_messages(arg1), to: Genswarms.Telegram.Delivery.Business
  defdelegate build_delete_chat_photo(arg1), to: Genswarms.Telegram.Delivery.Admin
  defdelegate build_delete_chat_sticker_set(arg1), to: Genswarms.Telegram.Delivery.Admin
  defdelegate build_delete_forum_topic(arg1), to: Genswarms.Telegram.Delivery.Admin
  defdelegate build_delete_message(arg1), to: Genswarms.Telegram.Delivery.MessageOps
  defdelegate build_delete_message_reaction(arg1), to: Genswarms.Telegram.Delivery.Reactions
  defdelegate build_delete_messages(arg1), to: Genswarms.Telegram.Delivery.MessageOps
  defdelegate build_delete_my_commands(), to: Genswarms.Telegram.Delivery.Profile
  defdelegate build_delete_my_commands(arg1), to: Genswarms.Telegram.Delivery.Profile
  defdelegate build_delete_sticker_from_set(arg1), to: Genswarms.Telegram.Delivery.Stickers
  defdelegate build_delete_sticker_set(arg1), to: Genswarms.Telegram.Delivery.Stickers
  defdelegate build_delete_story(arg1), to: Genswarms.Telegram.Delivery.Stories
  defdelegate build_edit_chat_invite_link(arg1), to: Genswarms.Telegram.Delivery.Admin

  defdelegate build_edit_chat_subscription_invite_link(arg1),
    to: Genswarms.Telegram.Delivery.Admin

  defdelegate build_edit_forum_topic(arg1), to: Genswarms.Telegram.Delivery.Admin
  defdelegate build_edit_general_forum_topic(arg1), to: Genswarms.Telegram.Delivery.Admin
  defdelegate build_edit_live_location(arg1), to: Genswarms.Telegram.Delivery.Edits
  defdelegate build_edit_message_caption(arg1), to: Genswarms.Telegram.Delivery.Edits
  defdelegate build_edit_message_checklist(arg1), to: Genswarms.Telegram.Delivery.Business
  defdelegate build_edit_message_media(arg1), to: Genswarms.Telegram.Delivery.Edits
  defdelegate build_edit_message_reply_markup(arg1), to: Genswarms.Telegram.Delivery.Edits
  defdelegate build_edit_message_text(arg1), to: Genswarms.Telegram.Delivery.Edits
  defdelegate build_edit_rich_message(arg1), to: Genswarms.Telegram.Delivery.Core
  defdelegate build_edit_story(arg1), to: Genswarms.Telegram.Delivery.Stories
  defdelegate build_edit_user_star_subscription(arg1), to: Genswarms.Telegram.Delivery.Payments
  defdelegate build_export_chat_invite_link(arg1), to: Genswarms.Telegram.Delivery.Admin
  defdelegate build_forward_message(arg1), to: Genswarms.Telegram.Delivery.MessageOps
  defdelegate build_forward_messages(arg1), to: Genswarms.Telegram.Delivery.MessageOps
  defdelegate build_get_available_gifts(), to: Genswarms.Telegram.Delivery.Gifts
  defdelegate build_get_available_gifts(arg1), to: Genswarms.Telegram.Delivery.Gifts
  defdelegate build_get_business_account_gifts(arg1), to: Genswarms.Telegram.Delivery.Gifts
  defdelegate build_get_business_account_star_balance(arg1), to: Genswarms.Telegram.Delivery.Gifts
  defdelegate build_get_business_connection(arg1), to: Genswarms.Telegram.Delivery.Business
  defdelegate build_get_chat(arg1), to: Genswarms.Telegram.Delivery.Admin
  defdelegate build_get_chat_administrators(arg1), to: Genswarms.Telegram.Delivery.Admin
  defdelegate build_get_chat_gifts(arg1), to: Genswarms.Telegram.Delivery.Gifts
  defdelegate build_get_chat_member(arg1), to: Genswarms.Telegram.Delivery.Admin
  defdelegate build_get_chat_member_count(arg1), to: Genswarms.Telegram.Delivery.Admin
  defdelegate build_get_chat_menu_button(), to: Genswarms.Telegram.Delivery.Profile
  defdelegate build_get_chat_menu_button(arg1), to: Genswarms.Telegram.Delivery.Profile
  defdelegate build_get_custom_emoji_stickers(arg1), to: Genswarms.Telegram.Delivery.Stickers
  defdelegate build_get_file(arg1), to: Genswarms.Telegram.Delivery.Utility
  defdelegate build_get_forum_topic_icon_stickers(), to: Genswarms.Telegram.Delivery.Admin
  defdelegate build_get_forum_topic_icon_stickers(arg1), to: Genswarms.Telegram.Delivery.Admin
  defdelegate build_get_game_high_scores(arg1), to: Genswarms.Telegram.Delivery.Games

  defdelegate build_get_managed_bot_access_settings(arg1),
    to: Genswarms.Telegram.Delivery.ManagedBots

  defdelegate build_get_managed_bot_token(arg1), to: Genswarms.Telegram.Delivery.ManagedBots
  defdelegate build_get_my_commands(), to: Genswarms.Telegram.Delivery.Profile
  defdelegate build_get_my_commands(arg1), to: Genswarms.Telegram.Delivery.Profile
  defdelegate build_get_my_default_administrator_rights(), to: Genswarms.Telegram.Delivery.Profile

  defdelegate build_get_my_default_administrator_rights(arg1),
    to: Genswarms.Telegram.Delivery.Profile

  defdelegate build_get_my_description(), to: Genswarms.Telegram.Delivery.Profile
  defdelegate build_get_my_description(arg1), to: Genswarms.Telegram.Delivery.Profile
  defdelegate build_get_my_name(), to: Genswarms.Telegram.Delivery.Profile
  defdelegate build_get_my_name(arg1), to: Genswarms.Telegram.Delivery.Profile
  defdelegate build_get_my_short_description(), to: Genswarms.Telegram.Delivery.Profile
  defdelegate build_get_my_short_description(arg1), to: Genswarms.Telegram.Delivery.Profile
  defdelegate build_get_my_star_balance(), to: Genswarms.Telegram.Delivery.Payments
  defdelegate build_get_my_star_balance(arg1), to: Genswarms.Telegram.Delivery.Payments
  defdelegate build_get_star_transactions(), to: Genswarms.Telegram.Delivery.Payments
  defdelegate build_get_star_transactions(arg1), to: Genswarms.Telegram.Delivery.Payments
  defdelegate build_get_sticker_set(arg1), to: Genswarms.Telegram.Delivery.Stickers
  defdelegate build_get_user_chat_boosts(arg1), to: Genswarms.Telegram.Delivery.Utility
  defdelegate build_get_user_gifts(arg1), to: Genswarms.Telegram.Delivery.Gifts

  defdelegate build_get_user_personal_chat_messages(arg1),
    to: Genswarms.Telegram.Delivery.ManagedBots

  defdelegate build_get_user_profile_audios(arg1), to: Genswarms.Telegram.Delivery.Utility
  defdelegate build_get_user_profile_photos(arg1), to: Genswarms.Telegram.Delivery.Utility
  defdelegate build_gift_premium_subscription(arg1), to: Genswarms.Telegram.Delivery.Gifts
  defdelegate build_hide_general_forum_topic(arg1), to: Genswarms.Telegram.Delivery.Admin
  defdelegate build_leave_chat(arg1), to: Genswarms.Telegram.Delivery.Admin
  defdelegate build_pin_chat_message(arg1), to: Genswarms.Telegram.Delivery.Admin
  defdelegate build_plain_message(arg1), to: Genswarms.Telegram.Delivery.Core
  defdelegate build_post_story(arg1), to: Genswarms.Telegram.Delivery.Stories
  defdelegate build_promote_chat_member(arg1), to: Genswarms.Telegram.Delivery.Admin
  defdelegate build_read_business_message(arg1), to: Genswarms.Telegram.Delivery.Business
  defdelegate build_refund_star_payment(arg1), to: Genswarms.Telegram.Delivery.Payments

  defdelegate build_remove_business_account_profile_photo(arg1),
    to: Genswarms.Telegram.Delivery.Business

  defdelegate build_remove_chat_verification(arg1), to: Genswarms.Telegram.Delivery.Verification
  defdelegate build_remove_my_profile_photo(), to: Genswarms.Telegram.Delivery.Profile
  defdelegate build_remove_my_profile_photo(arg1), to: Genswarms.Telegram.Delivery.Profile
  defdelegate build_remove_user_verification(arg1), to: Genswarms.Telegram.Delivery.Verification
  defdelegate build_reopen_forum_topic(arg1), to: Genswarms.Telegram.Delivery.Admin
  defdelegate build_reopen_general_forum_topic(arg1), to: Genswarms.Telegram.Delivery.Admin
  defdelegate build_replace_managed_bot_token(arg1), to: Genswarms.Telegram.Delivery.ManagedBots
  defdelegate build_replace_sticker_in_set(arg1), to: Genswarms.Telegram.Delivery.Stickers
  defdelegate build_repost_story(arg1), to: Genswarms.Telegram.Delivery.Stories
  defdelegate build_restrict_chat_member(arg1), to: Genswarms.Telegram.Delivery.Admin
  defdelegate build_revoke_chat_invite_link(arg1), to: Genswarms.Telegram.Delivery.Admin
  defdelegate build_save_prepared_inline_message(arg1), to: Genswarms.Telegram.Delivery.Inline
  defdelegate build_save_prepared_keyboard_button(arg1), to: Genswarms.Telegram.Delivery.Inline
  defdelegate build_send_chat_action(arg1), to: Genswarms.Telegram.Delivery.Utility
  defdelegate build_send_chat_join_request_web_app(arg1), to: Genswarms.Telegram.Delivery.Admin
  defdelegate build_send_checklist(arg1), to: Genswarms.Telegram.Delivery.Business
  defdelegate build_send_contact(arg1), to: Genswarms.Telegram.Delivery.Media
  defdelegate build_send_dice(arg1), to: Genswarms.Telegram.Delivery.Media
  defdelegate build_send_game(arg1), to: Genswarms.Telegram.Delivery.Games
  defdelegate build_send_gift(arg1), to: Genswarms.Telegram.Delivery.Gifts
  defdelegate build_send_invoice(arg1), to: Genswarms.Telegram.Delivery.Payments
  defdelegate build_send_live_photo(arg1), to: Genswarms.Telegram.Delivery.Media
  defdelegate build_send_location(arg1), to: Genswarms.Telegram.Delivery.Media
  defdelegate build_send_media(arg1), to: Genswarms.Telegram.Delivery.Media
  defdelegate build_send_media_group(arg1), to: Genswarms.Telegram.Delivery.Media
  defdelegate build_send_message(arg1), to: Genswarms.Telegram.Delivery.Core
  defdelegate build_send_message_draft(arg1), to: Genswarms.Telegram.Delivery.Core
  defdelegate build_send_paid_media(arg1), to: Genswarms.Telegram.Delivery.Payments
  defdelegate build_send_photo(arg1), to: Genswarms.Telegram.Delivery.Media
  defdelegate build_send_poll(arg1), to: Genswarms.Telegram.Delivery.Media
  defdelegate build_send_rich_message(arg1), to: Genswarms.Telegram.Delivery.Core
  defdelegate build_send_rich_message_draft(arg1), to: Genswarms.Telegram.Delivery.Core
  defdelegate build_send_sticker(arg1), to: Genswarms.Telegram.Delivery.Media
  defdelegate build_send_venue(arg1), to: Genswarms.Telegram.Delivery.Media
  defdelegate build_send_video_note(arg1), to: Genswarms.Telegram.Delivery.Media
  defdelegate build_set_business_account_bio(arg1), to: Genswarms.Telegram.Delivery.Business

  defdelegate build_set_business_account_gift_settings(arg1),
    to: Genswarms.Telegram.Delivery.Business

  defdelegate build_set_business_account_name(arg1), to: Genswarms.Telegram.Delivery.Business

  defdelegate build_set_business_account_profile_photo(arg1),
    to: Genswarms.Telegram.Delivery.Business

  defdelegate build_set_business_account_username(arg1), to: Genswarms.Telegram.Delivery.Business

  defdelegate build_set_chat_administrator_custom_title(arg1),
    to: Genswarms.Telegram.Delivery.Admin

  defdelegate build_set_chat_description(arg1), to: Genswarms.Telegram.Delivery.Admin
  defdelegate build_set_chat_member_tag(arg1), to: Genswarms.Telegram.Delivery.Admin
  defdelegate build_set_chat_menu_button(), to: Genswarms.Telegram.Delivery.Profile
  defdelegate build_set_chat_menu_button(arg1), to: Genswarms.Telegram.Delivery.Profile
  defdelegate build_set_chat_permissions(arg1), to: Genswarms.Telegram.Delivery.Admin
  defdelegate build_set_chat_photo(arg1), to: Genswarms.Telegram.Delivery.Admin
  defdelegate build_set_chat_sticker_set(arg1), to: Genswarms.Telegram.Delivery.Admin
  defdelegate build_set_chat_title(arg1), to: Genswarms.Telegram.Delivery.Admin

  defdelegate build_set_custom_emoji_sticker_set_thumbnail(arg1),
    to: Genswarms.Telegram.Delivery.Stickers

  defdelegate build_set_game_score(arg1), to: Genswarms.Telegram.Delivery.Games

  defdelegate build_set_managed_bot_access_settings(arg1),
    to: Genswarms.Telegram.Delivery.ManagedBots

  defdelegate build_set_message_reaction(arg1), to: Genswarms.Telegram.Delivery.Reactions
  defdelegate build_set_my_commands(arg1), to: Genswarms.Telegram.Delivery.Profile
  defdelegate build_set_my_default_administrator_rights(), to: Genswarms.Telegram.Delivery.Profile

  defdelegate build_set_my_default_administrator_rights(arg1),
    to: Genswarms.Telegram.Delivery.Profile

  defdelegate build_set_my_description(), to: Genswarms.Telegram.Delivery.Profile
  defdelegate build_set_my_description(arg1), to: Genswarms.Telegram.Delivery.Profile
  defdelegate build_set_my_name(), to: Genswarms.Telegram.Delivery.Profile
  defdelegate build_set_my_name(arg1), to: Genswarms.Telegram.Delivery.Profile
  defdelegate build_set_my_profile_photo(arg1), to: Genswarms.Telegram.Delivery.Profile
  defdelegate build_set_my_short_description(), to: Genswarms.Telegram.Delivery.Profile
  defdelegate build_set_my_short_description(arg1), to: Genswarms.Telegram.Delivery.Profile
  defdelegate build_set_passport_data_errors(arg1), to: Genswarms.Telegram.Delivery.Passport
  defdelegate build_set_sticker_emoji_list(arg1), to: Genswarms.Telegram.Delivery.Stickers
  defdelegate build_set_sticker_keywords(arg1), to: Genswarms.Telegram.Delivery.Stickers
  defdelegate build_set_sticker_mask_position(arg1), to: Genswarms.Telegram.Delivery.Stickers
  defdelegate build_set_sticker_position_in_set(arg1), to: Genswarms.Telegram.Delivery.Stickers
  defdelegate build_set_sticker_set_thumbnail(arg1), to: Genswarms.Telegram.Delivery.Stickers
  defdelegate build_set_sticker_set_title(arg1), to: Genswarms.Telegram.Delivery.Stickers
  defdelegate build_set_user_emoji_status(arg1), to: Genswarms.Telegram.Delivery.Utility
  defdelegate build_stop_live_location(arg1), to: Genswarms.Telegram.Delivery.Edits
  defdelegate build_stop_poll(arg1), to: Genswarms.Telegram.Delivery.Edits
  defdelegate build_transfer_business_account_stars(arg1), to: Genswarms.Telegram.Delivery.Gifts
  defdelegate build_transfer_gift(arg1), to: Genswarms.Telegram.Delivery.Gifts
  defdelegate build_unban_chat_member(arg1), to: Genswarms.Telegram.Delivery.Admin
  defdelegate build_unban_chat_sender_chat(arg1), to: Genswarms.Telegram.Delivery.Admin
  defdelegate build_unhide_general_forum_topic(arg1), to: Genswarms.Telegram.Delivery.Admin
  defdelegate build_unpin_all_chat_messages(arg1), to: Genswarms.Telegram.Delivery.Admin
  defdelegate build_unpin_all_forum_topic_messages(arg1), to: Genswarms.Telegram.Delivery.Admin

  defdelegate build_unpin_all_general_forum_topic_messages(arg1),
    to: Genswarms.Telegram.Delivery.Admin

  defdelegate build_unpin_chat_message(arg1), to: Genswarms.Telegram.Delivery.Admin
  defdelegate build_upgrade_gift(arg1), to: Genswarms.Telegram.Delivery.Gifts
  defdelegate build_upload_sticker_file(arg1), to: Genswarms.Telegram.Delivery.Stickers
  defdelegate build_verify_chat(arg1), to: Genswarms.Telegram.Delivery.Verification
  defdelegate build_verify_user(arg1), to: Genswarms.Telegram.Delivery.Verification
  defdelegate chunk_text(arg1), to: Genswarms.Telegram.Delivery.Shared
  defdelegate chunk_text(arg1, arg2), to: Genswarms.Telegram.Delivery.Shared
  defdelegate reply_markup(arg1), to: Genswarms.Telegram.Delivery.Shared
  defdelegate utf16_units(arg1), to: Genswarms.Telegram.Delivery.Shared
end

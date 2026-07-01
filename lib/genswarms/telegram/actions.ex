defmodule Genswarms.Telegram.Actions do
  @moduledoc """
  Scoped Telegram sender action taxonomy.

  This module is the single compile-time table used by the sender gate. Every
  public sender action must classify here before a Sender state can initialize.
  """

  @agent_groups [
    core: ~w(reply send progress),
    cards: ~w(send_card stream_card edit_card validate_card stream_text),
    discovery: ~w(capabilities examples),
    media:
      ~w(send_media send_media_group send_video_note send_live_photo send_sticker send_poll send_location send_venue send_contact send_dice),
    own_messages:
      ~w(edit_message edit_caption edit_media edit_reply_markup stop_poll edit_live_location stop_live_location delete_message delete_messages),
    reactions: ~w(set_reaction)
  ]

  @operator_groups [
    chat_admin: ~w(
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
        delete_message_reaction
        delete_all_message_reactions
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
      ),
    message_ops: ~w(copy_message copy_messages forward_message forward_messages),
    payments:
      ~w(create_invoice_link send_invoice send_paid_media answer_shipping_query answer_pre_checkout_query refund_star_payment edit_user_star_subscription get_my_star_balance get_star_transactions),
    gifts:
      ~w(get_available_gifts send_gift gift_premium_subscription get_business_account_star_balance transfer_business_account_stars get_business_account_gifts get_user_gifts get_chat_gifts convert_gift_to_stars upgrade_gift transfer_gift),
    business:
      ~w(get_business_connection read_business_message delete_business_messages set_business_account_name set_business_account_username set_business_account_bio set_business_account_profile_photo remove_business_account_profile_photo set_business_account_gift_settings approve_suggested_post decline_suggested_post send_checklist edit_checklist),
    stories: ~w(post_story repost_story edit_story delete_story),
    stickers_mgmt:
      ~w(get_sticker_set get_custom_emoji_stickers upload_sticker_file create_new_sticker_set add_sticker_to_set set_sticker_position_in_set delete_sticker_from_set replace_sticker_in_set set_sticker_emoji_list set_sticker_keywords set_sticker_mask_position set_sticker_set_title set_sticker_set_thumbnail set_custom_emoji_sticker_set_thumbnail delete_sticker_set),
    bot_profile:
      ~w(set_my_commands delete_my_commands get_my_commands set_my_name get_my_name set_my_description get_my_description set_my_short_description get_my_short_description set_my_profile_photo remove_my_profile_photo set_chat_menu_button get_chat_menu_button set_my_default_administrator_rights get_my_default_administrator_rights),
    managed_bots:
      ~w(get_managed_bot_token replace_managed_bot_token get_managed_bot_access_settings set_managed_bot_access_settings get_user_personal_chat_messages),
    inline:
      ~w(answer_callback answer_web_app answer_inline_query answer_guest_query save_prepared_inline_message save_prepared_keyboard_button),
    verification: ~w(verify_user verify_chat remove_user_verification remove_chat_verification),
    passport: ~w(set_passport_data_errors),
    games: ~w(send_game set_game_score get_game_high_scores),
    utility:
      ~w(get_file get_user_profile_photos get_user_profile_audios set_user_emoji_status get_user_chat_boosts),
    infra: ~w(send_rich_raw send_chat_action)
  ]

  @plumbing_actions ~w(send_batch slot_reply bind_session unbind_session typing audit)

  @entries_agent for {group, actions} <- @agent_groups,
                     action <- actions,
                     do: {action, {:agent, group}}

  @entries_operator for {group, actions} <- @operator_groups,
                        action <- actions,
                        do: {action, {:operator, group}}

  @entries_plumbing for action <- @plumbing_actions,
                        do: {action, {:plumbing, String.to_atom(action)}}

  @entries @entries_agent ++ @entries_operator ++ @entries_plumbing

  @actions_by_group_base @agent_groups ++
                           @operator_groups ++
                           Enum.map(@plumbing_actions, &{String.to_atom(&1), [&1]})

  @actions_by_group @actions_by_group_base
                    |> Enum.reduce(%{}, fn {group, actions}, acc ->
                      Map.update(acc, group, actions, &(&1 ++ actions))
                    end)
                    |> Map.update!(
                      :message_ops,
                      &Enum.uniq(&1 ++ ~w(delete_message delete_messages))
                    )

  @classifications Map.new(@entries)
  @groups Keyword.keys(@agent_groups) ++ Keyword.keys(@operator_groups)
  @actions Enum.map(@entries, &elem(&1, 0))

  @doc """
  Returns the sender action classification, or `:unknown`.
  """
  def classify(action) when is_atom(action), do: action |> Atom.to_string() |> classify()
  def classify(action) when is_binary(action), do: Map.get(@classifications, action, :unknown)
  def classify(_action), do: :unknown

  @doc """
  Returns all non-plumbing groups.
  """
  def groups, do: @groups

  @doc """
  Returns the actions assigned to a group or plumbing action atom.
  """
  def actions_in(group) when is_atom(group), do: Map.get(@actions_by_group, group, [])
  def actions_in(group) when is_binary(group), do: group |> String.to_atom() |> actions_in()
  def actions_in(_group), do: []

  @doc """
  Returns all classified action names.
  """
  def actions, do: @actions
end

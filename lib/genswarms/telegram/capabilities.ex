defmodule Genswarms.Telegram.Capabilities do
  @moduledoc """
  Machine-readable Telegram capabilities exposed by this package.

  Sender action policy is owned by `Genswarms.Telegram.Actions`. This module
  derives the public catalog from that table so discovery cannot drift into a
  second authorization policy.
  """

  alias Genswarms.Telegram.{Actions, Client}

  @telegram_bot_api_version "10.1"

  @doc "Declared Telegram Bot API target version for this package."
  def telegram_bot_api_version, do: @telegram_bot_api_version

  @doc "Capabilities that the sender object exposes to agents by default."
  def sender do
    for_groups(agent_groups())
  end

  @doc "Build a capability document for the provided group names."
  def for_groups(groups) when is_list(groups) do
    groups
    |> Enum.map(&normalize_group/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
    |> Map.new(&{&1, Actions.actions_in(&1)})
    |> for_action_groups()
  end

  @doc "Build a capability document for an explicit group-to-actions map."
  def for_action_groups(group_actions) when is_map(group_actions) do
    group_actions =
      group_actions
      |> Enum.map(fn {group, actions} -> {normalize_group(group), normalize_actions(actions)} end)
      |> Enum.reject(fn {group, actions} -> is_nil(group) or actions == [] end)

    groups =
      group_actions
      |> Map.new(fn {group, actions} -> {Atom.to_string(group), actions} end)

    actions =
      group_actions
      |> Enum.flat_map(fn {_group, actions} -> actions end)
      |> Enum.uniq()

    Map.merge(base_sender_capabilities(), %{
      actions: actions,
      enabled_groups: Map.keys(groups),
      groups: groups,
      telegram_bot_api_version: @telegram_bot_api_version,
      card_schema: Genswarms.Telegram.Card.schema_info()
    })
  end

  @doc "Higher-level Bot API capability areas tracked by the package."
  def catalog do
    %{
      implemented_agent_safe: agent_actions(),
      implemented_client_methods: implemented_client_methods(),
      prepared_restricted: operator_action_groups()
    }
  end

  defp base_sender_capabilities do
    card_schema = Genswarms.Telegram.Card.schema_info()

    %{
      delivery_modes:
        ~w(text media rich streaming_draft edit lifecycle inline web_app story batch place contact poll_control monetization chat_action reaction chat_admin forum_management utility sticker_management),
      blocks: card_schema.blocks,
      inline:
        ~w(bold italic underline strikethrough spoiler mark code sub sup links date_time custom_emoji text_mention mention mathematical_expression email_address phone_number bank_card_number hashtag cashtag bot_command anchor anchor_link reference reference_link),
      interactions:
        ~w(url_buttons callback_buttons web_app_buttons switch_inline_query_buttons inline_query_answers guest_query_answers prepared_inline_messages prepared_keyboard_buttons reply_keyboard remove_keyboard force_reply),
      media:
        ~w(photo live_photo video animation audio voice voice_note document sticker media_group),
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
      prepared_not_agent_safe_by_default: Enum.map(operator_groups(), &Atom.to_string/1),
      validations: validations()
    }
  end

  defp validations do
    [
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
      "guest query answers require a raw InlineQueryResult object with non-empty type and id",
      "edit actions and stop_poll accept inline keyboards only",
      "delete message batches require 1 to 100 message_ids",
      "polls must contain 1 to 12 options",
      "native checklists require business_connection_id and contain 1 to 30 tasks",
      "media groups must contain 2 to 10 photo/video/audio/document/live_photo items",
      "paid media requires 1 to 25000 Telegram Stars and 1 to 10 paid media items",
      "invoices require title, description, payload, currency, and at least one labeled price",
      "chat admin actions require the corresponding Telegram administrator rights",
      "stickers require a non-empty sticker file_id, attach reference, or supported URL"
    ]
  end

  defp agent_actions do
    agent_groups()
    |> Enum.flat_map(&Actions.actions_in/1)
    |> Enum.uniq()
  end

  defp agent_groups do
    Actions.groups()
    |> Enum.filter(&(group_class(&1) == :agent))
  end

  defp operator_action_groups do
    operator_groups()
    |> Map.new(&{&1, Actions.actions_in(&1)})
  end

  defp operator_groups do
    Actions.groups()
    |> Enum.filter(&(group_class(&1) == :operator))
  end

  defp group_class(group) do
    case Actions.actions_in(group) do
      [action | _] ->
        case Actions.classify(action) do
          {:agent, ^group} -> :agent
          {:operator, ^group} -> :operator
          _other -> :unknown
        end

      [] ->
        :unknown
    end
  end

  defp normalize_group(group) when is_atom(group) do
    if group in Actions.groups(), do: group
  end

  defp normalize_group(group) when is_binary(group) do
    Enum.find(Actions.groups(), &(Atom.to_string(&1) == group))
  end

  defp normalize_group(_group), do: nil

  defp normalize_actions(actions) do
    actions
    |> List.wrap()
    |> Enum.map(&to_string/1)
    |> Enum.filter(&(Actions.classify(&1) != :unknown))
    |> Enum.uniq()
  end

  defp implemented_client_methods do
    method_atoms =
      Actions.actions()
      |> Enum.flat_map(&client_method_candidates/1)
      |> Enum.concat(
        ~w(get_me get_updates set_webhook delete_webhook get_webhook_info logout close)a
      )
      |> Enum.uniq()

    method_atoms
    |> Enum.map(&client_method_name/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end

  defp client_method_candidates(action) do
    action = to_string(action)
    exact = String.to_atom(action)

    generated =
      cond do
        String.starts_with?(action, "edit_") ->
          [String.to_atom("edit_message_" <> String.replace_prefix(action, "edit_", ""))]

        String.starts_with?(action, "stop_") ->
          [String.to_atom("stop_message_" <> String.replace_prefix(action, "stop_", ""))]

        String.starts_with?(action, "set_") ->
          [String.to_atom("set_message_" <> String.replace_prefix(action, "set_", ""))]

        true ->
          []
      end

    [exact | generated]
  end

  defp client_method_name(method) do
    Client.method_name(method)
  rescue
    KeyError -> nil
  end
end

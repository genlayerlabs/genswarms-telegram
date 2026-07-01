defmodule Genswarms.Telegram.Delivery do
  @moduledoc """
  Pure Telegram outbound payload helpers.
  """

  alias Genswarms.Telegram.{ConversationId, Format}

  @telegram_text_limit 4096
  @chat_actions ~w(typing upload_photo record_video upload_video record_voice upload_voice upload_document choose_sticker find_location record_video_note upload_video_note)

  def build_answer_callback_query(%{callback_query_id: callback_query_id} = attrs) do
    %{
      _method: :answer_callback_query,
      callback_query_id: non_empty_string!(callback_query_id, :callback_query_id)
    }
    |> maybe_put(:text, bounded_string_or_empty!(option(attrs, :text), :text, 0, 200))
    |> maybe_put(:show_alert, option(attrs, :show_alert))
    |> maybe_put(:url, safe_optional_url!(option(attrs, :url), :url))
    |> maybe_put(:cache_time, option(attrs, :cache_time))
  end

  def build_answer_web_app_query(%{web_app_query_id: web_app_query_id, result: result}) do
    %{
      _method: :answer_web_app_query,
      web_app_query_id: non_empty_string!(web_app_query_id, :web_app_query_id),
      result: normalize_inline_query_result!(result)
    }
  end

  def build_answer_guest_query(%{guest_query_id: guest_query_id, result: result}) do
    %{
      _method: :answer_guest_query,
      guest_query_id: non_empty_string!(guest_query_id, :guest_query_id),
      result: normalize_inline_query_result!(result)
    }
  end

  def build_answer_inline_query(%{inline_query_id: inline_query_id, results: results} = attrs) do
    %{
      _method: :answer_inline_query,
      inline_query_id: non_empty_string!(inline_query_id, :inline_query_id),
      results: normalize_inline_query_results!(results, 50)
    }
    |> maybe_put(:cache_time, option(attrs, :cache_time))
    |> maybe_put(:is_personal, option(attrs, :is_personal))
    |> maybe_put(:next_offset, bounded_bytes!(option(attrs, :next_offset), :next_offset, 0, 64))
    |> maybe_put(:button, normalize_inline_query_results_button(option(attrs, :button)))
  end

  def build_save_prepared_inline_message(%{user_id: user_id, result: result} = attrs) do
    %{
      _method: :save_prepared_inline_message,
      user_id: normalize_positive_integer!(user_id, :user_id),
      result: normalize_inline_query_result!(result)
    }
    |> maybe_put(:allow_user_chats, option(attrs, :allow_user_chats))
    |> maybe_put(:allow_bot_chats, option(attrs, :allow_bot_chats))
    |> maybe_put(:allow_group_chats, option(attrs, :allow_group_chats))
    |> maybe_put(:allow_channel_chats, option(attrs, :allow_channel_chats))
  end

  def build_save_prepared_keyboard_button(%{user_id: user_id, button: button}) do
    %{
      _method: :save_prepared_keyboard_button,
      user_id: normalize_positive_integer!(user_id, :user_id),
      button: normalize_prepared_keyboard_button!(button)
    }
  end

  def build_get_user_chat_boosts(%{chat_id: chat_id, user_id: user_id}) do
    %{
      _method: :get_user_chat_boosts,
      chat_id: normalize_chat_id!(chat_id, :chat_id),
      user_id: normalize_positive_integer!(user_id, :user_id)
    }
  end

  def build_get_business_connection(%{business_connection_id: business_connection_id}) do
    %{
      _method: :get_business_connection,
      business_connection_id: non_empty_string!(business_connection_id, :business_connection_id)
    }
  end

  def build_get_managed_bot_token(%{user_id: user_id}) do
    %{
      _method: :get_managed_bot_token,
      user_id: normalize_positive_integer!(user_id, :user_id)
    }
  end

  def build_replace_managed_bot_token(%{user_id: user_id}) do
    %{
      _method: :replace_managed_bot_token,
      user_id: normalize_positive_integer!(user_id, :user_id)
    }
  end

  def build_get_managed_bot_access_settings(%{user_id: user_id}) do
    %{
      _method: :get_managed_bot_access_settings,
      user_id: normalize_positive_integer!(user_id, :user_id)
    }
  end

  def build_set_managed_bot_access_settings(
        %{
          user_id: user_id,
          is_access_restricted: is_access_restricted
        } = attrs
      ) do
    %{
      _method: :set_managed_bot_access_settings,
      user_id: normalize_positive_integer!(user_id, :user_id),
      is_access_restricted: truthy_boolean!(is_access_restricted, :is_access_restricted)
    }
    |> maybe_put(:added_user_ids, normalize_added_user_ids(option(attrs, :added_user_ids)))
  end

  def build_get_user_personal_chat_messages(%{user_id: user_id, limit: limit}) do
    %{
      _method: :get_user_personal_chat_messages,
      user_id: normalize_positive_integer!(user_id, :user_id),
      limit: bounded_integer!(limit, :limit, 1, 20)
    }
  end

  def build_set_my_commands(%{commands: commands} = attrs) do
    %{
      _method: :set_my_commands,
      commands: normalize_bot_commands!(commands)
    }
    |> maybe_put(:scope, optional_map(option(attrs, :scope), :scope))
    |> maybe_put(:language_code, language_code(option(attrs, :language_code)))
  end

  def build_delete_my_commands(attrs \\ %{}) do
    %{_method: :delete_my_commands}
    |> maybe_put(:scope, optional_map(option(attrs, :scope), :scope))
    |> maybe_put(:language_code, language_code(option(attrs, :language_code)))
  end

  def build_get_my_commands(attrs \\ %{}) do
    %{_method: :get_my_commands}
    |> maybe_put(:scope, optional_map(option(attrs, :scope), :scope))
    |> maybe_put(:language_code, language_code(option(attrs, :language_code)))
  end

  def build_set_my_name(attrs \\ %{}) do
    %{_method: :set_my_name}
    |> maybe_put(:name, bounded_string_or_empty!(option(attrs, :name), :name, 0, 64))
    |> maybe_put(:language_code, language_code(option(attrs, :language_code)))
  end

  def build_get_my_name(attrs \\ %{}) do
    %{_method: :get_my_name}
    |> maybe_put(:language_code, language_code(option(attrs, :language_code)))
  end

  def build_set_my_description(attrs \\ %{}) do
    %{_method: :set_my_description}
    |> maybe_put(
      :description,
      bounded_string_or_empty!(option(attrs, :description), :description, 0, 512)
    )
    |> maybe_put(:language_code, language_code(option(attrs, :language_code)))
  end

  def build_get_my_description(attrs \\ %{}) do
    %{_method: :get_my_description}
    |> maybe_put(:language_code, language_code(option(attrs, :language_code)))
  end

  def build_set_my_short_description(attrs \\ %{}) do
    %{_method: :set_my_short_description}
    |> maybe_put(
      :short_description,
      bounded_string_or_empty!(option(attrs, :short_description), :short_description, 0, 120)
    )
    |> maybe_put(:language_code, language_code(option(attrs, :language_code)))
  end

  def build_get_my_short_description(attrs \\ %{}) do
    %{_method: :get_my_short_description}
    |> maybe_put(:language_code, language_code(option(attrs, :language_code)))
  end

  def build_set_my_profile_photo(%{photo: photo}) do
    %{
      _method: :set_my_profile_photo,
      photo: normalize_non_empty_map!(photo, :photo)
    }
  end

  def build_remove_my_profile_photo(_attrs \\ %{}), do: %{_method: :remove_my_profile_photo}

  def build_set_chat_menu_button(attrs \\ %{}) do
    %{_method: :set_chat_menu_button}
    |> maybe_put(:chat_id, optional_positive_integer(option(attrs, :chat_id), :chat_id))
    |> maybe_put(:menu_button, optional_map(option(attrs, :menu_button), :menu_button))
  end

  def build_get_chat_menu_button(attrs \\ %{}) do
    %{_method: :get_chat_menu_button}
    |> maybe_put(:chat_id, optional_positive_integer(option(attrs, :chat_id), :chat_id))
  end

  def build_set_my_default_administrator_rights(attrs \\ %{}) do
    %{_method: :set_my_default_administrator_rights}
    |> maybe_put(:rights, optional_map(option(attrs, :rights), :rights))
    |> maybe_put(:for_channels, option(attrs, :for_channels))
  end

  def build_get_my_default_administrator_rights(attrs \\ %{}) do
    %{_method: :get_my_default_administrator_rights}
    |> maybe_put(:for_channels, option(attrs, :for_channels))
  end

  def build_post_story(
        %{
          business_connection_id: business_connection_id,
          content: content,
          active_period: active_period
        } =
          attrs
      ) do
    %{
      _method: :post_story,
      business_connection_id: non_empty_string!(business_connection_id, :business_connection_id),
      content: normalize_story_content!(content),
      active_period: normalize_story_active_period!(active_period)
    }
    |> maybe_put_story_caption(attrs)
    |> maybe_put(:areas, normalize_story_areas(option(attrs, :areas)))
    |> maybe_put(:post_to_chat_page, option(attrs, :post_to_chat_page))
    |> maybe_put(:protect_content, option(attrs, :protect_content))
  end

  def build_repost_story(
        %{
          business_connection_id: business_connection_id,
          from_chat_id: from_chat_id,
          from_story_id: from_story_id,
          active_period: active_period
        } = attrs
      ) do
    %{
      _method: :repost_story,
      business_connection_id: non_empty_string!(business_connection_id, :business_connection_id),
      from_chat_id: normalize_chat_id!(from_chat_id, :from_chat_id),
      from_story_id: normalize_positive_integer!(from_story_id, :from_story_id),
      active_period: normalize_story_active_period!(active_period)
    }
    |> maybe_put(:post_to_chat_page, option(attrs, :post_to_chat_page))
    |> maybe_put(:protect_content, option(attrs, :protect_content))
  end

  def build_edit_story(
        %{business_connection_id: business_connection_id, story_id: story_id, content: content} =
          attrs
      ) do
    %{
      _method: :edit_story,
      business_connection_id: non_empty_string!(business_connection_id, :business_connection_id),
      story_id: normalize_positive_integer!(story_id, :story_id),
      content: normalize_story_content!(content)
    }
    |> maybe_put_story_caption(attrs)
    |> maybe_put(:areas, normalize_story_areas(option(attrs, :areas)))
  end

  def build_delete_story(%{business_connection_id: business_connection_id, story_id: story_id}) do
    %{
      _method: :delete_story,
      business_connection_id: non_empty_string!(business_connection_id, :business_connection_id),
      story_id: normalize_positive_integer!(story_id, :story_id)
    }
  end

  def build_send_message(%{conversation_id: cid, text: text} = attrs) do
    validate_conversation_id!(cid)

    base = %{
      chat_id: ConversationId.chat_id(cid),
      text: Format.to_html(text),
      parse_mode: "HTML",
      disable_web_page_preview: true
    }

    base
    |> maybe_put_thread(cid)
    |> maybe_put(:reply_parameters, reply_parameters(attrs))
    |> maybe_put(:reply_markup, reply_markup_from_attrs(attrs))
  end

  def build_plain_message(%{conversation_id: cid, text: text} = attrs) do
    validate_conversation_id!(cid)

    %{chat_id: ConversationId.chat_id(cid), text: Format.plain(text)}
    |> maybe_put_thread(cid)
    |> maybe_put(:reply_parameters, reply_parameters(attrs))
    |> maybe_put(:reply_markup, reply_markup_from_attrs(attrs))
  end

  def build_send_message_draft(%{conversation_id: cid, draft_id: draft_id} = attrs) do
    validate_conversation_id!(cid)

    text = Map.get(attrs, :text, Map.get(attrs, "text", ""))

    %{
      _method: :send_message_draft,
      chat_id: ConversationId.chat_id(cid),
      draft_id: normalize_draft_id!(draft_id),
      text: Format.to_html(text)
    }
    |> maybe_put_text_parse_mode(text)
    |> maybe_put_thread(cid)
  end

  def build_send_photo(%{conversation_id: cid, photo: photo} = attrs) do
    validate_conversation_id!(cid)

    %{
      _method: :send_photo,
      chat_id: ConversationId.chat_id(cid),
      photo: photo,
      caption: Format.to_html(Map.get(attrs, :caption, Map.get(attrs, :text, ""))),
      parse_mode: "HTML"
    }
    |> maybe_put_thread(cid)
    |> maybe_put_common(attrs)
    |> maybe_put(:reply_parameters, reply_parameters(attrs))
    |> maybe_put(:reply_markup, reply_markup_from_attrs(attrs))
  end

  def build_send_media(%{conversation_id: cid, media_type: type, media: media} = attrs) do
    validate_conversation_id!(cid)

    %{_method: media_method(type), chat_id: ConversationId.chat_id(cid)}
    |> Map.put(media_field(type), non_empty_string!(media, media_field(type)))
    |> maybe_put_media_caption(attrs, type)
    |> maybe_put_thread(cid)
    |> maybe_put_common(attrs)
    |> maybe_put(:reply_parameters, reply_parameters(attrs))
    |> maybe_put(:reply_markup, reply_markup_from_attrs(attrs))
  end

  def build_send_video_note(%{conversation_id: cid, video_note: video_note} = attrs) do
    validate_conversation_id!(cid)

    %{
      _method: :send_video_note,
      chat_id: ConversationId.chat_id(cid),
      video_note: non_empty_string!(video_note, :video_note)
    }
    |> maybe_put_thread(cid)
    |> maybe_put_common(attrs)
    |> maybe_put(:reply_parameters, reply_parameters(attrs))
    |> maybe_put(:reply_markup, reply_markup_from_attrs(attrs))
    |> maybe_put(:duration, option(attrs, :duration))
    |> maybe_put(:length, option(attrs, :length))
    |> maybe_put(:thumbnail, option(attrs, :thumbnail))
  end

  def build_send_live_photo(%{conversation_id: cid, live_photo: live_photo, photo: photo} = attrs) do
    validate_conversation_id!(cid)

    %{
      _method: :send_live_photo,
      chat_id: ConversationId.chat_id(cid),
      live_photo: non_empty_string!(live_photo, :live_photo),
      photo: non_empty_string!(photo, :photo)
    }
    |> maybe_put_media_caption(attrs, :live_photo)
    |> maybe_put_thread(cid)
    |> maybe_put_common(attrs)
    |> maybe_put(:reply_parameters, reply_parameters(attrs))
    |> maybe_put(:reply_markup, reply_markup_from_attrs(attrs))
    |> maybe_put(:show_caption_above_media, option(attrs, :show_caption_above_media))
  end

  def build_send_sticker(%{conversation_id: cid, sticker: sticker} = attrs) do
    validate_conversation_id!(cid)

    %{
      _method: :send_sticker,
      chat_id: ConversationId.chat_id(cid),
      sticker: non_empty_string!(sticker, :sticker)
    }
    |> maybe_put_thread(cid)
    |> maybe_put_common(attrs)
    |> maybe_put(:reply_parameters, reply_parameters(attrs))
    |> maybe_put(:reply_markup, reply_markup_from_attrs(attrs))
    |> maybe_put(:emoji, option(attrs, :emoji))
    |> maybe_put(:business_connection_id, option(attrs, :business_connection_id))
    |> maybe_put(:suggested_post_parameters, option(attrs, :suggested_post_parameters))
  end

  def build_send_media_group(%{conversation_id: cid, media: media} = attrs) do
    validate_conversation_id!(cid)

    %{
      _method: :send_media_group,
      chat_id: ConversationId.chat_id(cid),
      media: normalize_media_group!(media)
    }
    |> maybe_put_thread(cid)
    |> maybe_put_common(Map.delete(Map.delete(attrs, :spoiler), "spoiler"))
    |> maybe_put(:reply_parameters, reply_parameters(attrs))
  end

  def build_send_paid_media(%{conversation_id: cid, star_count: star_count, media: media} = attrs) do
    validate_conversation_id!(cid)

    %{
      _method: :send_paid_media,
      chat_id: ConversationId.chat_id(cid),
      star_count: bounded_integer!(star_count, :star_count, 1, 25_000),
      media: normalize_paid_media!(media)
    }
    |> maybe_put_thread(cid)
    |> maybe_put_common(attrs)
    |> maybe_put(:business_connection_id, option(attrs, :business_connection_id))
    |> maybe_put(:direct_messages_topic_id, option(attrs, :direct_messages_topic_id))
    |> maybe_put(:payload, bounded_bytes!(option(attrs, :payload), :payload, 0, 128))
    |> maybe_put(:caption, paid_caption(attrs))
    |> maybe_put(:parse_mode, paid_caption_parse_mode(attrs))
    |> maybe_put(:caption_entities, option(attrs, :caption_entities))
    |> maybe_put(:show_caption_above_media, option(attrs, :show_caption_above_media))
    |> maybe_put(:suggested_post_parameters, option(attrs, :suggested_post_parameters))
    |> maybe_put(:reply_markup, inline_reply_markup_from_attrs(attrs))
  end

  def build_send_rich_message(%{conversation_id: cid, rich_message: rich_message} = attrs) do
    validate_conversation_id!(cid)

    %{
      _method: :send_rich_message,
      chat_id: ConversationId.chat_id(cid),
      rich_message: normalize_rich_message!(rich_message)
    }
    |> maybe_put_thread(cid)
    |> maybe_put_common(attrs)
    |> maybe_put(:reply_parameters, reply_parameters(attrs))
    |> maybe_put(:reply_markup, reply_markup_from_attrs(attrs))
  end

  def build_send_rich_message_draft(%{
        conversation_id: cid,
        draft_id: draft_id,
        rich_message: rich_message
      }) do
    validate_conversation_id!(cid)

    %{
      _method: :send_rich_message_draft,
      chat_id: ConversationId.chat_id(cid),
      draft_id: normalize_draft_id!(draft_id),
      rich_message: normalize_rich_message!(rich_message)
    }
    |> maybe_put_thread(cid)
  end

  def build_edit_rich_message(
        %{
          conversation_id: cid,
          message_id: message_id,
          rich_message: rich_message
        } = attrs
      ) do
    validate_conversation_id!(cid)

    %{
      _method: :edit_message_text,
      chat_id: ConversationId.chat_id(cid),
      message_id: normalize_message_id!(message_id),
      rich_message: normalize_rich_message!(rich_message)
    }
    |> maybe_put_thread(cid)
    |> maybe_put(:reply_markup, inline_reply_markup_from_attrs(attrs))
  end

  def build_edit_message_text(
        %{
          conversation_id: cid,
          message_id: message_id,
          text: text
        } = attrs
      ) do
    validate_conversation_id!(cid)

    %{
      _method: :edit_message_text,
      chat_id: ConversationId.chat_id(cid),
      message_id: normalize_message_id!(message_id),
      text: Format.to_html(non_empty_string!(text, :text)),
      parse_mode: "HTML"
    }
    |> maybe_put_thread(cid)
    |> maybe_put(:link_preview_options, option(attrs, :link_preview_options))
    |> maybe_put(:reply_markup, inline_reply_markup_from_attrs(attrs))
  end

  def build_edit_message_caption(
        %{
          conversation_id: cid,
          message_id: message_id
        } = attrs
      ) do
    validate_conversation_id!(cid)

    %{
      _method: :edit_message_caption,
      chat_id: ConversationId.chat_id(cid),
      message_id: normalize_message_id!(message_id)
    }
    |> maybe_put_thread(cid)
    |> maybe_put(:caption, edit_caption(attrs))
    |> maybe_put(:parse_mode, edit_caption_parse_mode(attrs))
    |> maybe_put(:show_caption_above_media, option(attrs, :show_caption_above_media))
    |> maybe_put(:reply_markup, inline_reply_markup_from_attrs(attrs))
  end

  def build_edit_message_reply_markup(
        %{
          conversation_id: cid,
          message_id: message_id
        } = attrs
      ) do
    validate_conversation_id!(cid)

    %{
      _method: :edit_message_reply_markup,
      chat_id: ConversationId.chat_id(cid),
      message_id: normalize_message_id!(message_id)
    }
    |> maybe_put_thread(cid)
    |> maybe_put(:reply_markup, inline_reply_markup_from_attrs(attrs))
  end

  def build_stop_poll(
        %{
          conversation_id: cid,
          message_id: message_id
        } = attrs
      ) do
    validate_conversation_id!(cid)

    %{
      _method: :stop_poll,
      chat_id: ConversationId.chat_id(cid),
      message_id: normalize_message_id!(message_id)
    }
    |> maybe_put(:reply_markup, inline_reply_markup_from_attrs(attrs))
    |> maybe_put(:business_connection_id, option(attrs, :business_connection_id))
  end

  def build_edit_message_media(
        %{
          conversation_id: cid,
          message_id: message_id
        } = attrs
      ) do
    validate_conversation_id!(cid)

    %{
      _method: :edit_message_media,
      chat_id: ConversationId.chat_id(cid),
      message_id: normalize_message_id!(message_id),
      media: edit_media!(attrs)
    }
    |> maybe_put_thread(cid)
    |> maybe_put(:reply_markup, inline_reply_markup_from_attrs(attrs))
  end

  def build_edit_live_location(
        %{
          conversation_id: cid,
          message_id: message_id,
          latitude: latitude,
          longitude: longitude
        } = attrs
      ) do
    validate_conversation_id!(cid)

    %{
      _method: :edit_message_live_location,
      chat_id: ConversationId.chat_id(cid),
      message_id: normalize_message_id!(message_id),
      latitude: normalize_coordinate!(latitude, :latitude),
      longitude: normalize_coordinate!(longitude, :longitude)
    }
    |> maybe_put_thread(cid)
    |> maybe_put(:reply_markup, inline_reply_markup_from_attrs(attrs))
    |> maybe_put(:horizontal_accuracy, option(attrs, :horizontal_accuracy))
    |> maybe_put(:heading, option(attrs, :heading))
    |> maybe_put(:proximity_alert_radius, option(attrs, :proximity_alert_radius))
    |> maybe_put(:business_connection_id, option(attrs, :business_connection_id))
  end

  def build_stop_live_location(
        %{
          conversation_id: cid,
          message_id: message_id
        } = attrs
      ) do
    validate_conversation_id!(cid)

    %{
      _method: :stop_message_live_location,
      chat_id: ConversationId.chat_id(cid),
      message_id: normalize_message_id!(message_id)
    }
    |> maybe_put_thread(cid)
    |> maybe_put(:reply_markup, inline_reply_markup_from_attrs(attrs))
    |> maybe_put(:business_connection_id, option(attrs, :business_connection_id))
  end

  def build_edit_message_checklist(
        %{
          conversation_id: cid,
          message_id: message_id
        } = attrs
      ) do
    validate_conversation_id!(cid)

    %{
      _method: :edit_message_checklist,
      chat_id: ConversationId.chat_id(cid),
      message_id: normalize_message_id!(message_id),
      business_connection_id:
        non_empty_string!(option(attrs, :business_connection_id), :business_connection_id),
      checklist: normalize_input_checklist!(attrs)
    }
    |> maybe_put(:reply_markup, inline_reply_markup_from_attrs(attrs))
  end

  def build_send_poll(%{conversation_id: cid, question: question, options: options} = attrs) do
    validate_conversation_id!(cid)

    %{
      _method: :send_poll,
      chat_id: ConversationId.chat_id(cid),
      question: non_empty_string!(to_string(question), :question),
      options: normalize_poll_options!(options)
    }
    |> maybe_put_thread(cid)
    |> maybe_put_common(attrs)
    |> maybe_put(:reply_parameters, reply_parameters(attrs))
    |> maybe_put(:reply_markup, reply_markup_from_attrs(attrs))
    |> maybe_put(:is_anonymous, option(attrs, :is_anonymous))
    |> maybe_put(:allows_multiple_answers, option(attrs, :allows_multiple_answers))
    |> maybe_put(:allows_revoting, option(attrs, :allows_revoting))
    |> maybe_put(:shuffle_options, option(attrs, :shuffle_options))
    |> maybe_put(:allow_adding_options, option(attrs, :allow_adding_options))
    |> maybe_put(:hide_results_until_closes, option(attrs, :hide_results_until_closes))
    |> maybe_put(:members_only, option(attrs, :members_only))
    |> maybe_put(:country_codes, option(attrs, :country_codes))
    |> maybe_put(:type, option(attrs, :poll_type) || option(attrs, :type))
    |> maybe_put(:correct_option_ids, correct_option_ids(attrs))
    |> maybe_put(:explanation, option(attrs, :explanation))
    |> maybe_put(:explanation_media, option(attrs, :explanation_media))
    |> maybe_put(:description, option(attrs, :description))
    |> maybe_put(:media, option(attrs, :media))
  end

  def build_send_checklist(%{conversation_id: cid} = attrs) do
    validate_conversation_id!(cid)

    %{
      _method: :send_checklist,
      chat_id: ConversationId.chat_id(cid),
      business_connection_id:
        non_empty_string!(option(attrs, :business_connection_id), :business_connection_id),
      checklist: normalize_input_checklist!(attrs)
    }
    |> maybe_put(:disable_notification, option(attrs, :disable_notification))
    |> maybe_put(:protect_content, option(attrs, :protect_content))
    |> maybe_put(:message_effect_id, option(attrs, :message_effect_id))
    |> maybe_put(:reply_parameters, reply_parameters(attrs))
    |> maybe_put(:reply_markup, inline_reply_markup_from_attrs(attrs))
  end

  def build_send_location(
        %{conversation_id: cid, latitude: latitude, longitude: longitude} = attrs
      ) do
    validate_conversation_id!(cid)

    %{
      _method: :send_location,
      chat_id: ConversationId.chat_id(cid),
      latitude: normalize_coordinate!(latitude, :latitude),
      longitude: normalize_coordinate!(longitude, :longitude)
    }
    |> maybe_put_thread(cid)
    |> maybe_put_common(attrs)
    |> maybe_put(:reply_parameters, reply_parameters(attrs))
    |> maybe_put(:reply_markup, reply_markup_from_attrs(attrs))
    |> maybe_put(:horizontal_accuracy, option(attrs, :horizontal_accuracy))
    |> maybe_put(:live_period, option(attrs, :live_period))
    |> maybe_put(:heading, option(attrs, :heading))
    |> maybe_put(:proximity_alert_radius, option(attrs, :proximity_alert_radius))
  end

  def build_send_venue(
        %{
          conversation_id: cid,
          latitude: latitude,
          longitude: longitude,
          title: title,
          address: address
        } = attrs
      ) do
    validate_conversation_id!(cid)

    %{
      _method: :send_venue,
      chat_id: ConversationId.chat_id(cid),
      latitude: normalize_coordinate!(latitude, :latitude),
      longitude: normalize_coordinate!(longitude, :longitude),
      title: non_empty_string!(title, :title),
      address: non_empty_string!(address, :address)
    }
    |> maybe_put_thread(cid)
    |> maybe_put_common(attrs)
    |> maybe_put(:reply_parameters, reply_parameters(attrs))
    |> maybe_put(:reply_markup, reply_markup_from_attrs(attrs))
    |> maybe_put(:foursquare_id, option(attrs, :foursquare_id))
    |> maybe_put(:foursquare_type, option(attrs, :foursquare_type))
    |> maybe_put(:google_place_id, option(attrs, :google_place_id))
    |> maybe_put(:google_place_type, option(attrs, :google_place_type))
  end

  def build_send_contact(
        %{conversation_id: cid, phone_number: phone_number, first_name: first_name} = attrs
      ) do
    validate_conversation_id!(cid)

    %{
      _method: :send_contact,
      chat_id: ConversationId.chat_id(cid),
      phone_number: non_empty_string!(phone_number, :phone_number),
      first_name: non_empty_string!(first_name, :first_name)
    }
    |> maybe_put_thread(cid)
    |> maybe_put_common(attrs)
    |> maybe_put(:reply_parameters, reply_parameters(attrs))
    |> maybe_put(:reply_markup, reply_markup_from_attrs(attrs))
    |> maybe_put(:last_name, option(attrs, :last_name))
    |> maybe_put(:vcard, option(attrs, :vcard))
  end

  def build_send_dice(%{conversation_id: cid} = attrs) do
    validate_conversation_id!(cid)

    %{
      _method: :send_dice,
      chat_id: ConversationId.chat_id(cid)
    }
    |> maybe_put_thread(cid)
    |> maybe_put_common(attrs)
    |> maybe_put(:reply_parameters, reply_parameters(attrs))
    |> maybe_put(:reply_markup, reply_markup_from_attrs(attrs))
    |> maybe_put(:emoji, option(attrs, :emoji))
  end

  def build_send_invoice(
        %{
          conversation_id: cid,
          title: title,
          description: description,
          payload: payload,
          currency: currency,
          prices: prices
        } = attrs
      ) do
    validate_conversation_id!(cid)

    currency = normalize_currency!(currency)

    %{
      _method: :send_invoice,
      chat_id: ConversationId.chat_id(cid),
      title: bounded_string!(title, :title, 1, 32),
      description: bounded_string!(description, :description, 1, 255),
      payload: bounded_bytes!(payload, :payload, 1, 128),
      provider_token: provider_token(attrs, currency),
      currency: currency,
      prices: normalize_labeled_prices!(prices, currency)
    }
    |> maybe_put_thread(cid)
    |> maybe_put(:direct_messages_topic_id, option(attrs, :direct_messages_topic_id))
    |> maybe_put(:max_tip_amount, option(attrs, :max_tip_amount))
    |> maybe_put(:suggested_tip_amounts, suggested_tip_amounts(attrs))
    |> maybe_put(:start_parameter, option(attrs, :start_parameter))
    |> maybe_put(:provider_data, option(attrs, :provider_data))
    |> maybe_put(:photo_url, safe_optional_url!(option(attrs, :photo_url), :photo_url))
    |> maybe_put(:photo_size, option(attrs, :photo_size))
    |> maybe_put(:photo_width, option(attrs, :photo_width))
    |> maybe_put(:photo_height, option(attrs, :photo_height))
    |> maybe_put(:need_name, option(attrs, :need_name))
    |> maybe_put(:need_phone_number, option(attrs, :need_phone_number))
    |> maybe_put(:need_email, option(attrs, :need_email))
    |> maybe_put(:need_shipping_address, option(attrs, :need_shipping_address))
    |> maybe_put(:send_phone_number_to_provider, option(attrs, :send_phone_number_to_provider))
    |> maybe_put(:send_email_to_provider, option(attrs, :send_email_to_provider))
    |> maybe_put(:is_flexible, option(attrs, :is_flexible))
    |> maybe_put_common(attrs)
    |> maybe_put(:suggested_post_parameters, option(attrs, :suggested_post_parameters))
    |> maybe_put(:reply_parameters, reply_parameters(attrs))
    |> maybe_put(:reply_markup, invoice_reply_markup_from_attrs(attrs))
  end

  def build_create_invoice_link(
        %{
          title: title,
          description: description,
          payload: payload,
          currency: currency,
          prices: prices
        } =
          attrs
      ) do
    currency = normalize_currency!(currency)

    %{
      _method: :create_invoice_link,
      title: bounded_string!(title, :title, 1, 32),
      description: bounded_string!(description, :description, 1, 255),
      payload: bounded_bytes!(payload, :payload, 1, 128),
      provider_token: provider_token(attrs, currency),
      currency: currency,
      prices: normalize_labeled_prices!(prices, currency)
    }
    |> maybe_put(:business_connection_id, option(attrs, :business_connection_id))
    |> maybe_put(:subscription_period, subscription_period(attrs, currency))
    |> maybe_put(:max_tip_amount, option(attrs, :max_tip_amount))
    |> maybe_put(:suggested_tip_amounts, suggested_tip_amounts(attrs))
    |> maybe_put(:provider_data, option(attrs, :provider_data))
    |> maybe_put(:photo_url, safe_optional_url!(option(attrs, :photo_url), :photo_url))
    |> maybe_put(:photo_size, option(attrs, :photo_size))
    |> maybe_put(:photo_width, option(attrs, :photo_width))
    |> maybe_put(:photo_height, option(attrs, :photo_height))
    |> maybe_put(:need_name, option(attrs, :need_name))
    |> maybe_put(:need_phone_number, option(attrs, :need_phone_number))
    |> maybe_put(:need_email, option(attrs, :need_email))
    |> maybe_put(:need_shipping_address, option(attrs, :need_shipping_address))
    |> maybe_put(:send_phone_number_to_provider, option(attrs, :send_phone_number_to_provider))
    |> maybe_put(:send_email_to_provider, option(attrs, :send_email_to_provider))
    |> maybe_put(:is_flexible, option(attrs, :is_flexible))
  end

  def build_answer_shipping_query(%{shipping_query_id: shipping_query_id, ok: ok} = attrs) do
    ok? = truthy_boolean!(ok, :ok)

    %{
      _method: :answer_shipping_query,
      shipping_query_id: non_empty_string!(shipping_query_id, :shipping_query_id),
      ok: ok?
    }
    |> maybe_put_shipping_answer(ok?, attrs)
  end

  def build_answer_pre_checkout_query(%{pre_checkout_query_id: query_id, ok: ok} = attrs) do
    ok? = truthy_boolean!(ok, :ok)

    %{
      _method: :answer_pre_checkout_query,
      pre_checkout_query_id: non_empty_string!(query_id, :pre_checkout_query_id),
      ok: ok?
    }
    |> maybe_put_error_message(ok?, attrs)
  end

  def build_get_my_star_balance(_attrs \\ %{}), do: %{_method: :get_my_star_balance}

  def build_get_star_transactions(attrs \\ %{}) do
    %{_method: :get_star_transactions}
    |> maybe_put(:offset, non_negative_integer(option(attrs, :offset), :offset))
    |> maybe_put(:limit, bounded_optional_integer!(option(attrs, :limit), :limit, 1, 100))
  end

  def build_get_available_gifts(_attrs \\ %{}), do: %{_method: :get_available_gifts}

  def build_send_gift(%{gift_id: gift_id} = attrs) do
    %{
      _method: :send_gift,
      gift_id: non_empty_string!(gift_id, :gift_id)
    }
    |> maybe_put_gift_recipient(attrs)
    |> maybe_put(:pay_for_upgrade, option(attrs, :pay_for_upgrade))
    |> maybe_put_gift_text(attrs)
  end

  def build_gift_premium_subscription(
        %{user_id: user_id, month_count: month_count, star_count: star_count} = attrs
      ) do
    month_count = normalize_integer!(month_count, :month_count)
    star_count = normalize_integer!(star_count, :star_count)

    unless {month_count, star_count} in [{3, 1000}, {6, 1500}, {12, 2500}] do
      raise ArgumentError,
            "gift premium subscription requires 1000 Stars for 3 months, 1500 for 6, or 2500 for 12"
    end

    %{
      _method: :gift_premium_subscription,
      user_id: normalize_positive_integer!(user_id, :user_id),
      month_count: month_count,
      star_count: star_count
    }
    |> maybe_put_gift_text(attrs)
  end

  def build_get_business_account_star_balance(%{business_connection_id: business_connection_id}) do
    %{
      _method: :get_business_account_star_balance,
      business_connection_id: non_empty_string!(business_connection_id, :business_connection_id)
    }
  end

  def build_transfer_business_account_stars(%{
        business_connection_id: business_connection_id,
        star_count: star_count
      }) do
    %{
      _method: :transfer_business_account_stars,
      business_connection_id: non_empty_string!(business_connection_id, :business_connection_id),
      star_count: bounded_integer!(star_count, :star_count, 1, 10_000)
    }
  end

  def build_get_business_account_gifts(%{business_connection_id: business_connection_id} = attrs) do
    %{
      _method: :get_business_account_gifts,
      business_connection_id: non_empty_string!(business_connection_id, :business_connection_id)
    }
    |> maybe_put_gift_filters(attrs, [:exclude_unsaved, :exclude_saved, :exclude_unique])
  end

  def build_get_user_gifts(%{user_id: user_id} = attrs) do
    %{
      _method: :get_user_gifts,
      user_id: normalize_positive_integer!(user_id, :user_id)
    }
    |> maybe_put_gift_filters(attrs, [:exclude_unique])
  end

  def build_get_chat_gifts(%{chat_id: chat_id} = attrs) do
    %{
      _method: :get_chat_gifts,
      chat_id: normalize_chat_id!(chat_id, :chat_id)
    }
    |> maybe_put_gift_filters(attrs, [:exclude_unsaved, :exclude_saved, :exclude_unique])
  end

  def build_convert_gift_to_stars(%{
        business_connection_id: business_connection_id,
        owned_gift_id: owned_gift_id
      }) do
    %{
      _method: :convert_gift_to_stars,
      business_connection_id: non_empty_string!(business_connection_id, :business_connection_id),
      owned_gift_id: non_empty_string!(owned_gift_id, :owned_gift_id)
    }
  end

  def build_upgrade_gift(
        %{
          business_connection_id: business_connection_id,
          owned_gift_id: owned_gift_id
        } = attrs
      ) do
    %{
      _method: :upgrade_gift,
      business_connection_id: non_empty_string!(business_connection_id, :business_connection_id),
      owned_gift_id: non_empty_string!(owned_gift_id, :owned_gift_id)
    }
    |> maybe_put(:keep_original_details, option(attrs, :keep_original_details))
    |> maybe_put(:star_count, non_negative_integer(option(attrs, :star_count), :star_count))
  end

  def build_transfer_gift(
        %{
          business_connection_id: business_connection_id,
          owned_gift_id: owned_gift_id,
          new_owner_chat_id: new_owner_chat_id
        } = attrs
      ) do
    %{
      _method: :transfer_gift,
      business_connection_id: non_empty_string!(business_connection_id, :business_connection_id),
      owned_gift_id: non_empty_string!(owned_gift_id, :owned_gift_id),
      new_owner_chat_id: normalize_chat_id!(new_owner_chat_id, :new_owner_chat_id)
    }
    |> maybe_put(:star_count, non_negative_integer(option(attrs, :star_count), :star_count))
  end

  def build_verify_user(%{user_id: user_id} = attrs) do
    %{
      _method: :verify_user,
      user_id: normalize_positive_integer!(user_id, :user_id)
    }
    |> maybe_put(
      :custom_description,
      bounded_string_or_empty!(option(attrs, :custom_description), :custom_description, 0, 70)
    )
  end

  def build_verify_chat(%{chat_id: chat_id} = attrs) do
    %{
      _method: :verify_chat,
      chat_id: normalize_chat_id!(chat_id, :chat_id)
    }
    |> maybe_put(
      :custom_description,
      bounded_string_or_empty!(option(attrs, :custom_description), :custom_description, 0, 70)
    )
  end

  def build_remove_user_verification(%{user_id: user_id}) do
    %{
      _method: :remove_user_verification,
      user_id: normalize_positive_integer!(user_id, :user_id)
    }
  end

  def build_remove_chat_verification(%{chat_id: chat_id}) do
    %{
      _method: :remove_chat_verification,
      chat_id: normalize_chat_id!(chat_id, :chat_id)
    }
  end

  def build_read_business_message(%{
        business_connection_id: business_connection_id,
        chat_id: chat_id,
        message_id: message_id
      }) do
    %{
      _method: :read_business_message,
      business_connection_id: non_empty_string!(business_connection_id, :business_connection_id),
      chat_id: normalize_integer!(chat_id, :chat_id),
      message_id: normalize_message_id!(message_id)
    }
  end

  def build_delete_business_messages(%{
        business_connection_id: business_connection_id,
        message_ids: message_ids
      }) do
    %{
      _method: :delete_business_messages,
      business_connection_id: non_empty_string!(business_connection_id, :business_connection_id),
      message_ids: normalize_message_ids!(message_ids)
    }
  end

  def build_set_business_account_name(
        %{business_connection_id: business_connection_id, first_name: first_name} = attrs
      ) do
    %{
      _method: :set_business_account_name,
      business_connection_id: non_empty_string!(business_connection_id, :business_connection_id),
      first_name: bounded_string!(first_name, :first_name, 1, 64)
    }
    |> maybe_put(
      :last_name,
      bounded_string_or_empty!(option(attrs, :last_name), :last_name, 0, 64)
    )
  end

  def build_set_business_account_username(
        %{business_connection_id: business_connection_id} = attrs
      ) do
    %{
      _method: :set_business_account_username,
      business_connection_id: non_empty_string!(business_connection_id, :business_connection_id)
    }
    |> maybe_put(:username, bounded_string_or_empty!(option(attrs, :username), :username, 0, 32))
  end

  def build_set_business_account_bio(%{business_connection_id: business_connection_id} = attrs) do
    %{
      _method: :set_business_account_bio,
      business_connection_id: non_empty_string!(business_connection_id, :business_connection_id)
    }
    |> maybe_put(:bio, bounded_string_or_empty!(option(attrs, :bio), :bio, 0, 140))
  end

  def build_set_business_account_profile_photo(
        %{business_connection_id: business_connection_id, photo: photo} = attrs
      ) do
    %{
      _method: :set_business_account_profile_photo,
      business_connection_id: non_empty_string!(business_connection_id, :business_connection_id),
      photo: normalize_non_empty_map!(photo, :photo)
    }
    |> maybe_put(:is_public, option(attrs, :is_public))
  end

  def build_remove_business_account_profile_photo(
        %{business_connection_id: business_connection_id} = attrs
      ) do
    %{
      _method: :remove_business_account_profile_photo,
      business_connection_id: non_empty_string!(business_connection_id, :business_connection_id)
    }
    |> maybe_put(:is_public, option(attrs, :is_public))
  end

  def build_set_business_account_gift_settings(%{
        business_connection_id: business_connection_id,
        show_gift_button: show_gift_button,
        accepted_gift_types: accepted_gift_types
      }) do
    %{
      _method: :set_business_account_gift_settings,
      business_connection_id: non_empty_string!(business_connection_id, :business_connection_id),
      show_gift_button: truthy_boolean!(show_gift_button, :show_gift_button),
      accepted_gift_types: normalize_accepted_gift_types!(accepted_gift_types)
    }
  end

  def build_approve_suggested_post(%{chat_id: chat_id, message_id: message_id} = attrs) do
    %{
      _method: :approve_suggested_post,
      chat_id: normalize_integer!(chat_id, :chat_id),
      message_id: normalize_message_id!(message_id)
    }
    |> maybe_put(:send_date, non_negative_integer(option(attrs, :send_date), :send_date))
  end

  def build_decline_suggested_post(%{chat_id: chat_id, message_id: message_id} = attrs) do
    %{
      _method: :decline_suggested_post,
      chat_id: normalize_integer!(chat_id, :chat_id),
      message_id: normalize_message_id!(message_id)
    }
    |> maybe_put(:comment, bounded_string_or_empty!(option(attrs, :comment), :comment, 0, 128))
  end

  def build_set_passport_data_errors(%{user_id: user_id, errors: errors}) do
    %{
      _method: :set_passport_data_errors,
      user_id: normalize_positive_integer!(user_id, :user_id),
      errors: normalize_passport_errors!(errors)
    }
  end

  def build_set_game_score(%{user_id: user_id, score: score} = attrs) do
    %{
      _method: :set_game_score,
      user_id: normalize_positive_integer!(user_id, :user_id),
      score: non_negative_integer!(score, :score)
    }
    |> maybe_put(:force, option(attrs, :force))
    |> maybe_put(:disable_edit_message, option(attrs, :disable_edit_message))
    |> maybe_put_game_message_target(attrs)
  end

  def build_get_game_high_scores(%{user_id: user_id} = attrs) do
    %{
      _method: :get_game_high_scores,
      user_id: normalize_positive_integer!(user_id, :user_id)
    }
    |> maybe_put_game_message_target(attrs)
  end

  def build_refund_star_payment(%{user_id: user_id, telegram_payment_charge_id: charge_id}) do
    %{
      _method: :refund_star_payment,
      user_id: normalize_positive_integer!(user_id, :user_id),
      telegram_payment_charge_id: non_empty_string!(charge_id, :telegram_payment_charge_id)
    }
  end

  def build_edit_user_star_subscription(%{
        user_id: user_id,
        telegram_payment_charge_id: charge_id,
        is_canceled: is_canceled
      }) do
    %{
      _method: :edit_user_star_subscription,
      user_id: normalize_positive_integer!(user_id, :user_id),
      telegram_payment_charge_id: non_empty_string!(charge_id, :telegram_payment_charge_id),
      is_canceled: truthy_boolean!(is_canceled, :is_canceled)
    }
  end

  def build_send_game(%{conversation_id: cid, game_short_name: game_short_name} = attrs) do
    validate_conversation_id!(cid)

    %{
      _method: :send_game,
      chat_id: ConversationId.chat_id(cid),
      game_short_name: non_empty_string!(game_short_name, :game_short_name)
    }
    |> maybe_put_thread(cid)
    |> maybe_put_common(attrs)
    |> maybe_put(:business_connection_id, option(attrs, :business_connection_id))
    |> maybe_put(:reply_parameters, reply_parameters(attrs))
    |> maybe_put(:reply_markup, inline_reply_markup_from_attrs(attrs))
  end

  def build_send_chat_action(%{conversation_id: cid, action: action} = attrs) do
    validate_conversation_id!(cid)

    %{
      _method: :send_chat_action,
      chat_id: ConversationId.chat_id(cid),
      action: normalize_chat_action!(action)
    }
    |> maybe_put_thread(cid)
    |> maybe_put(:business_connection_id, option(attrs, :business_connection_id))
  end

  def build_set_message_reaction(
        %{
          conversation_id: cid,
          message_id: message_id
        } = attrs
      ) do
    validate_conversation_id!(cid)

    %{
      _method: :set_message_reaction,
      chat_id: ConversationId.chat_id(cid),
      message_id: normalize_message_id!(message_id)
    }
    |> maybe_put(
      :reaction,
      normalize_reactions!(option(attrs, :reaction) || option(attrs, :reactions))
    )
    |> maybe_put(:is_big, option(attrs, :is_big))
  end

  def build_get_user_profile_photos(%{user_id: user_id} = attrs) do
    %{
      _method: :get_user_profile_photos,
      user_id: normalize_positive_integer!(user_id, :user_id)
    }
    |> maybe_put(:offset, non_negative_integer(option(attrs, :offset), :offset))
    |> maybe_put(:limit, bounded_optional_integer!(option(attrs, :limit), :limit, 1, 100))
  end

  def build_get_user_profile_audios(%{user_id: user_id} = attrs) do
    %{
      _method: :get_user_profile_audios,
      user_id: normalize_positive_integer!(user_id, :user_id)
    }
    |> maybe_put(:offset, non_negative_integer(option(attrs, :offset), :offset))
    |> maybe_put(:limit, bounded_optional_integer!(option(attrs, :limit), :limit, 1, 100))
  end

  def build_set_user_emoji_status(%{user_id: user_id} = attrs) do
    %{
      _method: :set_user_emoji_status,
      user_id: normalize_positive_integer!(user_id, :user_id)
    }
    |> maybe_put(
      :emoji_status_custom_emoji_id,
      bounded_string_or_empty!(
        option(attrs, :emoji_status_custom_emoji_id),
        :emoji_status_custom_emoji_id,
        0,
        64
      )
    )
    |> maybe_put(
      :emoji_status_expiration_date,
      non_negative_integer(
        option(attrs, :emoji_status_expiration_date),
        :emoji_status_expiration_date
      )
    )
  end

  def build_get_file(%{file_id: file_id}) do
    %{_method: :get_file, file_id: non_empty_string!(file_id, :file_id)}
  end

  def build_get_sticker_set(%{name: name}) do
    %{_method: :get_sticker_set, name: non_empty_string!(name, :name)}
  end

  def build_get_custom_emoji_stickers(%{custom_emoji_ids: ids}) do
    %{
      _method: :get_custom_emoji_stickers,
      custom_emoji_ids: normalize_string_list!(ids, :custom_emoji_ids, 1, 200)
    }
  end

  def build_upload_sticker_file(%{user_id: user_id, sticker: sticker, sticker_format: format}) do
    %{
      _method: :upload_sticker_file,
      user_id: normalize_positive_integer!(user_id, :user_id),
      sticker: non_empty_string!(sticker, :sticker),
      sticker_format: normalize_sticker_format!(format)
    }
  end

  def build_create_new_sticker_set(
        %{user_id: user_id, name: name, title: title, stickers: stickers} = attrs
      ) do
    %{
      _method: :create_new_sticker_set,
      user_id: normalize_positive_integer!(user_id, :user_id),
      name: non_empty_string!(name, :name),
      title: bounded_string!(title, :title, 1, 64),
      stickers: normalize_input_stickers!(stickers)
    }
    |> maybe_put(:sticker_type, normalize_sticker_type(option(attrs, :sticker_type)))
    |> maybe_put(:needs_repainting, option(attrs, :needs_repainting))
  end

  def build_add_sticker_to_set(%{user_id: user_id, name: name, sticker: sticker}) do
    %{
      _method: :add_sticker_to_set,
      user_id: normalize_positive_integer!(user_id, :user_id),
      name: non_empty_string!(name, :name),
      sticker: normalize_non_empty_map!(sticker, :sticker)
    }
  end

  def build_set_sticker_position_in_set(%{sticker: sticker, position: position}) do
    %{
      _method: :set_sticker_position_in_set,
      sticker: non_empty_string!(sticker, :sticker),
      position: non_negative_integer!(position, :position)
    }
  end

  def build_delete_sticker_from_set(%{sticker: sticker}) do
    %{_method: :delete_sticker_from_set, sticker: non_empty_string!(sticker, :sticker)}
  end

  def build_replace_sticker_in_set(%{
        user_id: user_id,
        name: name,
        old_sticker: old_sticker,
        sticker: sticker
      }) do
    %{
      _method: :replace_sticker_in_set,
      user_id: normalize_positive_integer!(user_id, :user_id),
      name: non_empty_string!(name, :name),
      old_sticker: non_empty_string!(old_sticker, :old_sticker),
      sticker: normalize_non_empty_map!(sticker, :sticker)
    }
  end

  def build_set_sticker_emoji_list(%{sticker: sticker, emoji_list: emoji_list}) do
    %{
      _method: :set_sticker_emoji_list,
      sticker: non_empty_string!(sticker, :sticker),
      emoji_list: normalize_string_list!(emoji_list, :emoji_list, 1, 20)
    }
  end

  def build_set_sticker_keywords(%{sticker: sticker} = attrs) do
    %{
      _method: :set_sticker_keywords,
      sticker: non_empty_string!(sticker, :sticker)
    }
    |> maybe_put(:keywords, normalize_string_list(option(attrs, :keywords), :keywords, 0, 20))
  end

  def build_set_sticker_mask_position(%{sticker: sticker} = attrs) do
    %{
      _method: :set_sticker_mask_position,
      sticker: non_empty_string!(sticker, :sticker)
    }
    |> maybe_put(:mask_position, optional_map(option(attrs, :mask_position), :mask_position))
  end

  def build_set_sticker_set_title(%{name: name, title: title}) do
    %{
      _method: :set_sticker_set_title,
      name: non_empty_string!(name, :name),
      title: bounded_string!(title, :title, 1, 64)
    }
  end

  def build_set_sticker_set_thumbnail(
        %{
          name: name,
          user_id: user_id,
          format: format
        } = attrs
      ) do
    %{
      _method: :set_sticker_set_thumbnail,
      name: non_empty_string!(name, :name),
      user_id: normalize_positive_integer!(user_id, :user_id),
      format: normalize_sticker_format!(format)
    }
    |> maybe_put(:thumbnail, option(attrs, :thumbnail))
  end

  def build_set_custom_emoji_sticker_set_thumbnail(%{name: name} = attrs) do
    %{
      _method: :set_custom_emoji_sticker_set_thumbnail,
      name: non_empty_string!(name, :name)
    }
    |> maybe_put(
      :custom_emoji_id,
      bounded_string_or_empty!(option(attrs, :custom_emoji_id), :custom_emoji_id, 0, 64)
    )
  end

  def build_delete_sticker_set(%{name: name}) do
    %{_method: :delete_sticker_set, name: non_empty_string!(name, :name)}
  end

  def build_forward_message(
        %{
          conversation_id: cid,
          from_chat_id: from_chat_id,
          message_id: message_id
        } = attrs
      ) do
    validate_conversation_id!(cid)

    %{
      _method: :forward_message,
      chat_id: ConversationId.chat_id(cid),
      from_chat_id: normalize_chat_id!(from_chat_id, :from_chat_id),
      message_id: normalize_message_id!(message_id)
    }
    |> maybe_put_thread(cid)
    |> maybe_put_common(attrs)
    |> maybe_put(:video_start_timestamp, option(attrs, :video_start_timestamp))
  end

  def build_forward_messages(
        %{
          conversation_id: cid,
          from_chat_id: from_chat_id,
          message_ids: message_ids
        } = attrs
      ) do
    validate_conversation_id!(cid)

    %{
      _method: :forward_messages,
      chat_id: ConversationId.chat_id(cid),
      from_chat_id: normalize_chat_id!(from_chat_id, :from_chat_id),
      message_ids: normalize_message_ids!(message_ids, increasing?: true)
    }
    |> maybe_put_thread(cid)
    |> maybe_put_common(attrs)
  end

  def build_copy_message(
        %{
          conversation_id: cid,
          from_chat_id: from_chat_id,
          message_id: message_id
        } = attrs
      ) do
    validate_conversation_id!(cid)

    %{
      _method: :copy_message,
      chat_id: ConversationId.chat_id(cid),
      from_chat_id: normalize_chat_id!(from_chat_id, :from_chat_id),
      message_id: normalize_message_id!(message_id)
    }
    |> maybe_put_thread(cid)
    |> maybe_put_common(attrs)
    |> maybe_put(:reply_parameters, reply_parameters(attrs))
    |> maybe_put(:reply_markup, reply_markup_from_attrs(attrs))
    |> maybe_put(:caption, edit_caption(attrs))
    |> maybe_put(:parse_mode, edit_caption_parse_mode(attrs))
    |> maybe_put(:show_caption_above_media, option(attrs, :show_caption_above_media))
    |> maybe_put(:video_start_timestamp, option(attrs, :video_start_timestamp))
  end

  def build_copy_messages(
        %{
          conversation_id: cid,
          from_chat_id: from_chat_id,
          message_ids: message_ids
        } = attrs
      ) do
    validate_conversation_id!(cid)

    %{
      _method: :copy_messages,
      chat_id: ConversationId.chat_id(cid),
      from_chat_id: normalize_chat_id!(from_chat_id, :from_chat_id),
      message_ids: normalize_message_ids!(message_ids, increasing?: true)
    }
    |> maybe_put_thread(cid)
    |> maybe_put_common(attrs)
  end

  def build_delete_message(%{conversation_id: cid, message_id: message_id}) do
    validate_conversation_id!(cid)

    %{
      _method: :delete_message,
      chat_id: ConversationId.chat_id(cid),
      message_id: normalize_message_id!(message_id)
    }
  end

  def build_delete_messages(%{conversation_id: cid, message_ids: message_ids}) do
    validate_conversation_id!(cid)

    %{
      _method: :delete_messages,
      chat_id: ConversationId.chat_id(cid),
      message_ids: normalize_message_ids!(message_ids)
    }
  end

  def build_delete_message_reaction(%{chat_id: chat_id, message_id: message_id} = attrs) do
    %{
      _method: :delete_message_reaction,
      chat_id: normalize_chat_id!(chat_id, :chat_id),
      message_id: normalize_message_id!(message_id)
    }
    |> maybe_put_reaction_actor(attrs)
  end

  def build_delete_all_message_reactions(%{chat_id: chat_id} = attrs) do
    %{
      _method: :delete_all_message_reactions,
      chat_id: normalize_chat_id!(chat_id, :chat_id)
    }
    |> maybe_put_reaction_actor(attrs)
  end

  def build_ban_chat_member(%{chat_id: chat_id, user_id: user_id} = attrs) do
    %{
      _method: :ban_chat_member,
      chat_id: normalize_chat_id!(chat_id, :chat_id),
      user_id: normalize_positive_integer!(user_id, :user_id)
    }
    |> maybe_put(:until_date, non_negative_integer(option(attrs, :until_date), :until_date))
    |> maybe_put(:revoke_messages, option(attrs, :revoke_messages))
  end

  def build_unban_chat_member(%{chat_id: chat_id, user_id: user_id} = attrs) do
    %{
      _method: :unban_chat_member,
      chat_id: normalize_chat_id!(chat_id, :chat_id),
      user_id: normalize_positive_integer!(user_id, :user_id)
    }
    |> maybe_put(:only_if_banned, option(attrs, :only_if_banned))
  end

  def build_restrict_chat_member(
        %{chat_id: chat_id, user_id: user_id, permissions: permissions} = attrs
      ) do
    %{
      _method: :restrict_chat_member,
      chat_id: normalize_chat_id!(chat_id, :chat_id),
      user_id: normalize_positive_integer!(user_id, :user_id),
      permissions: normalize_non_empty_map!(permissions, :permissions)
    }
    |> maybe_put(
      :use_independent_chat_permissions,
      option(attrs, :use_independent_chat_permissions)
    )
    |> maybe_put(:until_date, non_negative_integer(option(attrs, :until_date), :until_date))
  end

  def build_promote_chat_member(%{chat_id: chat_id, user_id: user_id} = attrs) do
    [
      :is_anonymous,
      :can_manage_chat,
      :can_delete_messages,
      :can_manage_video_chats,
      :can_restrict_members,
      :can_promote_members,
      :can_change_info,
      :can_invite_users,
      :can_post_stories,
      :can_edit_stories,
      :can_delete_stories,
      :can_post_messages,
      :can_edit_messages,
      :can_pin_messages,
      :can_manage_topics,
      :can_manage_direct_messages
    ]
    |> Enum.reduce(
      %{
        _method: :promote_chat_member,
        chat_id: normalize_chat_id!(chat_id, :chat_id),
        user_id: normalize_positive_integer!(user_id, :user_id)
      },
      fn key, payload -> maybe_put(payload, key, option(attrs, key)) end
    )
  end

  def build_set_chat_administrator_custom_title(%{
        chat_id: chat_id,
        user_id: user_id,
        custom_title: custom_title
      }) do
    %{
      _method: :set_chat_administrator_custom_title,
      chat_id: normalize_chat_id!(chat_id, :chat_id),
      user_id: normalize_positive_integer!(user_id, :user_id),
      custom_title: bounded_string!(custom_title, :custom_title, 1, 16)
    }
  end

  def build_set_chat_member_tag(%{chat_id: chat_id, user_id: user_id} = attrs) do
    %{
      _method: :set_chat_member_tag,
      chat_id: normalize_chat_id!(chat_id, :chat_id),
      user_id: normalize_positive_integer!(user_id, :user_id)
    }
    |> maybe_put(:tag, bounded_string_or_empty!(option(attrs, :tag), :tag, 0, 16))
  end

  def build_ban_chat_sender_chat(%{chat_id: chat_id, sender_chat_id: sender_chat_id}) do
    %{
      _method: :ban_chat_sender_chat,
      chat_id: normalize_chat_id!(chat_id, :chat_id),
      sender_chat_id: normalize_integer!(sender_chat_id, :sender_chat_id)
    }
  end

  def build_unban_chat_sender_chat(%{chat_id: chat_id, sender_chat_id: sender_chat_id}) do
    %{
      _method: :unban_chat_sender_chat,
      chat_id: normalize_chat_id!(chat_id, :chat_id),
      sender_chat_id: normalize_integer!(sender_chat_id, :sender_chat_id)
    }
  end

  def build_set_chat_permissions(%{chat_id: chat_id, permissions: permissions} = attrs) do
    %{
      _method: :set_chat_permissions,
      chat_id: normalize_chat_id!(chat_id, :chat_id),
      permissions: normalize_non_empty_map!(permissions, :permissions)
    }
    |> maybe_put(
      :use_independent_chat_permissions,
      option(attrs, :use_independent_chat_permissions)
    )
  end

  def build_export_chat_invite_link(%{chat_id: chat_id}) do
    %{_method: :export_chat_invite_link, chat_id: normalize_chat_id!(chat_id, :chat_id)}
  end

  def build_create_chat_invite_link(%{chat_id: chat_id} = attrs) do
    %{
      _method: :create_chat_invite_link,
      chat_id: normalize_chat_id!(chat_id, :chat_id)
    }
    |> maybe_put_invite_link_attrs(attrs)
  end

  def build_edit_chat_invite_link(%{chat_id: chat_id, invite_link: invite_link} = attrs) do
    %{
      _method: :edit_chat_invite_link,
      chat_id: normalize_chat_id!(chat_id, :chat_id),
      invite_link: non_empty_string!(invite_link, :invite_link)
    }
    |> maybe_put_invite_link_attrs(attrs)
  end

  def build_create_chat_subscription_invite_link(
        %{chat_id: chat_id, subscription_period: period, subscription_price: price} = attrs
      ) do
    %{
      _method: :create_chat_subscription_invite_link,
      chat_id: normalize_chat_id!(chat_id, :chat_id),
      subscription_period: normalize_subscription_period!(period),
      subscription_price: bounded_integer!(price, :subscription_price, 1, 10_000)
    }
    |> maybe_put(:name, bounded_string_or_empty!(option(attrs, :name), :name, 0, 32))
  end

  def build_edit_chat_subscription_invite_link(
        %{chat_id: chat_id, invite_link: invite_link} = attrs
      ) do
    %{
      _method: :edit_chat_subscription_invite_link,
      chat_id: normalize_chat_id!(chat_id, :chat_id),
      invite_link: non_empty_string!(invite_link, :invite_link)
    }
    |> maybe_put(:name, bounded_string_or_empty!(option(attrs, :name), :name, 0, 32))
  end

  def build_revoke_chat_invite_link(%{chat_id: chat_id, invite_link: invite_link}) do
    %{
      _method: :revoke_chat_invite_link,
      chat_id: normalize_chat_id!(chat_id, :chat_id),
      invite_link: non_empty_string!(invite_link, :invite_link)
    }
  end

  def build_approve_chat_join_request(%{chat_id: chat_id, user_id: user_id}) do
    %{
      _method: :approve_chat_join_request,
      chat_id: normalize_chat_id!(chat_id, :chat_id),
      user_id: normalize_positive_integer!(user_id, :user_id)
    }
  end

  def build_decline_chat_join_request(%{chat_id: chat_id, user_id: user_id}) do
    %{
      _method: :decline_chat_join_request,
      chat_id: normalize_chat_id!(chat_id, :chat_id),
      user_id: normalize_positive_integer!(user_id, :user_id)
    }
  end

  def build_answer_chat_join_request_query(%{
        chat_join_request_query_id: query_id,
        result: result
      }) do
    %{
      _method: :answer_chat_join_request_query,
      chat_join_request_query_id: non_empty_string!(query_id, :chat_join_request_query_id),
      result: normalize_join_request_query_result!(result)
    }
  end

  def build_send_chat_join_request_web_app(%{
        chat_join_request_query_id: query_id,
        web_app_url: web_app_url
      }) do
    %{
      _method: :send_chat_join_request_web_app,
      chat_join_request_query_id: non_empty_string!(query_id, :chat_join_request_query_id),
      web_app_url: safe_optional_url!(web_app_url, :web_app_url)
    }
  end

  def build_set_chat_photo(%{chat_id: chat_id, photo: photo}) do
    %{
      _method: :set_chat_photo,
      chat_id: normalize_chat_id!(chat_id, :chat_id),
      photo: non_empty_string!(photo, :photo)
    }
  end

  def build_delete_chat_photo(%{chat_id: chat_id}) do
    %{_method: :delete_chat_photo, chat_id: normalize_chat_id!(chat_id, :chat_id)}
  end

  def build_set_chat_title(%{chat_id: chat_id, title: title}) do
    %{
      _method: :set_chat_title,
      chat_id: normalize_chat_id!(chat_id, :chat_id),
      title: bounded_string!(title, :title, 1, 255)
    }
  end

  def build_set_chat_description(%{chat_id: chat_id} = attrs) do
    %{
      _method: :set_chat_description,
      chat_id: normalize_chat_id!(chat_id, :chat_id)
    }
    |> maybe_put(
      :description,
      bounded_string_or_empty!(option(attrs, :description), :description, 0, 255)
    )
  end

  def build_pin_chat_message(%{chat_id: chat_id, message_id: message_id} = attrs) do
    %{
      _method: :pin_chat_message,
      chat_id: normalize_chat_id!(chat_id, :chat_id),
      message_id: normalize_message_id!(message_id)
    }
    |> maybe_put(:disable_notification, option(attrs, :disable_notification))
    |> maybe_put(:business_connection_id, option(attrs, :business_connection_id))
  end

  def build_unpin_chat_message(%{chat_id: chat_id} = attrs) do
    %{_method: :unpin_chat_message, chat_id: normalize_chat_id!(chat_id, :chat_id)}
    |> maybe_put(:message_id, optional_message_id(option(attrs, :message_id)))
    |> maybe_put(:business_connection_id, option(attrs, :business_connection_id))
  end

  def build_unpin_all_chat_messages(%{chat_id: chat_id}) do
    %{_method: :unpin_all_chat_messages, chat_id: normalize_chat_id!(chat_id, :chat_id)}
  end

  def build_leave_chat(%{chat_id: chat_id}) do
    %{_method: :leave_chat, chat_id: normalize_chat_id!(chat_id, :chat_id)}
  end

  def build_get_chat(%{chat_id: chat_id}) do
    %{_method: :get_chat, chat_id: normalize_chat_id!(chat_id, :chat_id)}
  end

  def build_get_chat_administrators(%{chat_id: chat_id} = attrs) do
    %{_method: :get_chat_administrators, chat_id: normalize_chat_id!(chat_id, :chat_id)}
    |> maybe_put(:return_bots, option(attrs, :return_bots))
  end

  def build_get_chat_member_count(%{chat_id: chat_id}) do
    %{_method: :get_chat_member_count, chat_id: normalize_chat_id!(chat_id, :chat_id)}
  end

  def build_get_chat_member(%{chat_id: chat_id, user_id: user_id}) do
    %{
      _method: :get_chat_member,
      chat_id: normalize_chat_id!(chat_id, :chat_id),
      user_id: normalize_positive_integer!(user_id, :user_id)
    }
  end

  def build_set_chat_sticker_set(%{chat_id: chat_id, sticker_set_name: sticker_set_name}) do
    %{
      _method: :set_chat_sticker_set,
      chat_id: normalize_chat_id!(chat_id, :chat_id),
      sticker_set_name: non_empty_string!(sticker_set_name, :sticker_set_name)
    }
  end

  def build_delete_chat_sticker_set(%{chat_id: chat_id}) do
    %{_method: :delete_chat_sticker_set, chat_id: normalize_chat_id!(chat_id, :chat_id)}
  end

  def build_get_forum_topic_icon_stickers(_attrs \\ %{}),
    do: %{_method: :get_forum_topic_icon_stickers}

  def build_create_forum_topic(%{chat_id: chat_id, name: name} = attrs) do
    %{
      _method: :create_forum_topic,
      chat_id: normalize_chat_id!(chat_id, :chat_id),
      name: bounded_string!(name, :name, 1, 128)
    }
    |> maybe_put(:icon_color, normalize_topic_icon_color(option(attrs, :icon_color)))
    |> maybe_put(:icon_custom_emoji_id, option(attrs, :icon_custom_emoji_id))
  end

  def build_edit_forum_topic(%{chat_id: chat_id, message_thread_id: message_thread_id} = attrs) do
    %{
      _method: :edit_forum_topic,
      chat_id: normalize_chat_id!(chat_id, :chat_id),
      message_thread_id: normalize_message_id!(message_thread_id)
    }
    |> maybe_put(:name, bounded_string_or_empty!(option(attrs, :name), :name, 0, 128))
    |> maybe_put(:icon_custom_emoji_id, option(attrs, :icon_custom_emoji_id))
  end

  def build_close_forum_topic(%{chat_id: chat_id, message_thread_id: message_thread_id}) do
    forum_topic_payload(:close_forum_topic, chat_id, message_thread_id)
  end

  def build_reopen_forum_topic(%{chat_id: chat_id, message_thread_id: message_thread_id}) do
    forum_topic_payload(:reopen_forum_topic, chat_id, message_thread_id)
  end

  def build_delete_forum_topic(%{chat_id: chat_id, message_thread_id: message_thread_id}) do
    forum_topic_payload(:delete_forum_topic, chat_id, message_thread_id)
  end

  def build_unpin_all_forum_topic_messages(%{
        chat_id: chat_id,
        message_thread_id: message_thread_id
      }) do
    forum_topic_payload(:unpin_all_forum_topic_messages, chat_id, message_thread_id)
  end

  def build_edit_general_forum_topic(%{chat_id: chat_id, name: name}) do
    %{
      _method: :edit_general_forum_topic,
      chat_id: normalize_chat_id!(chat_id, :chat_id),
      name: bounded_string!(name, :name, 1, 128)
    }
  end

  def build_close_general_forum_topic(%{chat_id: chat_id}) do
    %{_method: :close_general_forum_topic, chat_id: normalize_chat_id!(chat_id, :chat_id)}
  end

  def build_reopen_general_forum_topic(%{chat_id: chat_id}) do
    %{_method: :reopen_general_forum_topic, chat_id: normalize_chat_id!(chat_id, :chat_id)}
  end

  def build_hide_general_forum_topic(%{chat_id: chat_id}) do
    %{_method: :hide_general_forum_topic, chat_id: normalize_chat_id!(chat_id, :chat_id)}
  end

  def build_unhide_general_forum_topic(%{chat_id: chat_id}) do
    %{_method: :unhide_general_forum_topic, chat_id: normalize_chat_id!(chat_id, :chat_id)}
  end

  def build_unpin_all_general_forum_topic_messages(%{chat_id: chat_id}) do
    %{
      _method: :unpin_all_general_forum_topic_messages,
      chat_id: normalize_chat_id!(chat_id, :chat_id)
    }
  end

  def chunk_text(text, limit \\ @telegram_text_limit) do
    text
    |> to_string()
    |> line_aware_chunks(limit)
  end

  def utf16_units(text) do
    text
    |> :unicode.characters_to_binary(:utf8, {:utf16, :little})
    |> byte_size()
    |> div(2)
  end

  defp line_aware_chunks(text, limit) do
    if utf16_units(text) <= limit do
      [text]
    else
      text
      |> line_tokens(limit)
      |> pack_tokens(limit)
    end
  end

  defp line_tokens(text, limit) do
    lines = String.split(text, "\n", trim: false)
    last_index = length(lines) - 1

    lines
    |> Enum.with_index()
    |> Enum.flat_map(fn {line, index} ->
      suffix = if index < last_index, do: "\n", else: ""
      parts = split_long_line(line, limit)
      attach_line_suffix(parts, suffix, limit)
    end)
  end

  defp attach_line_suffix(parts, "", _limit), do: parts

  defp attach_line_suffix(parts, suffix, limit) do
    {last, head} = List.pop_at(parts, -1)
    last = last || ""

    if utf16_units(last <> suffix) <= limit do
      head ++ [last <> suffix]
    else
      head ++ [last, suffix]
    end
  end

  defp split_long_line(line, limit) do
    if utf16_units(line) <= limit, do: [line], else: hard_split(String.graphemes(line), limit)
  end

  defp hard_split(graphemes, limit) do
    {chunks, cur, _len} =
      Enum.reduce(graphemes, {[], [], 0}, fn grapheme, {chunks, cur, len} ->
        gl = utf16_units(grapheme)

        if cur != [] and len + gl > limit do
          {[join_rev(cur) | chunks], [grapheme], gl}
        else
          {chunks, [grapheme | cur], len + gl}
        end
      end)

    [join_rev(cur) | chunks]
    |> Enum.reverse()
    |> Enum.reject(&(&1 == ""))
  end

  defp pack_tokens(tokens, limit) do
    {chunks, cur} =
      Enum.reduce(tokens, {[], ""}, fn token, {chunks, cur} ->
        candidate = cur <> token

        cond do
          token == "" ->
            {chunks, cur}

          cur == "" ->
            {chunks, token}

          utf16_units(candidate) <= limit ->
            {chunks, candidate}

          true ->
            {[cur | chunks], token}
        end
      end)

    [cur | chunks]
    |> Enum.reverse()
    |> Enum.reject(&(&1 == ""))
  end

  defp join_rev(cur), do: cur |> Enum.reverse() |> Enum.join()

  def reply_markup(nil), do: nil
  def reply_markup([]), do: nil

  def reply_markup(%{inline_keyboard: rows}) when is_list(rows) do
    case reply_markup(rows) do
      %{inline_keyboard: inline_keyboard} -> %{inline_keyboard: inline_keyboard}
      _ -> raise ArgumentError, "inline_keyboard must contain at least one valid row"
    end
  end

  def reply_markup(%{keyboard: rows} = markup) when is_list(rows) do
    %{keyboard: Enum.map(rows, &keyboard_row!/1)}
    |> maybe_put(:is_persistent, option(markup, :is_persistent))
    |> maybe_put(:resize_keyboard, option(markup, :resize_keyboard))
    |> maybe_put(:one_time_keyboard, option(markup, :one_time_keyboard))
    |> maybe_put(
      :input_field_placeholder,
      keyboard_placeholder!(option(markup, :input_field_placeholder))
    )
    |> maybe_put(:selective, option(markup, :selective))
  end

  def reply_markup(%{remove_keyboard: true} = markup) do
    %{remove_keyboard: true}
    |> maybe_put(:selective, option(markup, :selective))
  end

  def reply_markup(%{force_reply: true} = markup) do
    %{force_reply: true}
    |> maybe_put(
      :input_field_placeholder,
      keyboard_placeholder!(option(markup, :input_field_placeholder))
    )
    |> maybe_put(:selective, option(markup, :selective))
  end

  def reply_markup(buttons) when is_list(buttons) do
    rows =
      Enum.map(buttons, fn
        row when is_list(row) -> Enum.map(row, &button/1)
        single -> [button(single)]
      end)

    %{inline_keyboard: rows}
  end

  def reply_markup(other),
    do: raise(ArgumentError, "invalid Telegram reply_markup: #{inspect(other)}")

  defp button(%{text: text, url: url}) when is_binary(text) and is_binary(url) do
    if Format.safe_url?(url),
      do: %{text: text, url: url},
      else: raise(ArgumentError, "unsafe button URL")
  end

  defp button(%{text: text, callback_data: data}) when is_binary(text) and is_binary(data) do
    if byte_size(data) <= 64,
      do: %{text: text, callback_data: data},
      else: raise(ArgumentError, "callback_data must be <= 64 bytes")
  end

  defp button(%{text: text, web_app: %{url: url}}) when is_binary(text) and is_binary(url) do
    if Format.safe_url?(url),
      do: %{text: text, web_app: %{url: url}},
      else: raise(ArgumentError, "unsafe web_app URL")
  end

  defp button(%{text: text, switch_inline_query: query})
       when is_binary(text) and is_binary(query) do
    if byte_size(query) <= 256,
      do: %{text: text, switch_inline_query: query},
      else: raise(ArgumentError, "switch_inline_query must be <= 256 bytes")
  end

  defp button(%{text: text, switch_inline_query_current_chat: query})
       when is_binary(text) and is_binary(query) do
    if byte_size(query) <= 256,
      do: %{text: text, switch_inline_query_current_chat: query},
      else: raise(ArgumentError, "switch_inline_query_current_chat must be <= 256 bytes")
  end

  defp button(%{text: text, switch_inline_query_chosen_chat: chosen_chat})
       when is_binary(text) and is_map(chosen_chat) do
    query = option(chosen_chat, :query) || ""

    if is_binary(query) and byte_size(query) <= 256 do
      %{text: text, switch_inline_query_chosen_chat: normalize_chosen_chat(chosen_chat, query)}
    else
      raise ArgumentError, "switch_inline_query_chosen_chat query must be <= 256 bytes"
    end
  end

  defp button(%{text: text, copy_text: %{text: copy_text}})
       when is_binary(text) and is_binary(copy_text) do
    if byte_size(copy_text) <= 256,
      do: %{text: text, copy_text: %{text: copy_text}},
      else: raise(ArgumentError, "copy_text must be <= 256 bytes")
  end

  defp button(%{text: text, pay: true}) when is_binary(text), do: %{text: text, pay: true}

  defp button(other), do: raise(ArgumentError, "invalid Telegram button: #{inspect(other)}")

  defp keyboard_row!(row) when is_list(row), do: Enum.map(row, &keyboard_button!/1)

  defp keyboard_row!(other),
    do: raise(ArgumentError, "invalid Telegram keyboard row: #{inspect(other)}")

  defp keyboard_button!(text) when is_binary(text), do: non_empty_keyboard_text!(text)

  defp keyboard_button!(%{text: text} = button) when is_binary(text) do
    button
    |> take_any([
      :text,
      :icon_custom_emoji_id,
      :style,
      :request_contact,
      :request_location,
      :request_poll,
      :web_app
    ])
    |> validate_keyboard_button!()
  end

  defp keyboard_button!(other),
    do: raise(ArgumentError, "invalid Telegram keyboard button: #{inspect(other)}")

  defp validate_keyboard_button!(%{text: text} = button) do
    _ = non_empty_keyboard_text!(text)

    button
    |> validate_keyboard_style!()
    |> validate_keyboard_action_count!()
    |> validate_keyboard_web_app!()
    |> validate_keyboard_poll!()
  end

  defp validate_keyboard_style!(%{style: style})
       when style not in ["danger", "success", "primary"],
       do: raise(ArgumentError, "keyboard button style must be danger, success, or primary")

  defp validate_keyboard_style!(button), do: button

  defp validate_keyboard_action_count!(button) do
    count =
      [:request_contact, :request_location, :request_poll, :web_app]
      |> Enum.count(&Map.has_key?(button, &1))

    if count <= 1 do
      button
    else
      raise ArgumentError, "keyboard button can specify at most one action"
    end
  end

  defp validate_keyboard_web_app!(%{web_app: %{url: url}} = button) when is_binary(url) do
    if Format.safe_url?(url),
      do: button,
      else: raise(ArgumentError, "unsafe keyboard web_app URL")
  end

  defp validate_keyboard_web_app!(%{web_app: _}),
    do: raise(ArgumentError, "invalid keyboard web_app")

  defp validate_keyboard_web_app!(button), do: button

  defp validate_keyboard_poll!(%{request_poll: %{type: type}} = button)
       when type in ["quiz", "regular"],
       do: button

  defp validate_keyboard_poll!(%{request_poll: %{}} = button), do: button

  defp validate_keyboard_poll!(%{request_poll: _}),
    do: raise(ArgumentError, "invalid keyboard request_poll")

  defp validate_keyboard_poll!(button), do: button

  defp non_empty_keyboard_text!(text) do
    if String.trim(text) == "" do
      raise ArgumentError, "keyboard button text must be non-empty"
    else
      text
    end
  end

  defp keyboard_placeholder!(nil), do: nil

  defp keyboard_placeholder!(value) when is_binary(value) do
    if String.length(value) in 1..64,
      do: value,
      else: raise(ArgumentError, "input_field_placeholder must be 1 to 64 characters")
  end

  defp keyboard_placeholder!(_value), do: raise(ArgumentError, "invalid input_field_placeholder")

  defp normalize_chosen_chat(chosen_chat, query) do
    [
      :allow_user_chats,
      :allow_bot_chats,
      :allow_group_chats,
      :allow_channel_chats
    ]
    |> Enum.reduce(%{query: query}, fn key, acc ->
      if option(chosen_chat, key) in [true, "true", 1, "1"] do
        Map.put(acc, key, true)
      else
        acc
      end
    end)
  end

  defp media_method(type) when type in [:photo, "photo"], do: :send_photo
  defp media_method(type) when type in [:video, "video"], do: :send_video
  defp media_method(type) when type in [:animation, "animation"], do: :send_animation
  defp media_method(type) when type in [:audio, "audio"], do: :send_audio

  defp media_method(type) when type in [:voice, "voice", :voice_note, "voice_note"],
    do: :send_voice

  defp media_method(type) when type in [:document, "document"], do: :send_document

  defp media_method(type),
    do: raise(ArgumentError, "invalid Telegram media_type: #{inspect(type)}")

  defp media_field(type) when type in [:photo, "photo"], do: :photo
  defp media_field(type) when type in [:video, "video"], do: :video
  defp media_field(type) when type in [:animation, "animation"], do: :animation
  defp media_field(type) when type in [:audio, "audio"], do: :audio
  defp media_field(type) when type in [:voice, "voice", :voice_note, "voice_note"], do: :voice
  defp media_field(type) when type in [:document, "document"], do: :document

  defp maybe_put_media_caption(payload, attrs, type)
       when type in [:voice, "voice", :voice_note, "voice_note"],
       do: payload |> maybe_put_common(attrs)

  defp maybe_put_media_caption(payload, attrs, _type) do
    caption = option(attrs, :caption) || option(attrs, :text)

    if is_nil(caption) do
      payload
    else
      payload
      |> Map.put(:caption, Format.to_html(caption))
      |> Map.put(:parse_mode, "HTML")
    end
  end

  defp normalize_rich_message!(rich_message) when is_map(rich_message) do
    html = option(rich_message, :html)
    markdown = option(rich_message, :markdown)

    cond do
      is_binary(html) and html != "" and is_nil(markdown) ->
        %{html: html}
        |> maybe_put(:is_rtl, option(rich_message, :is_rtl))
        |> maybe_put(:skip_entity_detection, option(rich_message, :skip_entity_detection))

      is_binary(markdown) and markdown != "" and is_nil(html) ->
        %{markdown: markdown}
        |> maybe_put(:is_rtl, option(rich_message, :is_rtl))
        |> maybe_put(:skip_entity_detection, option(rich_message, :skip_entity_detection))

      true ->
        raise ArgumentError,
              "rich_message must contain exactly one non-empty html or markdown field"
    end
  end

  defp normalize_rich_message!(_), do: raise(ArgumentError, "invalid rich_message")

  defp normalize_inline_query_results!(results, max)
       when is_list(results) and length(results) >= 1 and length(results) <= max do
    Enum.map(results, &normalize_inline_query_result!/1)
  end

  defp normalize_inline_query_results!(_results, max),
    do: raise(ArgumentError, "inline query results must contain 1 to #{max} results")

  defp normalize_inline_query_result!(result) when is_map(result) do
    type = option(result, :type)
    id = option(result, :id)

    if is_binary(type) and String.trim(type) != "" and is_binary(id) and String.trim(id) != "" do
      result
      |> atomize_common_inline_result_keys()
    else
      raise ArgumentError, "inline query result requires non-empty type and id"
    end
  end

  defp normalize_inline_query_result!(_result),
    do: raise(ArgumentError, "inline query result must be an object")

  defp atomize_common_inline_result_keys(result) do
    Enum.reduce([:type, :id], result, fn key, acc ->
      case option(acc, key) do
        nil -> acc
        value -> acc |> Map.delete(to_string(key)) |> Map.put(key, value)
      end
    end)
  end

  defp normalize_inline_query_results_button(nil), do: nil

  defp normalize_inline_query_results_button(%{} = button) do
    text = non_empty_string!(option(button, :text), :button_text)
    web_app = option(button, :web_app)
    start_parameter = option(button, :start_parameter)

    cond do
      not is_nil(web_app) and not is_nil(start_parameter) ->
        raise ArgumentError, "inline query results button must use exactly one action"

      not is_nil(web_app) ->
        %{text: text, web_app: normalize_web_app_info!(web_app)}

      not is_nil(start_parameter) ->
        %{text: text, start_parameter: bounded_start_parameter!(start_parameter)}

      true ->
        raise ArgumentError, "inline query results button must use exactly one action"
    end
  end

  defp normalize_inline_query_results_button(_button),
    do: raise(ArgumentError, "inline query results button must be an object")

  defp normalize_web_app_info!(%{url: url}) when is_binary(url) do
    if Format.safe_url?(url), do: %{url: url}, else: raise(ArgumentError, "unsafe web_app URL")
  end

  defp normalize_web_app_info!(%{"url" => url}) when is_binary(url) do
    normalize_web_app_info!(%{url: url})
  end

  defp normalize_web_app_info!(url) when is_binary(url), do: normalize_web_app_info!(%{url: url})
  defp normalize_web_app_info!(_web_app), do: raise(ArgumentError, "invalid web_app")

  defp bounded_start_parameter!(value) when is_binary(value) do
    if byte_size(value) in 1..64 and String.match?(value, ~r/^[A-Za-z0-9_-]+$/) do
      value
    else
      raise ArgumentError, "start_parameter must be 1 to 64 URL-safe characters"
    end
  end

  defp bounded_start_parameter!(_value),
    do: raise(ArgumentError, "start_parameter must be 1 to 64 URL-safe characters")

  defp normalize_prepared_keyboard_button!(%{} = button) do
    text = non_empty_string!(option(button, :text), :button_text)

    actions =
      [:request_users, :request_chat, :request_managed_bot]
      |> Enum.flat_map(fn key ->
        case option(button, key) do
          nil -> []
          value -> [{key, value}]
        end
      end)

    case actions do
      [{key, value}] -> Map.put(%{text: text}, key, value)
      [] -> raise ArgumentError, "prepared keyboard button requires a request action"
      _ -> raise ArgumentError, "prepared keyboard button can specify only one request action"
    end
  end

  defp normalize_prepared_keyboard_button!(_button),
    do: raise(ArgumentError, "prepared keyboard button must be an object")

  defp normalize_added_user_ids(nil), do: nil

  defp normalize_added_user_ids(ids) when is_list(ids) and length(ids) <= 10,
    do: Enum.map(ids, &normalize_positive_integer!(&1, :added_user_id))

  defp normalize_added_user_ids(_ids),
    do: raise(ArgumentError, "added_user_ids must contain at most 10 user ids")

  defp normalize_bot_commands!(commands) when is_list(commands) and length(commands) in 1..100 do
    Enum.map(commands, &normalize_bot_command!/1)
  end

  defp normalize_bot_commands!(_commands),
    do: raise(ArgumentError, "commands must contain 1 to 100 bot commands")

  defp normalize_bot_command!(%{} = command) do
    command_text = non_empty_string!(option(command, :command), :command)
    description = bounded_string!(option(command, :description), :description, 1, 256)

    if String.match?(command_text, ~r/^[a-z0-9_]{1,32}$/) do
      %{command: command_text, description: description}
    else
      raise ArgumentError, "command must be 1 to 32 lowercase letters, digits, or underscores"
    end
  end

  defp normalize_bot_command!(_command), do: raise(ArgumentError, "bot command must be an object")

  defp language_code(nil), do: nil
  defp language_code(""), do: ""

  defp language_code(code) when is_binary(code) do
    if String.match?(code, ~r/^[a-z]{2}$/) do
      code
    else
      raise ArgumentError, "language_code must be empty or a two-letter lowercase code"
    end
  end

  defp language_code(_code),
    do: raise(ArgumentError, "language_code must be empty or a two-letter lowercase code")

  defp optional_map(nil, _field), do: nil
  defp optional_map(map, _field) when is_map(map), do: map
  defp optional_map(_map, field), do: raise(ArgumentError, "#{field} must be an object")

  defp optional_positive_integer(nil, _field), do: nil
  defp optional_positive_integer(value, field), do: normalize_positive_integer!(value, field)

  defp normalize_story_content!(%{} = content) do
    case option(content, :type) do
      "photo" ->
        %{type: "photo", photo: non_empty_string!(option(content, :photo), :photo)}

      "video" ->
        %{
          type: "video",
          video: non_empty_string!(option(content, :video), :video)
        }
        |> maybe_put(:duration, bounded_number!(option(content, :duration), :duration, 0, 60))
        |> maybe_put(
          :cover_frame_timestamp,
          bounded_number!(option(content, :cover_frame_timestamp), :cover_frame_timestamp, 0, 60)
        )
        |> maybe_put(:is_animation, option(content, :is_animation))

      other ->
        raise ArgumentError, "story content type must be photo or video: #{inspect(other)}"
    end
  end

  defp normalize_story_content!(_content),
    do: raise(ArgumentError, "story content must be an object")

  defp normalize_story_active_period!(period) do
    period = normalize_integer!(period, :active_period)

    if period in [6 * 3600, 12 * 3600, 86_400, 2 * 86_400] do
      period
    else
      raise ArgumentError, "active_period must be 21600, 43200, 86400, or 172800"
    end
  end

  defp normalize_story_areas(nil), do: nil
  defp normalize_story_areas(areas) when is_list(areas), do: areas
  defp normalize_story_areas(_areas), do: raise(ArgumentError, "story areas must be a list")

  defp maybe_put_story_caption(payload, attrs) do
    case option(attrs, :caption) || option(attrs, :text) do
      nil ->
        payload

      caption ->
        payload
        |> Map.put(:caption, Format.to_html(bounded_string_or_empty!(caption, :caption, 0, 2048)))
        |> Map.put(:parse_mode, "HTML")
    end
    |> maybe_put(:caption_entities, option(attrs, :caption_entities))
  end

  defp normalize_poll_options!(options) when is_list(options) and length(options) in 1..12 do
    Enum.map(options, fn
      option when is_binary(option) ->
        %{text: non_empty_string!(option, :poll_option_text)}

      option when is_map(option) ->
        text = option(option, :text)

        if is_binary(text) and String.trim(text) != "" do
          option
          |> take_any([:text, :media])
        else
          raise ArgumentError, "poll option text must be non-empty"
        end

      other ->
        raise ArgumentError, "invalid poll option: #{inspect(other)}"
    end)
  end

  defp normalize_poll_options!(_),
    do: raise(ArgumentError, "poll options must contain 1 to 12 options")

  defp normalize_input_checklist!(attrs) do
    checklist =
      case option(attrs, :checklist) do
        checklist when is_map(checklist) -> checklist
        nil -> attrs
        other -> raise ArgumentError, "checklist must be an object: #{inspect(other)}"
      end

    title =
      checklist
      |> option(:title)
      |> bounded_string!(:checklist_title, 1, 255)

    tasks =
      checklist
      |> option(:tasks)
      |> normalize_input_checklist_tasks!()

    %{
      title: title,
      tasks: tasks
    }
    |> maybe_put_checklist_parse_mode(checklist, :parse_mode, :title_entities)
    |> maybe_put(:others_can_add_tasks, option(checklist, :others_can_add_tasks))
    |> maybe_put(
      :others_can_mark_tasks_as_done,
      option(checklist, :others_can_mark_tasks_as_done)
    )
  end

  defp normalize_input_checklist_tasks!(tasks) when is_list(tasks) and length(tasks) in 1..30 do
    {normalized, _seen} =
      tasks
      |> Enum.with_index(1)
      |> Enum.map_reduce(MapSet.new(), fn {task, index}, seen ->
        input = normalize_input_checklist_task!(task, index)

        if MapSet.member?(seen, input.id) do
          raise ArgumentError, "checklist task ids must be unique"
        end

        {input, MapSet.put(seen, input.id)}
      end)

    normalized
  end

  defp normalize_input_checklist_tasks!(_tasks),
    do: raise(ArgumentError, "checklist tasks must contain 1 to 30 tasks")

  defp normalize_input_checklist_task!(text, index) when is_binary(text) do
    %{id: index, text: bounded_string!(text, :checklist_task_text, 1, 100)}
  end

  defp normalize_input_checklist_task!(task, index) when is_map(task) do
    id =
      case option(task, :id) do
        nil -> index
        value -> normalize_positive_integer!(value, :checklist_task_id)
      end

    %{
      id: id,
      text: bounded_string!(option(task, :text), :checklist_task_text, 1, 100)
    }
    |> maybe_put_checklist_parse_mode(task, :parse_mode, :text_entities)
  end

  defp normalize_input_checklist_task!(task, _index),
    do: raise(ArgumentError, "invalid checklist task: #{inspect(task)}")

  defp normalize_labeled_prices!(prices, currency) when is_list(prices) and prices != [] do
    if currency == "XTR" and length(prices) != 1 do
      raise ArgumentError, "Telegram Stars invoices require exactly one price"
    end

    Enum.map(prices, fn
      price when is_map(price) ->
        %{
          label: non_empty_string!(option(price, :label), :price_label),
          amount: normalize_integer!(option(price, :amount), :price_amount)
        }

      other ->
        raise ArgumentError, "invalid invoice price: #{inspect(other)}"
    end)
  end

  defp normalize_labeled_prices!(_prices, _currency),
    do: raise(ArgumentError, "prices must contain at least one labeled price")

  defp normalize_shipping_options!(options) when is_list(options) and options != [] do
    Enum.map(options, fn
      option when is_map(option) ->
        %{
          id: non_empty_string!(option(option, :id), :shipping_option_id),
          title: non_empty_string!(option(option, :title), :shipping_option_title),
          prices: normalize_labeled_prices!(option(option, :prices), "USD")
        }

      other ->
        raise ArgumentError, "invalid shipping option: #{inspect(other)}"
    end)
  end

  defp normalize_shipping_options!(_options),
    do: raise(ArgumentError, "shipping_options must contain at least one option")

  defp maybe_put_shipping_answer(payload, true, attrs) do
    Map.put(
      payload,
      :shipping_options,
      normalize_shipping_options!(option(attrs, :shipping_options))
    )
  end

  defp maybe_put_shipping_answer(payload, false, attrs),
    do: maybe_put_error_message(payload, false, attrs)

  defp maybe_put_error_message(payload, true, _attrs), do: payload

  defp maybe_put_error_message(payload, false, attrs) do
    Map.put(
      payload,
      :error_message,
      bounded_string!(option(attrs, :error_message), :error_message, 1, 200)
    )
  end

  defp maybe_put_gift_recipient(payload, attrs) do
    user_id = option(attrs, :user_id)
    chat_id = option(attrs, :chat_id)

    cond do
      not is_nil(user_id) and is_nil(chat_id) ->
        Map.put(payload, :user_id, normalize_positive_integer!(user_id, :user_id))

      is_nil(user_id) and not is_nil(chat_id) ->
        Map.put(payload, :chat_id, normalize_chat_id!(chat_id, :chat_id))

      true ->
        raise ArgumentError, "send_gift requires exactly one of user_id or chat_id"
    end
  end

  defp maybe_put_gift_text(payload, attrs) do
    payload
    |> maybe_put(:text, bounded_string_or_empty!(option(attrs, :text), :text, 0, 128))
    |> maybe_put(:text_parse_mode, option(attrs, :text_parse_mode) || option(attrs, :parse_mode))
    |> maybe_put(:text_entities, option(attrs, :text_entities))
  end

  defp maybe_put_gift_filters(payload, attrs, extra_filter_keys) do
    filter_keys =
      extra_filter_keys ++
        [
          :exclude_unlimited,
          :exclude_limited_upgradable,
          :exclude_limited_non_upgradable,
          :exclude_from_blockchain,
          :sort_by_price
        ]

    payload =
      Enum.reduce(filter_keys, payload, fn key, acc ->
        maybe_put(acc, key, option(attrs, key))
      end)

    payload
    |> maybe_put(:offset, option(attrs, :offset))
    |> maybe_put(:limit, bounded_optional_integer!(option(attrs, :limit), :limit, 1, 100))
  end

  defp normalize_accepted_gift_types!(types) when is_map(types) do
    accepted =
      [:unlimited_gifts, :limited_gifts, :unique_gifts, :premium_subscription]
      |> Enum.reduce(%{}, fn key, acc ->
        case option(types, key) do
          nil -> acc
          value -> Map.put(acc, key, truthy_boolean!(value, key))
        end
      end)

    if map_size(accepted) == 0 do
      raise ArgumentError, "accepted_gift_types must include at least one gift type"
    else
      accepted
    end
  end

  defp normalize_accepted_gift_types!(_types),
    do: raise(ArgumentError, "accepted_gift_types must be an object")

  defp normalize_passport_errors!(errors) when is_list(errors) and errors != [] do
    Enum.map(errors, &normalize_passport_error!/1)
  end

  defp normalize_passport_errors!(_errors),
    do: raise(ArgumentError, "passport errors must contain at least one error")

  defp normalize_passport_error!(%{} = error) do
    source = non_empty_string!(option(error, :source), :passport_error_source)
    type = non_empty_string!(option(error, :type), :passport_error_type)
    message = non_empty_string!(option(error, :message), :passport_error_message)

    error
    |> atomize_common_passport_error_keys()
    |> Map.put(:source, source)
    |> Map.put(:type, type)
    |> Map.put(:message, message)
  end

  defp normalize_passport_error!(_error),
    do: raise(ArgumentError, "passport error must be an object")

  defp atomize_common_passport_error_keys(error) do
    Enum.reduce([:source, :type, :message], error, fn key, acc ->
      case option(acc, key) do
        nil -> acc
        value -> acc |> Map.delete(to_string(key)) |> Map.put(key, value)
      end
    end)
  end

  defp maybe_put_game_message_target(payload, attrs) do
    inline_message_id = option(attrs, :inline_message_id)
    chat_id = option(attrs, :chat_id)
    message_id = option(attrs, :message_id)

    cond do
      not is_nil(inline_message_id) and is_nil(chat_id) and is_nil(message_id) ->
        Map.put(
          payload,
          :inline_message_id,
          non_empty_string!(inline_message_id, :inline_message_id)
        )

      is_nil(inline_message_id) and not is_nil(chat_id) and not is_nil(message_id) ->
        payload
        |> Map.put(:chat_id, normalize_chat_id!(chat_id, :chat_id))
        |> Map.put(:message_id, normalize_message_id!(message_id))

      true ->
        raise ArgumentError,
              "game score target requires inline_message_id or chat_id with message_id"
    end
  end

  defp suggested_tip_amounts(attrs) do
    case option(attrs, :suggested_tip_amounts) do
      nil ->
        nil

      amounts when is_list(amounts) and length(amounts) <= 4 ->
        normalized = Enum.map(amounts, &normalize_positive_integer!(&1, :suggested_tip_amount))

        if normalized == Enum.sort(normalized) and Enum.uniq(normalized) == normalized do
          normalized
        else
          raise ArgumentError, "suggested_tip_amounts must be strictly increasing"
        end

      _ ->
        raise ArgumentError, "suggested_tip_amounts must contain at most 4 amounts"
    end
  end

  defp normalize_currency!(currency) when is_binary(currency) do
    currency = String.upcase(String.trim(currency))

    if String.match?(currency, ~r/^[A-Z]{3}$/) do
      currency
    else
      raise ArgumentError, "currency must be a 3-letter code"
    end
  end

  defp normalize_currency!(_currency),
    do: raise(ArgumentError, "currency must be a 3-letter code")

  defp provider_token(attrs, "XTR"), do: option(attrs, :provider_token) || ""

  defp provider_token(attrs, _currency),
    do: non_empty_string!(option(attrs, :provider_token), :provider_token)

  defp subscription_period(attrs, currency) do
    case option(attrs, :subscription_period) do
      nil ->
        nil

      period ->
        if currency != "XTR" do
          raise ArgumentError, "subscription_period requires XTR currency"
        end

        period = normalize_integer!(period, :subscription_period)

        if period == 2_592_000 do
          period
        else
          raise ArgumentError, "subscription_period must be 2592000"
        end
    end
  end

  defp paid_caption(attrs) do
    case option(attrs, :caption) || option(attrs, :text) do
      nil -> nil
      caption -> Format.to_html(bounded_string!(caption, :caption, 0, 1024))
    end
  end

  defp paid_caption_parse_mode(attrs) do
    if is_nil(option(attrs, :caption)) and is_nil(option(attrs, :text)), do: nil, else: "HTML"
  end

  defp maybe_put_checklist_parse_mode(payload, source, parse_mode_key, entities_key) do
    parse_mode = option(source, parse_mode_key)
    entities = option(source, entities_key)

    cond do
      not is_nil(parse_mode) and not is_nil(entities) ->
        raise ArgumentError, "#{parse_mode_key} and #{entities_key} cannot both be set"

      not is_nil(parse_mode) ->
        Map.put(payload, parse_mode_key, non_empty_string!(parse_mode, parse_mode_key))

      not is_nil(entities) ->
        Map.put(payload, entities_key, entities)

      true ->
        payload
    end
  end

  defp normalize_media_group!(media) when is_list(media) and length(media) in 2..10 do
    items =
      Enum.map(media, fn
        item when is_map(item) ->
          item
          |> take_any([
            :type,
            :media,
            :caption,
            :parse_mode,
            :caption_entities,
            :show_caption_above_media,
            :has_spoiler,
            :thumbnail,
            :duration,
            :width,
            :height,
            :supports_streaming,
            :performer,
            :title,
            :disable_content_type_detection
          ])
          |> normalize_media_group_type()
          |> require_media_group_item!()

        other ->
          raise ArgumentError, "invalid media group item: #{inspect(other)}"
      end)

    validate_media_group_mix!(items)
    items
  end

  defp normalize_media_group!(_),
    do: raise(ArgumentError, "media group must contain 2 to 10 items")

  defp normalize_paid_media!(media) when is_list(media) and length(media) in 1..10 do
    Enum.map(media, fn
      item when is_map(item) ->
        item
        |> take_any([:type, :media, :photo, :thumbnail, :cover, :start_timestamp])
        |> normalize_media_group_type()
        |> require_paid_media_item!()

      other ->
        raise ArgumentError, "invalid paid media item: #{inspect(other)}"
    end)
  end

  defp normalize_paid_media!(_),
    do: raise(ArgumentError, "paid media must contain 1 to 10 items")

  defp require_paid_media_item!(%{type: "photo", media: media} = item) when is_binary(media) do
    %{item | media: non_empty_string!(media, :media)}
  end

  defp require_paid_media_item!(%{type: "video", media: media} = item) when is_binary(media) do
    %{item | media: non_empty_string!(media, :media)}
  end

  defp require_paid_media_item!(%{type: "live_photo", media: media, photo: photo} = item)
       when is_binary(media) and is_binary(photo) do
    %{item | media: non_empty_string!(media, :media), photo: non_empty_string!(photo, :photo)}
  end

  defp require_paid_media_item!(_item),
    do:
      raise(
        ArgumentError,
        "paid media items require type photo/video/live_photo and non-empty media"
      )

  defp edit_media!(attrs) do
    media =
      case option(attrs, :media) do
        media when is_map(media) ->
          media

        media when is_binary(media) ->
          %{type: option(attrs, :media_type), media: media}

        _ ->
          raise ArgumentError, "edit media requires a media object or media string"
      end

    media
    |> take_any([
      :type,
      :media,
      :caption,
      :parse_mode,
      :caption_entities,
      :show_caption_above_media,
      :has_spoiler,
      :thumbnail,
      :duration,
      :width,
      :height,
      :supports_streaming,
      :performer,
      :title,
      :disable_content_type_detection
    ])
    |> normalize_media_group_type()
    |> require_edit_media_item!()
  end

  defp require_edit_media_item!(%{type: type, media: media} = item)
       when type in ["photo", "video", "animation", "audio", "document", "live_photo"] and
              is_binary(media) do
    item
    |> Map.put(:media, non_empty_string!(media, :media))
    |> maybe_format_media_caption()
  end

  defp require_edit_media_item!(_item),
    do:
      raise(
        ArgumentError,
        "edit media requires type photo/video/animation/audio/document/live_photo and non-empty media"
      )

  defp maybe_format_media_caption(%{caption: caption} = item) when not is_nil(caption) do
    item
    |> Map.put(:caption, Format.to_html(caption))
    |> Map.put_new(:parse_mode, "HTML")
  end

  defp maybe_format_media_caption(item), do: item

  defp require_media_group_item!(%{type: type, media: media} = item)
       when type in ["photo", "video", "audio", "document", "live_photo"] and is_binary(media) do
    %{item | media: non_empty_string!(media, :media)}
  end

  defp require_media_group_item!(_item),
    do:
      raise(
        ArgumentError,
        "media group items require type photo/video/audio/document/live_photo and non-empty media"
      )

  defp normalize_media_group_type(%{type: type} = item) when is_atom(type),
    do: %{item | type: Atom.to_string(type)}

  defp normalize_media_group_type(item), do: item

  defp validate_media_group_mix!(items) do
    types = items |> Enum.map(& &1.type) |> Enum.uniq()

    cond do
      "audio" in types and types != ["audio"] ->
        raise ArgumentError, "audio media groups can contain only audio items"

      "document" in types and types != ["document"] ->
        raise ArgumentError, "document media groups can contain only document items"

      true ->
        :ok
    end
  end

  defp correct_option_ids(attrs) do
    cond do
      ids = option(attrs, :correct_option_ids) ->
        ids

      is_integer(option(attrs, :correct_option_id)) ->
        [option(attrs, :correct_option_id)]

      true ->
        nil
    end
  end

  defp take_any(map, keys) do
    Enum.reduce(keys, %{}, fn key, acc ->
      value = Map.get(map, key) || Map.get(map, to_string(key))
      if is_nil(value), do: acc, else: Map.put(acc, key, value)
    end)
  end

  defp normalize_message_id!(id) when is_integer(id), do: id

  defp normalize_message_id!(id) when is_binary(id) do
    case Integer.parse(id) do
      {n, ""} -> n
      _ -> raise ArgumentError, "message_id must be an integer"
    end
  end

  defp normalize_message_id!(_), do: raise(ArgumentError, "message_id must be an integer")

  defp normalize_positive_integer!(id, _field) when is_integer(id) and id > 0, do: id

  defp normalize_positive_integer!(id, field) when is_binary(id) do
    case Integer.parse(id) do
      {n, ""} when n > 0 -> n
      _ -> raise ArgumentError, "#{field} must be a positive integer"
    end
  end

  defp normalize_positive_integer!(_id, field),
    do: raise(ArgumentError, "#{field} must be a positive integer")

  defp normalize_message_ids!(ids, opts \\ [])

  defp normalize_message_ids!(ids, opts) when is_list(ids) and length(ids) in 1..100 do
    normalized = Enum.map(ids, &normalize_message_id!/1)

    if Keyword.get(opts, :increasing?, false) and normalized != Enum.sort(normalized) do
      raise ArgumentError, "message_ids must be sorted in strictly increasing order"
    end

    if Keyword.get(opts, :increasing?, false) and Enum.uniq(normalized) != normalized do
      raise ArgumentError, "message_ids must be sorted in strictly increasing order"
    end

    normalized
  end

  defp normalize_message_ids!(_ids, _opts),
    do: raise(ArgumentError, "message_ids must contain 1 to 100 message ids")

  defp normalize_chat_id!(id, _field) when is_integer(id), do: id

  defp normalize_chat_id!(id, field) when is_binary(id) do
    if String.trim(id) == "" do
      raise ArgumentError, "#{field} must be non-empty"
    else
      id
    end
  end

  defp normalize_chat_id!(_id, field), do: raise(ArgumentError, "#{field} must be a chat id")

  defp normalize_non_empty_map!(value, _field) when is_map(value) and map_size(value) > 0,
    do: value

  defp normalize_non_empty_map!(_value, field),
    do: raise(ArgumentError, "#{field} must be an object")

  defp normalize_draft_id!(id) when is_integer(id) and id != 0, do: id

  defp normalize_draft_id!(id) when is_binary(id) do
    case Integer.parse(id) do
      {n, ""} when n != 0 -> n
      _ -> raise ArgumentError, "draft_id must be a non-zero integer"
    end
  end

  defp normalize_draft_id!(_), do: raise(ArgumentError, "draft_id must be a non-zero integer")

  defp normalize_coordinate!(value, _field) when is_integer(value) or is_float(value), do: value

  defp normalize_coordinate!(value, field) when is_binary(value) do
    case Float.parse(value) do
      {number, ""} -> number
      _ -> raise ArgumentError, "#{field} must be a number"
    end
  end

  defp normalize_coordinate!(_value, field), do: raise(ArgumentError, "#{field} must be a number")

  defp normalize_chat_action!(action) when is_atom(action),
    do: action |> Atom.to_string() |> normalize_chat_action!()

  defp normalize_chat_action!(action) when is_binary(action) do
    action = String.trim(action)

    if action in @chat_actions do
      action
    else
      raise ArgumentError, "invalid chat action: #{inspect(action)}"
    end
  end

  defp normalize_chat_action!(_action), do: raise(ArgumentError, "invalid chat action")

  defp normalize_reactions!(nil), do: nil
  defp normalize_reactions!(""), do: []
  defp normalize_reactions!([]), do: []

  defp normalize_reactions!(reaction) when is_binary(reaction),
    do: [%{type: "emoji", emoji: non_empty_string!(reaction, :reaction)}]

  defp normalize_reactions!(reaction) when is_map(reaction),
    do: [normalize_reaction!(reaction)]

  defp normalize_reactions!(reactions) when is_list(reactions) do
    if length(reactions) > 1 do
      raise ArgumentError, "bots can set at most one reaction by default"
    else
      Enum.map(reactions, &normalize_reaction!/1)
    end
  end

  defp normalize_reactions!(_reaction), do: raise(ArgumentError, "invalid reaction")

  defp normalize_reaction!(reaction) when is_binary(reaction),
    do: %{type: "emoji", emoji: non_empty_string!(reaction, :reaction)}

  defp normalize_reaction!(reaction) when is_map(reaction) do
    type = option(reaction, :type) || "emoji"

    case type do
      "emoji" ->
        %{type: "emoji", emoji: non_empty_string!(option(reaction, :emoji), :emoji)}

      "custom_emoji" ->
        %{
          type: "custom_emoji",
          custom_emoji_id: non_empty_string!(option(reaction, :custom_emoji_id), :custom_emoji_id)
        }

      "paid" ->
        raise ArgumentError, "bots cannot set paid reactions"

      other ->
        raise ArgumentError, "invalid reaction type: #{inspect(other)}"
    end
  end

  defp normalize_reaction!(_reaction), do: raise(ArgumentError, "invalid reaction")

  defp maybe_put_reaction_actor(payload, attrs) do
    user_id = option(attrs, :user_id)
    actor_chat_id = option(attrs, :actor_chat_id)

    case {user_id, actor_chat_id} do
      {nil, nil} ->
        payload

      {nil, actor_chat_id} ->
        Map.put(payload, :actor_chat_id, normalize_chat_id!(actor_chat_id, :actor_chat_id))

      {user_id, nil} ->
        Map.put(payload, :user_id, normalize_positive_integer!(user_id, :user_id))

      {_user_id, _actor_chat_id} ->
        raise ArgumentError, "reaction removal requires only one of user_id or actor_chat_id"
    end
  end

  defp maybe_put_invite_link_attrs(payload, attrs) do
    payload
    |> maybe_put(:name, bounded_string_or_empty!(option(attrs, :name), :name, 0, 32))
    |> maybe_put(:expire_date, non_negative_integer(option(attrs, :expire_date), :expire_date))
    |> maybe_put(
      :member_limit,
      bounded_optional_integer!(option(attrs, :member_limit), :member_limit, 1, 99_999)
    )
    |> maybe_put(:creates_join_request, option(attrs, :creates_join_request))
  end

  defp normalize_subscription_period!(period) do
    case normalize_integer!(period, :subscription_period) do
      2_592_000 -> 2_592_000
      _ -> raise ArgumentError, "subscription_period must be 2592000"
    end
  end

  defp normalize_join_request_query_result!(result) when is_atom(result),
    do: result |> Atom.to_string() |> normalize_join_request_query_result!()

  defp normalize_join_request_query_result!(result)
       when result in ["approve", "decline", "queue"],
       do: result

  defp normalize_join_request_query_result!(_result),
    do: raise(ArgumentError, "join request query result must be approve, decline, or queue")

  defp optional_message_id(nil), do: nil
  defp optional_message_id(message_id), do: normalize_message_id!(message_id)

  @forum_topic_icon_colors [7_322_096, 16_766_590, 13_338_331, 9_367_192, 16_749_490, 16_478_047]

  defp normalize_topic_icon_color(nil), do: nil

  defp normalize_topic_icon_color(color) do
    color = normalize_integer!(color, :icon_color)

    if color in @forum_topic_icon_colors do
      color
    else
      raise ArgumentError, "icon_color must be one of Telegram's supported forum topic colors"
    end
  end

  defp forum_topic_payload(method, chat_id, message_thread_id) do
    %{
      _method: method,
      chat_id: normalize_chat_id!(chat_id, :chat_id),
      message_thread_id: normalize_message_id!(message_thread_id)
    }
  end

  defp normalize_string_list(nil, _field, 0, _max), do: nil

  defp normalize_string_list(value, field, min, max),
    do: normalize_string_list!(value, field, min, max)

  defp normalize_string_list!(values, field, min, max)
       when is_list(values) and length(values) >= min and length(values) <= max do
    Enum.map(values, &non_empty_string!(&1, field))
  end

  defp normalize_string_list!(_values, field, min, max),
    do: raise(ArgumentError, "#{field} must contain #{min} to #{max} non-empty strings")

  defp normalize_input_stickers!(stickers)
       when is_list(stickers) and length(stickers) in 1..50 do
    Enum.map(stickers, &normalize_non_empty_map!(&1, :sticker))
  end

  defp normalize_input_stickers!(_stickers),
    do: raise(ArgumentError, "stickers must contain 1 to 50 InputSticker objects")

  defp normalize_sticker_format!(format) when is_atom(format),
    do: format |> Atom.to_string() |> normalize_sticker_format!()

  defp normalize_sticker_format!(format) when format in ["static", "animated", "video"],
    do: format

  defp normalize_sticker_format!(_format),
    do: raise(ArgumentError, "sticker_format must be static, animated, or video")

  defp normalize_sticker_type(nil), do: nil

  defp normalize_sticker_type(type) when is_atom(type),
    do: type |> Atom.to_string() |> normalize_sticker_type()

  defp normalize_sticker_type(type) when type in ["regular", "mask", "custom_emoji"], do: type

  defp normalize_sticker_type(_type),
    do: raise(ArgumentError, "sticker_type must be regular, mask, or custom_emoji")

  defp non_empty_string!(value, field) when is_binary(value) do
    if String.trim(value) == "" do
      raise ArgumentError, "#{field} must be non-empty"
    else
      value
    end
  end

  defp non_empty_string!(_value, field), do: raise(ArgumentError, "#{field} must be non-empty")

  defp bounded_string!(value, field, min, max) when is_binary(value) do
    text = String.trim(value)
    length = String.length(text)

    if length in min..max do
      text
    else
      raise ArgumentError, "#{field} must be #{min} to #{max} characters"
    end
  end

  defp bounded_string!(_value, field, min, max),
    do: raise(ArgumentError, "#{field} must be #{min} to #{max} characters")

  defp bounded_string_or_empty!(nil, _field, _min, _max), do: nil

  defp bounded_string_or_empty!(value, field, min, max) when is_binary(value) do
    length = String.length(value)

    if length in min..max do
      value
    else
      raise ArgumentError, "#{field} must be #{min} to #{max} characters"
    end
  end

  defp bounded_string_or_empty!(_value, field, min, max),
    do: raise(ArgumentError, "#{field} must be #{min} to #{max} characters")

  defp bounded_bytes!(nil, field, min, max) when min > 0,
    do: raise(ArgumentError, "#{field} must be #{min} to #{max} bytes")

  defp bounded_bytes!(nil, _field, _min, _max), do: nil

  defp bounded_bytes!(value, field, min, max) when is_binary(value) do
    size = byte_size(value)

    if size in min..max do
      value
    else
      raise ArgumentError, "#{field} must be #{min} to #{max} bytes"
    end
  end

  defp bounded_bytes!(_value, field, min, max),
    do: raise(ArgumentError, "#{field} must be #{min} to #{max} bytes")

  defp normalize_integer!(value, _field) when is_integer(value), do: value

  defp normalize_integer!(value, field) when is_binary(value) do
    case Integer.parse(value) do
      {n, ""} -> n
      _ -> raise ArgumentError, "#{field} must be an integer"
    end
  end

  defp normalize_integer!(_value, field), do: raise(ArgumentError, "#{field} must be an integer")

  defp non_negative_integer(nil, _field), do: nil

  defp non_negative_integer(value, field) do
    value = normalize_integer!(value, field)

    if value >= 0 do
      value
    else
      raise ArgumentError, "#{field} must be non-negative"
    end
  end

  defp non_negative_integer!(value, field) do
    case non_negative_integer(value, field) do
      nil -> raise ArgumentError, "#{field} must be non-negative"
      integer -> integer
    end
  end

  defp truthy_boolean!(value, _field) when value in [true, false], do: value

  defp truthy_boolean!("true", _field), do: true
  defp truthy_boolean!("false", _field), do: false

  defp truthy_boolean!(_value, field),
    do: raise(ArgumentError, "#{field} must be a boolean")

  defp bounded_integer!(value, field, min, max) do
    value = normalize_integer!(value, field)

    if value in min..max do
      value
    else
      raise ArgumentError, "#{field} must be #{min} to #{max}"
    end
  end

  defp bounded_optional_integer!(nil, _field, _min, _max), do: nil

  defp bounded_optional_integer!(value, field, min, max),
    do: bounded_integer!(value, field, min, max)

  defp bounded_number!(nil, _field, _min, _max), do: nil

  defp bounded_number!(value, field, min, max) when is_integer(value) or is_float(value) do
    if value >= min and value <= max do
      value
    else
      raise ArgumentError, "#{field} must be #{min} to #{max}"
    end
  end

  defp bounded_number!(value, field, min, max) when is_binary(value) do
    case Float.parse(value) do
      {number, ""} -> bounded_number!(number, field, min, max)
      _ -> raise ArgumentError, "#{field} must be #{min} to #{max}"
    end
  end

  defp bounded_number!(_value, field, min, max),
    do: raise(ArgumentError, "#{field} must be #{min} to #{max}")

  defp safe_optional_url!(nil, _field), do: nil

  defp safe_optional_url!(url, field) when is_binary(url) do
    if Format.safe_url?(url),
      do: url,
      else: raise(ArgumentError, "#{field} must be http or https")
  end

  defp safe_optional_url!(_url, field), do: raise(ArgumentError, "#{field} must be http or https")

  defp maybe_put_common(payload, attrs) do
    payload
    |> maybe_put(:disable_notification, option(attrs, :disable_notification))
    |> maybe_put(:protect_content, option(attrs, :protect_content))
    |> maybe_put(:message_effect_id, option(attrs, :message_effect_id))
    |> maybe_put(:allow_paid_broadcast, option(attrs, :allow_paid_broadcast))
    |> maybe_put(:has_spoiler, option(attrs, :has_spoiler) || option(attrs, :spoiler))
  end

  defp maybe_put_thread(map, cid) do
    case ConversationId.thread_integer(cid) do
      nil -> map
      thread -> Map.put(map, :message_thread_id, thread)
    end
  end

  defp reply_parameters(%{reply_to_message_id: id}) when is_integer(id),
    do: %{message_id: id, allow_sending_without_reply: true}

  defp reply_parameters(%{reply_to_message_id: id}) when is_binary(id) do
    case Integer.parse(id) do
      {n, ""} -> %{message_id: n, allow_sending_without_reply: true}
      _ -> nil
    end
  end

  defp reply_parameters(_), do: nil

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp maybe_put_text_parse_mode(payload, text) do
    if String.trim(to_string(text)) == "" do
      payload
    else
      Map.put(payload, :parse_mode, "HTML")
    end
  end

  defp reply_markup_from_attrs(attrs) do
    reply_markup(option(attrs, :reply_markup) || option(attrs, :buttons))
  end

  defp inline_reply_markup_from_attrs(attrs) do
    case option(attrs, :reply_markup) || option(attrs, :buttons) do
      nil ->
        nil

      [] ->
        nil

      %{inline_keyboard: _} = markup ->
        reply_markup(markup)

      buttons when is_list(buttons) ->
        reply_markup(buttons)

      other ->
        raise ArgumentError, "edit reply_markup must be an inline keyboard: #{inspect(other)}"
    end
  end

  defp invoice_reply_markup_from_attrs(attrs) do
    markup = inline_reply_markup_from_attrs(attrs)

    case markup do
      nil ->
        nil

      %{inline_keyboard: [[%{pay: true} | _] | _]} ->
        markup

      _ ->
        raise ArgumentError, "invoice reply_markup first button must be a pay button"
    end
  end

  defp edit_caption(attrs) do
    case option(attrs, :caption) || option(attrs, :text) do
      nil -> nil
      caption -> Format.to_html(caption)
    end
  end

  defp edit_caption_parse_mode(attrs) do
    if is_nil(option(attrs, :caption)) and is_nil(option(attrs, :text)), do: nil, else: "HTML"
  end

  defp option(map, key) when is_map(map) do
    cond do
      Map.has_key?(map, key) -> Map.get(map, key)
      Map.has_key?(map, to_string(key)) -> Map.get(map, to_string(key))
      true -> nil
    end
  end

  defp validate_conversation_id!(cid) do
    unless ConversationId.valid?(cid) do
      raise ArgumentError, "invalid Telegram conversation id"
    end
  end
end

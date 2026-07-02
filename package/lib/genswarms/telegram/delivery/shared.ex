defmodule Genswarms.Telegram.Delivery.Shared do
  @moduledoc false

  alias Genswarms.Telegram.{ConversationId, Format}

  @telegram_text_limit 4096
  @chat_actions ~w(typing upload_photo record_video upload_video record_voice upload_voice upload_document choose_sticker find_location record_video_note upload_video_note)

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

  def line_aware_chunks(text, limit) do
    if utf16_units(text) <= limit do
      [text]
    else
      text
      |> line_tokens(limit)
      |> pack_tokens(limit)
    end
  end

  def line_tokens(text, limit) do
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

  def attach_line_suffix(parts, "", _limit), do: parts

  def attach_line_suffix(parts, suffix, limit) do
    {last, head} = List.pop_at(parts, -1)
    last = last || ""

    if utf16_units(last <> suffix) <= limit do
      head ++ [last <> suffix]
    else
      head ++ [last, suffix]
    end
  end

  def split_long_line(line, limit) do
    if utf16_units(line) <= limit, do: [line], else: hard_split(String.graphemes(line), limit)
  end

  def hard_split(graphemes, limit) do
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

  def pack_tokens(tokens, limit) do
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

  def join_rev(cur), do: cur |> Enum.reverse() |> Enum.join()

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

  def button(%{text: text, url: url}) when is_binary(text) and is_binary(url) do
    if Format.safe_url?(url),
      do: %{text: text, url: url},
      else: raise(ArgumentError, "unsafe button URL")
  end

  def button(%{text: text, callback_data: data}) when is_binary(text) and is_binary(data) do
    if byte_size(data) <= 64,
      do: %{text: text, callback_data: data},
      else: raise(ArgumentError, "callback_data must be <= 64 bytes")
  end

  def button(%{text: text, web_app: %{url: url}}) when is_binary(text) and is_binary(url) do
    if Format.safe_url?(url),
      do: %{text: text, web_app: %{url: url}},
      else: raise(ArgumentError, "unsafe web_app URL")
  end

  def button(%{text: text, switch_inline_query: query})
      when is_binary(text) and is_binary(query) do
    if byte_size(query) <= 256,
      do: %{text: text, switch_inline_query: query},
      else: raise(ArgumentError, "switch_inline_query must be <= 256 bytes")
  end

  def button(%{text: text, switch_inline_query_current_chat: query})
      when is_binary(text) and is_binary(query) do
    if byte_size(query) <= 256,
      do: %{text: text, switch_inline_query_current_chat: query},
      else: raise(ArgumentError, "switch_inline_query_current_chat must be <= 256 bytes")
  end

  def button(%{text: text, switch_inline_query_chosen_chat: chosen_chat})
      when is_binary(text) and is_map(chosen_chat) do
    query = option(chosen_chat, :query) || ""

    if is_binary(query) and byte_size(query) <= 256 do
      %{text: text, switch_inline_query_chosen_chat: normalize_chosen_chat(chosen_chat, query)}
    else
      raise ArgumentError, "switch_inline_query_chosen_chat query must be <= 256 bytes"
    end
  end

  def button(%{text: text, copy_text: %{text: copy_text}})
      when is_binary(text) and is_binary(copy_text) do
    if byte_size(copy_text) <= 256,
      do: %{text: text, copy_text: %{text: copy_text}},
      else: raise(ArgumentError, "copy_text must be <= 256 bytes")
  end

  def button(%{text: text, pay: true}) when is_binary(text), do: %{text: text, pay: true}

  def button(other), do: raise(ArgumentError, "invalid Telegram button: #{inspect(other)}")

  def keyboard_row!(row) when is_list(row), do: Enum.map(row, &keyboard_button!/1)

  def keyboard_row!(other),
    do: raise(ArgumentError, "invalid Telegram keyboard row: #{inspect(other)}")

  def keyboard_button!(text) when is_binary(text), do: non_empty_keyboard_text!(text)

  def keyboard_button!(%{text: text} = button) when is_binary(text) do
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

  def keyboard_button!(other),
    do: raise(ArgumentError, "invalid Telegram keyboard button: #{inspect(other)}")

  def validate_keyboard_button!(%{text: text} = button) do
    _ = non_empty_keyboard_text!(text)

    button
    |> validate_keyboard_style!()
    |> validate_keyboard_action_count!()
    |> validate_keyboard_web_app!()
    |> validate_keyboard_poll!()
  end

  def validate_keyboard_style!(%{style: style})
      when style not in ["danger", "success", "primary"],
      do: raise(ArgumentError, "keyboard button style must be danger, success, or primary")

  def validate_keyboard_style!(button), do: button

  def validate_keyboard_action_count!(button) do
    count =
      [:request_contact, :request_location, :request_poll, :web_app]
      |> Enum.count(&Map.has_key?(button, &1))

    if count <= 1 do
      button
    else
      raise ArgumentError, "keyboard button can specify at most one action"
    end
  end

  def validate_keyboard_web_app!(%{web_app: %{url: url}} = button) when is_binary(url) do
    if Format.safe_url?(url),
      do: button,
      else: raise(ArgumentError, "unsafe keyboard web_app URL")
  end

  def validate_keyboard_web_app!(%{web_app: _}),
    do: raise(ArgumentError, "invalid keyboard web_app")

  def validate_keyboard_web_app!(button), do: button

  def validate_keyboard_poll!(%{request_poll: %{type: type}} = button)
      when type in ["quiz", "regular"],
      do: button

  def validate_keyboard_poll!(%{request_poll: %{}} = button), do: button

  def validate_keyboard_poll!(%{request_poll: _}),
    do: raise(ArgumentError, "invalid keyboard request_poll")

  def validate_keyboard_poll!(button), do: button

  def non_empty_keyboard_text!(text) do
    if String.trim(text) == "" do
      raise ArgumentError, "keyboard button text must be non-empty"
    else
      text
    end
  end

  def keyboard_placeholder!(nil), do: nil

  def keyboard_placeholder!(value) when is_binary(value) do
    if String.length(value) in 1..64,
      do: value,
      else: raise(ArgumentError, "input_field_placeholder must be 1 to 64 characters")
  end

  def keyboard_placeholder!(_value), do: raise(ArgumentError, "invalid input_field_placeholder")

  def normalize_chosen_chat(chosen_chat, query) do
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

  def media_method(type) when type in [:photo, "photo"], do: :send_photo
  def media_method(type) when type in [:video, "video"], do: :send_video
  def media_method(type) when type in [:animation, "animation"], do: :send_animation
  def media_method(type) when type in [:audio, "audio"], do: :send_audio

  def media_method(type) when type in [:voice, "voice", :voice_note, "voice_note"],
    do: :send_voice

  def media_method(type) when type in [:document, "document"], do: :send_document

  def media_method(type),
    do: raise(ArgumentError, "invalid Telegram media_type: #{inspect(type)}")

  def media_field(type) when type in [:photo, "photo"], do: :photo
  def media_field(type) when type in [:video, "video"], do: :video
  def media_field(type) when type in [:animation, "animation"], do: :animation
  def media_field(type) when type in [:audio, "audio"], do: :audio
  def media_field(type) when type in [:voice, "voice", :voice_note, "voice_note"], do: :voice
  def media_field(type) when type in [:document, "document"], do: :document

  def maybe_put_media_caption(payload, attrs, type)
      when type in [:voice, "voice", :voice_note, "voice_note"],
      do: payload |> maybe_put_common(attrs)

  def maybe_put_media_caption(payload, attrs, _type) do
    caption = option(attrs, :caption) || option(attrs, :text)

    if is_nil(caption) do
      payload
    else
      payload
      |> Map.put(:caption, Format.to_html(caption))
      |> Map.put(:parse_mode, "HTML")
    end
  end

  def normalize_rich_message!(rich_message) when is_map(rich_message) do
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

  def normalize_rich_message!(_), do: raise(ArgumentError, "invalid rich_message")

  def normalize_inline_query_results!(results, max)
      when is_list(results) and length(results) >= 1 and length(results) <= max do
    Enum.map(results, &normalize_inline_query_result!/1)
  end

  def normalize_inline_query_results!(_results, max),
    do: raise(ArgumentError, "inline query results must contain 1 to #{max} results")

  def normalize_inline_query_result!(result) when is_map(result) do
    type = option(result, :type)
    id = option(result, :id)

    if is_binary(type) and String.trim(type) != "" and is_binary(id) and String.trim(id) != "" do
      result
      |> atomize_common_inline_result_keys()
    else
      raise ArgumentError, "inline query result requires non-empty type and id"
    end
  end

  def normalize_inline_query_result!(_result),
    do: raise(ArgumentError, "inline query result must be an object")

  def atomize_common_inline_result_keys(result) do
    Enum.reduce([:type, :id], result, fn key, acc ->
      case option(acc, key) do
        nil -> acc
        value -> acc |> Map.delete(to_string(key)) |> Map.put(key, value)
      end
    end)
  end

  def normalize_inline_query_results_button(nil), do: nil

  def normalize_inline_query_results_button(%{} = button) do
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

  def normalize_inline_query_results_button(_button),
    do: raise(ArgumentError, "inline query results button must be an object")

  def normalize_web_app_info!(%{url: url}) when is_binary(url) do
    if Format.safe_url?(url), do: %{url: url}, else: raise(ArgumentError, "unsafe web_app URL")
  end

  def normalize_web_app_info!(%{"url" => url}) when is_binary(url) do
    normalize_web_app_info!(%{url: url})
  end

  def normalize_web_app_info!(url) when is_binary(url), do: normalize_web_app_info!(%{url: url})
  def normalize_web_app_info!(_web_app), do: raise(ArgumentError, "invalid web_app")

  def bounded_start_parameter!(value) when is_binary(value) do
    if byte_size(value) in 1..64 and String.match?(value, ~r/^[A-Za-z0-9_-]+$/) do
      value
    else
      raise ArgumentError, "start_parameter must be 1 to 64 URL-safe characters"
    end
  end

  def bounded_start_parameter!(_value),
    do: raise(ArgumentError, "start_parameter must be 1 to 64 URL-safe characters")

  def normalize_prepared_keyboard_button!(%{} = button) do
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

  def normalize_prepared_keyboard_button!(_button),
    do: raise(ArgumentError, "prepared keyboard button must be an object")

  def normalize_added_user_ids(nil), do: nil

  def normalize_added_user_ids(ids) when is_list(ids) and length(ids) <= 10,
    do: Enum.map(ids, &normalize_positive_integer!(&1, :added_user_id))

  def normalize_added_user_ids(_ids),
    do: raise(ArgumentError, "added_user_ids must contain at most 10 user ids")

  def normalize_bot_commands!(commands) when is_list(commands) and length(commands) in 1..100 do
    Enum.map(commands, &normalize_bot_command!/1)
  end

  def normalize_bot_commands!(_commands),
    do: raise(ArgumentError, "commands must contain 1 to 100 bot commands")

  def normalize_bot_command!(%{} = command) do
    command_text = non_empty_string!(option(command, :command), :command)
    description = bounded_string!(option(command, :description), :description, 1, 256)

    if String.match?(command_text, ~r/^[a-z0-9_]{1,32}$/) do
      %{command: command_text, description: description}
    else
      raise ArgumentError, "command must be 1 to 32 lowercase letters, digits, or underscores"
    end
  end

  def normalize_bot_command!(_command), do: raise(ArgumentError, "bot command must be an object")

  def language_code(nil), do: nil
  def language_code(""), do: ""

  def language_code(code) when is_binary(code) do
    if String.match?(code, ~r/^[a-z]{2}$/) do
      code
    else
      raise ArgumentError, "language_code must be empty or a two-letter lowercase code"
    end
  end

  def language_code(_code),
    do: raise(ArgumentError, "language_code must be empty or a two-letter lowercase code")

  def optional_map(nil, _field), do: nil
  def optional_map(map, _field) when is_map(map), do: map
  def optional_map(_map, field), do: raise(ArgumentError, "#{field} must be an object")

  def optional_positive_integer(nil, _field), do: nil
  def optional_positive_integer(value, field), do: normalize_positive_integer!(value, field)

  def normalize_story_content!(%{} = content) do
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

  def normalize_story_content!(_content),
    do: raise(ArgumentError, "story content must be an object")

  def normalize_story_active_period!(period) do
    period = normalize_integer!(period, :active_period)

    if period in [6 * 3600, 12 * 3600, 86_400, 2 * 86_400] do
      period
    else
      raise ArgumentError, "active_period must be 21600, 43200, 86400, or 172800"
    end
  end

  def normalize_story_areas(nil), do: nil
  def normalize_story_areas(areas) when is_list(areas), do: areas
  def normalize_story_areas(_areas), do: raise(ArgumentError, "story areas must be a list")

  def maybe_put_story_caption(payload, attrs) do
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

  def normalize_poll_options!(options) when is_list(options) and length(options) in 1..12 do
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

  def normalize_poll_options!(_),
    do: raise(ArgumentError, "poll options must contain 1 to 12 options")

  def normalize_input_checklist!(attrs) do
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

  def normalize_input_checklist_tasks!(tasks) when is_list(tasks) and length(tasks) in 1..30 do
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

  def normalize_input_checklist_tasks!(_tasks),
    do: raise(ArgumentError, "checklist tasks must contain 1 to 30 tasks")

  def normalize_input_checklist_task!(text, index) when is_binary(text) do
    %{id: index, text: bounded_string!(text, :checklist_task_text, 1, 100)}
  end

  def normalize_input_checklist_task!(task, index) when is_map(task) do
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

  def normalize_input_checklist_task!(task, _index),
    do: raise(ArgumentError, "invalid checklist task: #{inspect(task)}")

  def normalize_labeled_prices!(prices, currency) when is_list(prices) and prices != [] do
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

  def normalize_labeled_prices!(_prices, _currency),
    do: raise(ArgumentError, "prices must contain at least one labeled price")

  def normalize_shipping_options!(options) when is_list(options) and options != [] do
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

  def normalize_shipping_options!(_options),
    do: raise(ArgumentError, "shipping_options must contain at least one option")

  def maybe_put_shipping_answer(payload, true, attrs) do
    Map.put(
      payload,
      :shipping_options,
      normalize_shipping_options!(option(attrs, :shipping_options))
    )
  end

  def maybe_put_shipping_answer(payload, false, attrs),
    do: maybe_put_error_message(payload, false, attrs)

  def maybe_put_error_message(payload, true, _attrs), do: payload

  def maybe_put_error_message(payload, false, attrs) do
    Map.put(
      payload,
      :error_message,
      bounded_string!(option(attrs, :error_message), :error_message, 1, 200)
    )
  end

  def maybe_put_gift_recipient(payload, attrs) do
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

  def maybe_put_gift_text(payload, attrs) do
    payload
    |> maybe_put(:text, bounded_string_or_empty!(option(attrs, :text), :text, 0, 128))
    |> maybe_put(:text_parse_mode, option(attrs, :text_parse_mode) || option(attrs, :parse_mode))
    |> maybe_put(:text_entities, option(attrs, :text_entities))
  end

  def maybe_put_gift_filters(payload, attrs, extra_filter_keys) do
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

  def normalize_accepted_gift_types!(types) when is_map(types) do
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

  def normalize_accepted_gift_types!(_types),
    do: raise(ArgumentError, "accepted_gift_types must be an object")

  def normalize_passport_errors!(errors) when is_list(errors) and errors != [] do
    Enum.map(errors, &normalize_passport_error!/1)
  end

  def normalize_passport_errors!(_errors),
    do: raise(ArgumentError, "passport errors must contain at least one error")

  def normalize_passport_error!(%{} = error) do
    source = non_empty_string!(option(error, :source), :passport_error_source)
    type = non_empty_string!(option(error, :type), :passport_error_type)
    message = non_empty_string!(option(error, :message), :passport_error_message)

    error
    |> atomize_common_passport_error_keys()
    |> Map.put(:source, source)
    |> Map.put(:type, type)
    |> Map.put(:message, message)
  end

  def normalize_passport_error!(_error),
    do: raise(ArgumentError, "passport error must be an object")

  def atomize_common_passport_error_keys(error) do
    Enum.reduce([:source, :type, :message], error, fn key, acc ->
      case option(acc, key) do
        nil -> acc
        value -> acc |> Map.delete(to_string(key)) |> Map.put(key, value)
      end
    end)
  end

  def maybe_put_game_message_target(payload, attrs) do
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

  def suggested_tip_amounts(attrs) do
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

  def normalize_currency!(currency) when is_binary(currency) do
    currency = String.upcase(String.trim(currency))

    if String.match?(currency, ~r/^[A-Z]{3}$/) do
      currency
    else
      raise ArgumentError, "currency must be a 3-letter code"
    end
  end

  def normalize_currency!(_currency),
    do: raise(ArgumentError, "currency must be a 3-letter code")

  def provider_token(attrs, "XTR"), do: option(attrs, :provider_token) || ""

  def provider_token(attrs, _currency),
    do: non_empty_string!(option(attrs, :provider_token), :provider_token)

  def subscription_period(attrs, currency) do
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

  def paid_caption(attrs) do
    case option(attrs, :caption) || option(attrs, :text) do
      nil -> nil
      caption -> Format.to_html(bounded_string!(caption, :caption, 0, 1024))
    end
  end

  def paid_caption_parse_mode(attrs) do
    if is_nil(option(attrs, :caption)) and is_nil(option(attrs, :text)), do: nil, else: "HTML"
  end

  def maybe_put_checklist_parse_mode(payload, source, parse_mode_key, entities_key) do
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

  def normalize_media_group!(media) when is_list(media) and length(media) in 2..10 do
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

  def normalize_media_group!(_),
    do: raise(ArgumentError, "media group must contain 2 to 10 items")

  def normalize_paid_media!(media) when is_list(media) and length(media) in 1..10 do
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

  def normalize_paid_media!(_),
    do: raise(ArgumentError, "paid media must contain 1 to 10 items")

  def require_paid_media_item!(%{type: "photo", media: media} = item) when is_binary(media) do
    %{item | media: non_empty_string!(media, :media)}
  end

  def require_paid_media_item!(%{type: "video", media: media} = item) when is_binary(media) do
    %{item | media: non_empty_string!(media, :media)}
  end

  def require_paid_media_item!(%{type: "live_photo", media: media, photo: photo} = item)
      when is_binary(media) and is_binary(photo) do
    %{item | media: non_empty_string!(media, :media), photo: non_empty_string!(photo, :photo)}
  end

  def require_paid_media_item!(_item),
    do:
      raise(
        ArgumentError,
        "paid media items require type photo/video/live_photo and non-empty media"
      )

  def edit_media!(attrs) do
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

  def require_edit_media_item!(%{type: type, media: media} = item)
      when type in ["photo", "video", "animation", "audio", "document", "live_photo"] and
             is_binary(media) do
    item
    |> Map.put(:media, non_empty_string!(media, :media))
    |> maybe_format_media_caption()
  end

  def require_edit_media_item!(_item),
    do:
      raise(
        ArgumentError,
        "edit media requires type photo/video/animation/audio/document/live_photo and non-empty media"
      )

  def maybe_format_media_caption(%{caption: caption} = item) when not is_nil(caption) do
    item
    |> Map.put(:caption, Format.to_html(caption))
    |> Map.put_new(:parse_mode, "HTML")
  end

  def maybe_format_media_caption(item), do: item

  def require_media_group_item!(%{type: type, media: media} = item)
      when type in ["photo", "video", "audio", "document", "live_photo"] and is_binary(media) do
    %{item | media: non_empty_string!(media, :media)}
  end

  def require_media_group_item!(_item),
    do:
      raise(
        ArgumentError,
        "media group items require type photo/video/audio/document/live_photo and non-empty media"
      )

  def normalize_media_group_type(%{type: type} = item) when is_atom(type),
    do: %{item | type: Atom.to_string(type)}

  def normalize_media_group_type(item), do: item

  def validate_media_group_mix!(items) do
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

  def correct_option_ids(attrs) do
    cond do
      ids = option(attrs, :correct_option_ids) ->
        ids

      is_integer(option(attrs, :correct_option_id)) ->
        [option(attrs, :correct_option_id)]

      true ->
        nil
    end
  end

  def take_any(map, keys) do
    Enum.reduce(keys, %{}, fn key, acc ->
      value = Map.get(map, key) || Map.get(map, to_string(key))
      if is_nil(value), do: acc, else: Map.put(acc, key, value)
    end)
  end

  def normalize_message_id!(id) when is_integer(id), do: id

  def normalize_message_id!(id) when is_binary(id) do
    case Integer.parse(id) do
      {n, ""} -> n
      _ -> raise ArgumentError, "message_id must be an integer"
    end
  end

  def normalize_message_id!(_), do: raise(ArgumentError, "message_id must be an integer")

  def normalize_positive_integer!(id, _field) when is_integer(id) and id > 0, do: id

  def normalize_positive_integer!(id, field) when is_binary(id) do
    case Integer.parse(id) do
      {n, ""} when n > 0 -> n
      _ -> raise ArgumentError, "#{field} must be a positive integer"
    end
  end

  def normalize_positive_integer!(_id, field),
    do: raise(ArgumentError, "#{field} must be a positive integer")

  def normalize_message_ids!(ids, opts \\ [])

  def normalize_message_ids!(ids, opts) when is_list(ids) and length(ids) in 1..100 do
    normalized = Enum.map(ids, &normalize_message_id!/1)

    if Keyword.get(opts, :increasing?, false) and normalized != Enum.sort(normalized) do
      raise ArgumentError, "message_ids must be sorted in strictly increasing order"
    end

    if Keyword.get(opts, :increasing?, false) and Enum.uniq(normalized) != normalized do
      raise ArgumentError, "message_ids must be sorted in strictly increasing order"
    end

    normalized
  end

  def normalize_message_ids!(_ids, _opts),
    do: raise(ArgumentError, "message_ids must contain 1 to 100 message ids")

  def normalize_chat_id!(id, _field) when is_integer(id), do: id

  def normalize_chat_id!(id, field) when is_binary(id) do
    if String.trim(id) == "" do
      raise ArgumentError, "#{field} must be non-empty"
    else
      id
    end
  end

  def normalize_chat_id!(_id, field), do: raise(ArgumentError, "#{field} must be a chat id")

  def normalize_non_empty_map!(value, _field) when is_map(value) and map_size(value) > 0,
    do: value

  def normalize_non_empty_map!(_value, field),
    do: raise(ArgumentError, "#{field} must be an object")

  def normalize_draft_id!(id) when is_integer(id) and id != 0, do: id

  def normalize_draft_id!(id) when is_binary(id) do
    case Integer.parse(id) do
      {n, ""} when n != 0 -> n
      _ -> raise ArgumentError, "draft_id must be a non-zero integer"
    end
  end

  def normalize_draft_id!(_), do: raise(ArgumentError, "draft_id must be a non-zero integer")

  def normalize_coordinate!(value, _field) when is_integer(value) or is_float(value), do: value

  def normalize_coordinate!(value, field) when is_binary(value) do
    case Float.parse(value) do
      {number, ""} -> number
      _ -> raise ArgumentError, "#{field} must be a number"
    end
  end

  def normalize_coordinate!(_value, field), do: raise(ArgumentError, "#{field} must be a number")

  def normalize_chat_action!(action) when is_atom(action),
    do: action |> Atom.to_string() |> normalize_chat_action!()

  def normalize_chat_action!(action) when is_binary(action) do
    action = String.trim(action)

    if action in @chat_actions do
      action
    else
      raise ArgumentError, "invalid chat action: #{inspect(action)}"
    end
  end

  def normalize_chat_action!(_action), do: raise(ArgumentError, "invalid chat action")

  def normalize_reactions!(nil), do: nil
  def normalize_reactions!(""), do: []
  def normalize_reactions!([]), do: []

  def normalize_reactions!(reaction) when is_binary(reaction),
    do: [%{type: "emoji", emoji: non_empty_string!(reaction, :reaction)}]

  def normalize_reactions!(reaction) when is_map(reaction),
    do: [normalize_reaction!(reaction)]

  def normalize_reactions!(reactions) when is_list(reactions) do
    if length(reactions) > 1 do
      raise ArgumentError, "bots can set at most one reaction by default"
    else
      Enum.map(reactions, &normalize_reaction!/1)
    end
  end

  def normalize_reactions!(_reaction), do: raise(ArgumentError, "invalid reaction")

  def normalize_reaction!(reaction) when is_binary(reaction),
    do: %{type: "emoji", emoji: non_empty_string!(reaction, :reaction)}

  def normalize_reaction!(reaction) when is_map(reaction) do
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

  def normalize_reaction!(_reaction), do: raise(ArgumentError, "invalid reaction")

  def maybe_put_reaction_actor(payload, attrs) do
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

  def maybe_put_invite_link_attrs(payload, attrs) do
    payload
    |> maybe_put(:name, bounded_string_or_empty!(option(attrs, :name), :name, 0, 32))
    |> maybe_put(:expire_date, non_negative_integer(option(attrs, :expire_date), :expire_date))
    |> maybe_put(
      :member_limit,
      bounded_optional_integer!(option(attrs, :member_limit), :member_limit, 1, 99_999)
    )
    |> maybe_put(:creates_join_request, option(attrs, :creates_join_request))
  end

  def normalize_subscription_period!(period) do
    case normalize_integer!(period, :subscription_period) do
      2_592_000 -> 2_592_000
      _ -> raise ArgumentError, "subscription_period must be 2592000"
    end
  end

  def normalize_join_request_query_result!(result) when is_atom(result),
    do: result |> Atom.to_string() |> normalize_join_request_query_result!()

  def normalize_join_request_query_result!(result)
      when result in ["approve", "decline", "queue"],
      do: result

  def normalize_join_request_query_result!(_result),
    do: raise(ArgumentError, "join request query result must be approve, decline, or queue")

  def optional_message_id(nil), do: nil
  def optional_message_id(message_id), do: normalize_message_id!(message_id)

  @forum_topic_icon_colors [7_322_096, 16_766_590, 13_338_331, 9_367_192, 16_749_490, 16_478_047]

  def normalize_topic_icon_color(nil), do: nil

  def normalize_topic_icon_color(color) do
    color = normalize_integer!(color, :icon_color)

    if color in @forum_topic_icon_colors do
      color
    else
      raise ArgumentError, "icon_color must be one of Telegram's supported forum topic colors"
    end
  end

  def forum_topic_payload(method, chat_id, message_thread_id) do
    %{
      _method: method,
      chat_id: normalize_chat_id!(chat_id, :chat_id),
      message_thread_id: normalize_message_id!(message_thread_id)
    }
  end

  def normalize_string_list(nil, _field, 0, _max), do: nil

  def normalize_string_list(value, field, min, max),
    do: normalize_string_list!(value, field, min, max)

  def normalize_string_list!(values, field, min, max)
      when is_list(values) and length(values) >= min and length(values) <= max do
    Enum.map(values, &non_empty_string!(&1, field))
  end

  def normalize_string_list!(_values, field, min, max),
    do: raise(ArgumentError, "#{field} must contain #{min} to #{max} non-empty strings")

  def normalize_input_stickers!(stickers)
      when is_list(stickers) and length(stickers) in 1..50 do
    Enum.map(stickers, &normalize_non_empty_map!(&1, :sticker))
  end

  def normalize_input_stickers!(_stickers),
    do: raise(ArgumentError, "stickers must contain 1 to 50 InputSticker objects")

  def normalize_sticker_format!(format) when is_atom(format),
    do: format |> Atom.to_string() |> normalize_sticker_format!()

  def normalize_sticker_format!(format) when format in ["static", "animated", "video"],
    do: format

  def normalize_sticker_format!(_format),
    do: raise(ArgumentError, "sticker_format must be static, animated, or video")

  def normalize_sticker_type(nil), do: nil

  def normalize_sticker_type(type) when is_atom(type),
    do: type |> Atom.to_string() |> normalize_sticker_type()

  def normalize_sticker_type(type) when type in ["regular", "mask", "custom_emoji"], do: type

  def normalize_sticker_type(_type),
    do: raise(ArgumentError, "sticker_type must be regular, mask, or custom_emoji")

  def non_empty_string!(value, field) when is_binary(value) do
    if String.trim(value) == "" do
      raise ArgumentError, "#{field} must be non-empty"
    else
      value
    end
  end

  def non_empty_string!(_value, field), do: raise(ArgumentError, "#{field} must be non-empty")

  def bounded_string!(value, field, min, max) when is_binary(value) do
    text = String.trim(value)
    length = String.length(text)

    if length in min..max do
      text
    else
      raise ArgumentError, "#{field} must be #{min} to #{max} characters"
    end
  end

  def bounded_string!(_value, field, min, max),
    do: raise(ArgumentError, "#{field} must be #{min} to #{max} characters")

  def bounded_string_or_empty!(nil, _field, _min, _max), do: nil

  def bounded_string_or_empty!(value, field, min, max) when is_binary(value) do
    length = String.length(value)

    if length in min..max do
      value
    else
      raise ArgumentError, "#{field} must be #{min} to #{max} characters"
    end
  end

  def bounded_string_or_empty!(_value, field, min, max),
    do: raise(ArgumentError, "#{field} must be #{min} to #{max} characters")

  def bounded_bytes!(nil, field, min, max) when min > 0,
    do: raise(ArgumentError, "#{field} must be #{min} to #{max} bytes")

  def bounded_bytes!(nil, _field, _min, _max), do: nil

  def bounded_bytes!(value, field, min, max) when is_binary(value) do
    size = byte_size(value)

    if size in min..max do
      value
    else
      raise ArgumentError, "#{field} must be #{min} to #{max} bytes"
    end
  end

  def bounded_bytes!(_value, field, min, max),
    do: raise(ArgumentError, "#{field} must be #{min} to #{max} bytes")

  def normalize_integer!(value, _field) when is_integer(value), do: value

  def normalize_integer!(value, field) when is_binary(value) do
    case Integer.parse(value) do
      {n, ""} -> n
      _ -> raise ArgumentError, "#{field} must be an integer"
    end
  end

  def normalize_integer!(_value, field), do: raise(ArgumentError, "#{field} must be an integer")

  def non_negative_integer(nil, _field), do: nil

  def non_negative_integer(value, field) do
    value = normalize_integer!(value, field)

    if value >= 0 do
      value
    else
      raise ArgumentError, "#{field} must be non-negative"
    end
  end

  def non_negative_integer!(value, field) do
    case non_negative_integer(value, field) do
      nil -> raise ArgumentError, "#{field} must be non-negative"
      integer -> integer
    end
  end

  def truthy_boolean!(value, _field) when value in [true, false], do: value

  def truthy_boolean!("true", _field), do: true
  def truthy_boolean!("false", _field), do: false

  def truthy_boolean!(_value, field),
    do: raise(ArgumentError, "#{field} must be a boolean")

  def bounded_integer!(value, field, min, max) do
    value = normalize_integer!(value, field)

    if value in min..max do
      value
    else
      raise ArgumentError, "#{field} must be #{min} to #{max}"
    end
  end

  def bounded_optional_integer!(nil, _field, _min, _max), do: nil

  def bounded_optional_integer!(value, field, min, max),
    do: bounded_integer!(value, field, min, max)

  def bounded_number!(nil, _field, _min, _max), do: nil

  def bounded_number!(value, field, min, max) when is_integer(value) or is_float(value) do
    if value >= min and value <= max do
      value
    else
      raise ArgumentError, "#{field} must be #{min} to #{max}"
    end
  end

  def bounded_number!(value, field, min, max) when is_binary(value) do
    case Float.parse(value) do
      {number, ""} -> bounded_number!(number, field, min, max)
      _ -> raise ArgumentError, "#{field} must be #{min} to #{max}"
    end
  end

  def bounded_number!(_value, field, min, max),
    do: raise(ArgumentError, "#{field} must be #{min} to #{max}")

  def safe_optional_url!(nil, _field), do: nil

  def safe_optional_url!(url, field) when is_binary(url) do
    if Format.safe_url?(url),
      do: url,
      else: raise(ArgumentError, "#{field} must be http or https")
  end

  def safe_optional_url!(_url, field), do: raise(ArgumentError, "#{field} must be http or https")

  def maybe_put_common(payload, attrs) do
    payload
    |> maybe_put(:disable_notification, option(attrs, :disable_notification))
    |> maybe_put(:protect_content, option(attrs, :protect_content))
    |> maybe_put(:message_effect_id, option(attrs, :message_effect_id))
    |> maybe_put(:allow_paid_broadcast, option(attrs, :allow_paid_broadcast))
    |> maybe_put(:has_spoiler, option(attrs, :has_spoiler) || option(attrs, :spoiler))
  end

  def maybe_put_thread(map, cid) do
    case ConversationId.thread_integer(cid) do
      nil -> map
      thread -> Map.put(map, :message_thread_id, thread)
    end
  end

  def reply_parameters(%{reply_to_message_id: id} = attrs) when is_integer(id),
    do: build_reply_parameters(id, attrs)

  def reply_parameters(%{reply_to_message_id: id} = attrs) when is_binary(id) do
    case Integer.parse(id) do
      {n, ""} -> build_reply_parameters(n, attrs)
      _ -> nil
    end
  end

  def reply_parameters(%{"reply_to_message_id" => id} = attrs) when is_integer(id),
    do: build_reply_parameters(id, attrs)

  def reply_parameters(%{"reply_to_message_id" => id} = attrs) when is_binary(id) do
    case Integer.parse(id) do
      {n, ""} -> build_reply_parameters(n, attrs)
      _ -> nil
    end
  end

  def reply_parameters(_), do: nil

  def build_reply_parameters(message_id, attrs) do
    %{message_id: message_id, allow_sending_without_reply: true}
    |> maybe_put_reply_quote(attrs)
  end

  def maybe_put_reply_quote(params, attrs) do
    case option(attrs, :quote) do
      quote when is_binary(quote) ->
        params
        |> Map.put(:quote, quote)
        |> maybe_put(:quote_position, normalize_optional_integer(option(attrs, :quote_position)))
        |> maybe_put(:quote_parse_mode, option(attrs, :quote_parse_mode))

      _other ->
        params
    end
  end

  def normalize_optional_integer(value) when is_integer(value), do: value

  def normalize_optional_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {n, ""} -> n
      _ -> nil
    end
  end

  def normalize_optional_integer(_value), do: nil

  def maybe_put(map, _key, nil), do: map
  def maybe_put(map, key, value), do: Map.put(map, key, value)

  def maybe_put_text_parse_mode(payload, text) do
    if String.trim(to_string(text)) == "" do
      payload
    else
      Map.put(payload, :parse_mode, "HTML")
    end
  end

  def reply_markup_from_attrs(attrs) do
    reply_markup(option(attrs, :reply_markup) || option(attrs, :buttons))
  end

  def inline_reply_markup_from_attrs(attrs) do
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

  def invoice_reply_markup_from_attrs(attrs) do
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

  def edit_caption(attrs) do
    case option(attrs, :caption) || option(attrs, :text) do
      nil -> nil
      caption -> Format.to_html(caption)
    end
  end

  def edit_caption_parse_mode(attrs) do
    if is_nil(option(attrs, :caption)) and is_nil(option(attrs, :text)), do: nil, else: "HTML"
  end

  def option(map, key) when is_map(map) do
    cond do
      Map.has_key?(map, key) -> Map.get(map, key)
      Map.has_key?(map, to_string(key)) -> Map.get(map, to_string(key))
      true -> nil
    end
  end

  def validate_conversation_id!(cid) do
    unless ConversationId.valid?(cid) do
      raise ArgumentError, "invalid Telegram conversation id"
    end
  end
end

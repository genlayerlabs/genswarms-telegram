defmodule Genswarms.Telegram.Buttons do
  @moduledoc """
  Safe Telegram reply markup normalization helpers.

  `Genswarms.Telegram.Delivery.reply_markup/1` is strict and raises on invalid
  button data. This module is the tolerant boundary for user or application JSON:
  it drops malformed buttons and normalizes common callback, Web App,
  switch-inline, copy-text, pay, reply-keyboard, remove-keyboard, and force-reply
  shapes.
  """

  alias Genswarms.Telegram.{Delivery, Format}

  @doc """
  Normalize a button list into Delivery-compatible rows.

  Supports URL, callback, Web App, switch-inline, copy-text, and pay buttons.
  The callback key may be either `callback_data` or `action`; `action` is
  normalized to `callback_data`. Invalid rows/buttons are dropped. Returns nil
  when no valid buttons remain.
  """
  def normalize(nil), do: nil
  def normalize([]), do: nil

  def normalize(buttons) when is_list(buttons) do
    rows =
      buttons
      |> Enum.map(&normalize_row/1)
      |> Enum.reject(&(&1 == []))

    if rows == [], do: nil, else: rows
  end

  def normalize(_buttons), do: nil

  @doc "Build reply markup after tolerant normalization."
  def reply_markup(buttons) do
    case normalize_reply_markup(buttons) do
      nil -> nil
      %{inline_keyboard: rows} = markup -> Map.put(markup, :inline_keyboard, rows)
      markup when is_map(markup) -> markup
      rows -> Delivery.reply_markup(rows)
    end
  end

  @doc """
  Normalize Telegram reply markup.

  Lists are treated as inline keyboard shorthand. Maps can describe an
  `inline_keyboard`, `keyboard`, `remove_keyboard`, or `force_reply` markup.
  Invalid controls are dropped and invalid markup returns nil.
  """
  def normalize_reply_markup(nil), do: nil
  def normalize_reply_markup([]), do: nil
  def normalize_reply_markup(buttons) when is_list(buttons), do: normalize(buttons)

  def normalize_reply_markup(%{} = markup) do
    cond do
      inline = get(markup, :inline_keyboard) ->
        case normalize(inline) do
          nil -> nil
          rows -> %{inline_keyboard: rows}
        end

      keyboard = get(markup, :keyboard) ->
        normalize_reply_keyboard(markup, keyboard)

      truthy?(get(markup, :remove_keyboard)) or get(markup, :type) == "remove_keyboard" ->
        %{remove_keyboard: true}
        |> maybe_put_truthy(:selective, get(markup, :selective))

      truthy?(get(markup, :force_reply)) or get(markup, :type) == "force_reply" ->
        %{force_reply: true}
        |> maybe_put_placeholder(get(markup, :input_field_placeholder))
        |> maybe_put_truthy(:selective, get(markup, :selective))

      true ->
        nil
    end
  end

  def normalize_reply_markup(_markup), do: nil

  defp normalize_row(row) when is_list(row),
    do: row |> Enum.map(&normalize_button/1) |> Enum.reject(&is_nil/1)

  defp normalize_row(single), do: [normalize_button(single)] |> Enum.reject(&is_nil/1)

  defp normalize_button(button) when is_map(button) do
    text = get(button, :text)

    cond do
      not valid_text?(text) ->
        nil

      url = get(button, :url) ->
        if is_binary(url) and Format.safe_url?(url), do: %{text: text, url: url}

      data = get(button, :callback_data) || get(button, :action) ->
        if is_binary(data) and data != "" and byte_size(data) <= 64,
          do: %{text: text, callback_data: data}

      web_app = get(button, :web_app) ->
        normalize_web_app(text, web_app)

      query = get(button, :switch_inline_query) ->
        normalize_switch_inline(text, :switch_inline_query, query)

      query = get(button, :switch_inline_query_current_chat) ->
        normalize_switch_inline(text, :switch_inline_query_current_chat, query)

      chosen_chat = get(button, :switch_inline_query_chosen_chat) ->
        normalize_chosen_chat(text, chosen_chat)

      copy_text = get(button, :copy_text) ->
        normalize_copy_text(text, copy_text)

      pay = get(button, :pay) ->
        if pay in [true, "true", 1, "1"], do: %{text: text, pay: true}

      true ->
        nil
    end
  end

  defp normalize_button(_button), do: nil

  defp valid_text?(text), do: is_binary(text) and String.trim(text) != ""

  defp get(map, key), do: Map.get(map, key) || Map.get(map, to_string(key))

  defp normalize_web_app(text, url) when is_binary(url) do
    if Format.safe_url?(url), do: %{text: text, web_app: %{url: url}}
  end

  defp normalize_web_app(text, %{} = web_app) do
    url = get(web_app, :url)
    if is_binary(url) and Format.safe_url?(url), do: %{text: text, web_app: %{url: url}}
  end

  defp normalize_web_app(_text, _web_app), do: nil

  defp normalize_switch_inline(text, field, query) when is_binary(query) do
    if byte_size(query) <= 256, do: Map.put(%{text: text}, field, query)
  end

  defp normalize_switch_inline(_text, _field, _query), do: nil

  defp normalize_chosen_chat(text, %{} = chosen_chat) do
    query = get(chosen_chat, :query) || ""

    if is_binary(query) and byte_size(query) <= 256 do
      allowed =
        chosen_chat
        |> take_truthy([
          :allow_user_chats,
          :allow_bot_chats,
          :allow_group_chats,
          :allow_channel_chats
        ])
        |> Map.put(:query, query)

      %{text: text, switch_inline_query_chosen_chat: allowed}
    end
  end

  defp normalize_chosen_chat(_text, _chosen_chat), do: nil

  defp normalize_copy_text(text, copy_text) when is_binary(copy_text) do
    if byte_size(copy_text) <= 256, do: %{text: text, copy_text: %{text: copy_text}}
  end

  defp normalize_copy_text(text, %{} = copy_text) do
    value = get(copy_text, :text)
    if is_binary(value) and byte_size(value) <= 256, do: %{text: text, copy_text: %{text: value}}
  end

  defp normalize_copy_text(_text, _copy_text), do: nil

  defp normalize_reply_keyboard(markup, keyboard) when is_list(keyboard) do
    rows =
      keyboard
      |> Enum.map(&normalize_keyboard_row/1)
      |> Enum.reject(&(&1 == []))

    if rows == [] do
      nil
    else
      %{keyboard: rows}
      |> maybe_put_truthy(:is_persistent, get(markup, :is_persistent))
      |> maybe_put_truthy(:resize_keyboard, get(markup, :resize_keyboard))
      |> maybe_put_truthy(:one_time_keyboard, get(markup, :one_time_keyboard))
      |> maybe_put_placeholder(get(markup, :input_field_placeholder))
      |> maybe_put_truthy(:selective, get(markup, :selective))
    end
  end

  defp normalize_reply_keyboard(_markup, _keyboard), do: nil

  defp normalize_keyboard_row(row) when is_list(row),
    do: row |> Enum.map(&normalize_keyboard_button/1) |> Enum.reject(&is_nil/1)

  defp normalize_keyboard_row(single),
    do: [normalize_keyboard_button(single)] |> Enum.reject(&is_nil/1)

  defp normalize_keyboard_button(text) when is_binary(text) do
    if valid_text?(text), do: %{text: text}
  end

  defp normalize_keyboard_button(%{} = button) do
    text = get(button, :text)

    if valid_text?(text) and single_keyboard_action?(button) and
         valid_keyboard_action_payload?(button) do
      %{text: text}
      |> maybe_put_non_empty(:icon_custom_emoji_id, get(button, :icon_custom_emoji_id))
      |> maybe_put_style(get(button, :style))
      |> maybe_put_truthy(:request_contact, get(button, :request_contact))
      |> maybe_put_truthy(:request_location, get(button, :request_location))
      |> maybe_put_poll_type(get(button, :request_poll))
      |> maybe_put_keyboard_web_app(get(button, :web_app))
    end
  end

  defp normalize_keyboard_button(_button), do: nil

  defp single_keyboard_action?(button) do
    [
      truthy?(get(button, :request_contact)),
      truthy?(get(button, :request_location)),
      not is_nil(get(button, :request_poll)),
      not is_nil(get(button, :web_app))
    ]
    |> Enum.count(& &1)
    |> Kernel.<=(1)
  end

  defp valid_keyboard_action_payload?(button) do
    valid_keyboard_web_app?(get(button, :web_app)) and
      valid_keyboard_poll?(get(button, :request_poll))
  end

  defp valid_keyboard_web_app?(nil), do: true
  defp valid_keyboard_web_app?(url) when is_binary(url), do: Format.safe_url?(url)

  defp valid_keyboard_web_app?(%{} = web_app),
    do: web_app |> get(:url) |> valid_keyboard_web_app?()

  defp valid_keyboard_web_app?(_web_app), do: false

  defp valid_keyboard_poll?(nil), do: true
  defp valid_keyboard_poll?(type) when type in ["quiz", "regular"], do: true

  defp valid_keyboard_poll?(%{} = poll),
    do: is_nil(get(poll, :type)) or get(poll, :type) in ["quiz", "regular"]

  defp valid_keyboard_poll?(_poll), do: false

  defp maybe_put_style(map, style) when style in ["danger", "success", "primary"],
    do: Map.put(map, :style, style)

  defp maybe_put_style(map, _style), do: map

  defp maybe_put_poll_type(map, nil), do: map

  defp maybe_put_poll_type(map, type) when type in ["quiz", "regular"],
    do: Map.put(map, :request_poll, %{type: type})

  defp maybe_put_poll_type(map, %{} = poll) do
    case get(poll, :type) do
      type when type in ["quiz", "regular"] -> Map.put(map, :request_poll, %{type: type})
      nil -> Map.put(map, :request_poll, %{})
      _ -> map
    end
  end

  defp maybe_put_poll_type(map, _poll), do: map

  defp maybe_put_keyboard_web_app(map, url) when is_binary(url) do
    if Format.safe_url?(url), do: Map.put(map, :web_app, %{url: url}), else: map
  end

  defp maybe_put_keyboard_web_app(map, %{} = web_app) do
    case get(web_app, :url) do
      url when is_binary(url) -> maybe_put_keyboard_web_app(map, url)
      _ -> map
    end
  end

  defp maybe_put_keyboard_web_app(map, _web_app), do: map

  defp maybe_put_non_empty(map, key, value) when is_binary(value) do
    if String.trim(value) == "", do: map, else: Map.put(map, key, value)
  end

  defp maybe_put_non_empty(map, _key, _value), do: map

  defp maybe_put_placeholder(map, value) when is_binary(value) do
    trimmed = String.trim(value)

    if String.length(trimmed) in 1..64,
      do: Map.put(map, :input_field_placeholder, trimmed),
      else: map
  end

  defp maybe_put_placeholder(map, _value), do: map

  defp maybe_put_truthy(map, key, value) do
    if truthy?(value), do: Map.put(map, key, true), else: map
  end

  defp take_truthy(map, keys) do
    Enum.reduce(keys, %{}, fn key, acc ->
      case get(map, key) do
        value when value in [true, "true", 1, "1"] -> Map.put(acc, key, true)
        _ -> acc
      end
    end)
  end

  defp truthy?(value), do: value in [true, "true", 1, "1"]
end

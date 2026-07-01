defmodule Genswarms.Telegram.Delivery do
  @moduledoc """
  Pure Telegram outbound payload helpers.
  """

  alias Genswarms.Telegram.{ConversationId, Format}

  @telegram_text_limit 4096

  def build_send_message(%{conversation_id: cid, text: text} = attrs) do
    validate_conversation_id!(cid)

    base = %{
      chat_id: ConversationId.chat_id(cid),
      text: Format.to_html(text),
      parse_mode: "HTML"
    }

    base
    |> maybe_put_thread(cid)
    |> maybe_put(:reply_parameters, reply_parameters(attrs))
    |> maybe_put(:reply_markup, reply_markup(Map.get(attrs, :buttons)))
  end

  def build_plain_message(%{conversation_id: cid, text: text} = attrs) do
    validate_conversation_id!(cid)

    %{chat_id: ConversationId.chat_id(cid), text: Format.plain(text)}
    |> maybe_put_thread(cid)
    |> maybe_put(:reply_parameters, reply_parameters(attrs))
    |> maybe_put(:reply_markup, reply_markup(Map.get(attrs, :buttons)))
  end

  def build_send_photo(%{conversation_id: cid, photo: photo} = attrs) do
    validate_conversation_id!(cid)

    %{
      chat_id: ConversationId.chat_id(cid),
      photo: photo,
      caption: Format.to_html(Map.get(attrs, :caption, Map.get(attrs, :text, ""))),
      parse_mode: "HTML"
    }
    |> maybe_put_thread(cid)
    |> maybe_put(:reply_markup, reply_markup(Map.get(attrs, :buttons)))
  end

  def chunk_text(text, limit \\ @telegram_text_limit) do
    text
    |> to_string()
    |> String.graphemes()
    |> Enum.reduce([""], fn grapheme, [current | rest] ->
      candidate = current <> grapheme

      if utf16_units(candidate) <= limit do
        [candidate | rest]
      else
        [grapheme, current | rest]
      end
    end)
    |> Enum.reverse()
    |> Enum.reject(&(&1 == ""))
  end

  def utf16_units(text) do
    text
    |> :unicode.characters_to_binary(:utf8, {:utf16, :little})
    |> byte_size()
    |> div(2)
  end

  def reply_markup(nil), do: nil
  def reply_markup([]), do: nil

  def reply_markup(buttons) when is_list(buttons) do
    rows =
      Enum.map(buttons, fn
        row when is_list(row) -> Enum.map(row, &button/1)
        single -> [button(single)]
      end)

    %{inline_keyboard: rows}
  end

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

  defp button(other), do: raise(ArgumentError, "invalid Telegram button: #{inspect(other)}")

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

  defp validate_conversation_id!(cid) do
    unless ConversationId.valid?(cid) do
      raise ArgumentError, "invalid Telegram conversation id"
    end
  end
end

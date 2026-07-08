defmodule Genswarms.Telegram.Parser do
  @moduledoc """
  Normalize Telegram update maps into transport events.
  """

  alias Genswarms.Telegram.ConversationId

  @text_media ~w(animation audio document photo sticker video video_note voice contact dice game location poll venue)

  @doc "Parse one Telegram update map."
  def parse_update(%{"edited_message" => _}), do: :ignore
  def parse_update(%{"edited_channel_post" => _}), do: :ignore

  def parse_update(%{"callback_query" => cb} = update) when is_map(cb) do
    with %{"id" => callback_id, "message" => %{"chat" => %{"id" => chat_id}} = message} <- cb do
      chat = Map.get(message, "chat", %{})
      thread_id = session_thread_id(message)

      {:ok,
       %{
         type: :callback,
         update_id: Map.get(update, "update_id"),
         callback_query_id: callback_id,
         data: Map.get(cb, "data", ""),
         conversation_id: ConversationId.build(chat_id, thread_id),
         chat_id: chat_id,
         chat_type: Map.get(chat, "type"),
         thread_id: thread_id,
         message_id: Map.get(message, "message_id"),
         identity: identity(Map.get(cb, "from", %{}))
       }}
    else
      _ -> :ignore
    end
  end

  def parse_update(%{"my_chat_member" => member} = update) when is_map(member) do
    with %{"chat" => %{"id" => chat_id} = chat} <- member do
      status = get_in(member, ["new_chat_member", "status"])

      {:ok,
       %{
         type: :member,
         update_id: Map.get(update, "update_id"),
         status: status,
         reachable?: status not in ["kicked", "left"],
         conversation_id: ConversationId.build(chat_id, "0"),
         chat_id: chat_id,
         chat_type: Map.get(chat, "type"),
         thread_id: "0",
         identity: identity(Map.get(member, "from", %{}))
       }}
    else
      _ -> :ignore
    end
  end

  def parse_update(%{"message" => message} = update), do: parse_message(update, message, :message)

  def parse_update(%{"channel_post" => message} = update),
    do: parse_message(update, message, :channel_post)

  def parse_update(_), do: :ignore

  defp parse_message(update, %{"chat" => %{"id" => chat_id} = chat} = message, source) do
    thread_id = session_thread_id(message)
    {kind, text} = text_from_message(message)

    event =
      %{
        type: kind,
        source: source,
        update_id: Map.get(update, "update_id"),
        conversation_id: ConversationId.build(chat_id, thread_id),
        chat_id: chat_id,
        chat_type: Map.get(chat, "type"),
        thread_id: thread_id,
        message_id: Map.get(message, "message_id"),
        date: Map.get(message, "date"),
        text: text,
        media: media_kind(message),
        reply_to_bot_username: get_in(message, ["reply_to_message", "from", "username"]),
        identity: identity(Map.get(message, "from", %{}))
      }
      |> maybe_put(:replied_to, replied_to(message))

    {:ok, event}
  end

  defp parse_message(_update, _message, _source), do: :ignore

  # message_thread_id names a real conversation ONLY for forum-topic messages;
  # on any other group message it's just the reply-chain root id, and keying
  # sessions on it forks one group chat into a session per reply chain.
  defp session_thread_id(message) do
    if Map.get(message, "is_topic_message", false),
      do: Map.get(message, "message_thread_id", "0"),
      else: "0"
  end

  defp text_from_message(%{"text" => text}) when is_binary(text), do: {:text, text}
  defp text_from_message(%{"caption" => caption}) when is_binary(caption), do: {:text, caption}
  defp text_from_message(_), do: {:non_text, ""}

  defp media_kind(message) do
    Enum.find(@text_media, &Map.has_key?(message, &1))
  end

  defp replied_to(%{"reply_to_message" => %{"message_id" => id} = replied} = message)
       when is_integer(id) do
    %{
      message_id: id,
      text: replied_text(replied),
      quote: text_quote(message)
    }
  end

  defp replied_to(_message), do: nil

  defp replied_text(message) do
    cond do
      is_binary(Map.get(message, "text")) -> Map.get(message, "text")
      is_binary(Map.get(message, "caption")) -> Map.get(message, "caption")
      true -> nil
    end
  end

  defp text_quote(%{"quote" => %{"text" => text} = quote}) when is_binary(text) do
    %{
      text: text,
      position: quote_position(Map.get(quote, "position"))
    }
  end

  defp text_quote(_message), do: nil

  defp quote_position(position) when is_integer(position), do: position
  defp quote_position(_position), do: nil

  defp identity(nil), do: %{}

  defp identity(from) when is_map(from) do
    username = Map.get(from, "username")

    %{
      user_id: Map.get(from, "id"),
      is_bot: Map.get(from, "is_bot"),
      first_name: Map.get(from, "first_name"),
      last_name: Map.get(from, "last_name"),
      username: username,
      handle: username,
      language_code: Map.get(from, "language_code"),
      language: Map.get(from, "language_code"),
      is_premium: Map.get(from, "is_premium"),
      premium: Map.get(from, "is_premium")
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end

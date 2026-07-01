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
      thread_id = Map.get(message, "message_thread_id", "0")

      {:ok,
       %{
         type: :callback,
         update_id: Map.get(update, "update_id"),
         callback_query_id: callback_id,
         data: Map.get(cb, "data", ""),
         conversation_id: ConversationId.build(chat_id, thread_id),
         chat_id: chat_id,
         thread_id: thread_id,
         message_id: Map.get(message, "message_id"),
         identity: identity(Map.get(cb, "from", %{}))
       }}
    else
      _ -> :ignore
    end
  end

  def parse_update(%{"my_chat_member" => member} = update) when is_map(member) do
    with %{"chat" => %{"id" => chat_id}} <- member do
      status = get_in(member, ["new_chat_member", "status"])

      {:ok,
       %{
         type: :member,
         update_id: Map.get(update, "update_id"),
         status: status,
         reachable?: status not in ["kicked", "left"],
         conversation_id: ConversationId.build(chat_id, "0"),
         chat_id: chat_id,
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

  defp parse_message(update, %{"chat" => %{"id" => chat_id}} = message, source) do
    thread_id = Map.get(message, "message_thread_id", "0")
    {kind, text} = text_from_message(message)

    {:ok,
     %{
       type: kind,
       source: source,
       update_id: Map.get(update, "update_id"),
       conversation_id: ConversationId.build(chat_id, thread_id),
       chat_id: chat_id,
       thread_id: thread_id,
       message_id: Map.get(message, "message_id"),
       date: Map.get(message, "date"),
       text: text,
       media: media_kind(message),
       reply_to_bot_username: get_in(message, ["reply_to_message", "from", "username"]),
       identity: identity(Map.get(message, "from", %{}))
     }}
  end

  defp parse_message(_update, _message, _source), do: :ignore

  defp text_from_message(%{"text" => text}) when is_binary(text), do: {:text, text}
  defp text_from_message(%{"caption" => caption}) when is_binary(caption), do: {:text, caption}
  defp text_from_message(_), do: {:non_text, ""}

  defp media_kind(message) do
    Enum.find(@text_media, &Map.has_key?(message, &1))
  end

  defp identity(nil), do: %{}

  defp identity(from) when is_map(from) do
    %{
      user_id: Map.get(from, "id"),
      is_bot: Map.get(from, "is_bot"),
      first_name: Map.get(from, "first_name"),
      last_name: Map.get(from, "last_name"),
      username: Map.get(from, "username"),
      language_code: Map.get(from, "language_code"),
      is_premium: Map.get(from, "is_premium")
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end
end

defmodule Genswarms.Telegram.Client do
  @moduledoc """
  Telegram Bot API client behaviour and dispatch helpers.
  """

  @type method ::
          :get_me
          | :get_updates
          | :answer_callback_query
          | :set_my_commands
          | :send_message
          | :send_photo
          | :send_chat_action
          | :edit_message_text

  @type result :: {:ok, term()} | {:error, term()}

  @callback request(method(), map(), keyword()) :: result()

  @method_names %{
    get_me: "getMe",
    get_updates: "getUpdates",
    answer_callback_query: "answerCallbackQuery",
    set_my_commands: "setMyCommands",
    send_message: "sendMessage",
    send_photo: "sendPhoto",
    send_chat_action: "sendChatAction",
    edit_message_text: "editMessageText"
  }

  def request(adapter, method, payload, opts \\ []) when is_atom(adapter) and is_atom(method) do
    adapter.request(method, payload, opts)
  end

  def get_me(adapter, opts \\ []), do: request(adapter, :get_me, %{}, opts)
  def get_updates(adapter, payload, opts \\ []), do: request(adapter, :get_updates, payload, opts)

  def answer_callback_query(adapter, payload, opts \\ []),
    do: request(adapter, :answer_callback_query, payload, opts)

  def set_my_commands(adapter, payload, opts \\ []),
    do: request(adapter, :set_my_commands, payload, opts)

  def send_message(adapter, payload, opts \\ []),
    do: request(adapter, :send_message, payload, opts)

  def send_photo(adapter, payload, opts \\ []), do: request(adapter, :send_photo, payload, opts)

  def send_chat_action(adapter, payload, opts \\ []),
    do: request(adapter, :send_chat_action, payload, opts)

  def edit_message_text(adapter, payload, opts \\ []),
    do: request(adapter, :edit_message_text, payload, opts)

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

  defp classify_decoded(_status, %{"ok" => false, "error_code" => 429} = body) do
    retry_after = get_in(body, ["parameters", "retry_after"]) || 1
    {:error, {:rate_limited, retry_after, Map.get(body, "description", "")}}
  end

  defp classify_decoded(_status, %{"ok" => false, "error_code" => code} = body)
       when code in [400, 403] do
    description = Map.get(body, "description", "")

    cond do
      String.contains?(String.downcase(description), "can't parse") ->
        {:error, {:parse_error, description}}

      String.contains?(String.downcase(description), "bot was blocked") or
          String.contains?(String.downcase(description), "chat not found") ->
        {:error, {:dead_chat, code, description}}

      true ->
        {:error, {:failed, code, description}}
    end
  end

  defp classify_decoded(status, %{"ok" => false} = body) when status >= 500,
    do: {:error, {:transient, status, Map.get(body, "description", "")}}

  defp classify_decoded(status, %{"ok" => false} = body),
    do: {:error, {:failed, Map.get(body, "error_code", status), Map.get(body, "description", "")}}

  defp classify_decoded(status, body) when status >= 500, do: {:error, {:transient, status, body}}
  defp classify_decoded(status, body), do: {:error, {:unexpected_response, status, body}}
end

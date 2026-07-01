defmodule Genswarms.Telegram.Client do
  @moduledoc """
  Telegram Bot API client behaviour and dispatch helpers.
  """

  @type method ::
          :get_me
          | :get_updates
          | :answer_callback_query
          | :set_my_commands
          | :set_webhook
          | :delete_webhook
          | :get_webhook_info
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
    set_webhook: "setWebhook",
    delete_webhook: "deleteWebhook",
    get_webhook_info: "getWebhookInfo",
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

  def set_webhook(adapter, payload, opts \\ []),
    do: request(adapter, :set_webhook, payload, opts)

  def delete_webhook(adapter, payload \\ %{}, opts \\ []),
    do: request(adapter, :delete_webhook, payload, opts)

  def get_webhook_info(adapter, opts \\ []), do: request(adapter, :get_webhook_info, %{}, opts)

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

  defp classify_decoded(status, %{"ok" => true} = body) when status in 200..299,
    do: {:ok, Map.get(body, "result", body)}

  defp classify_decoded(_status, %{"ok" => false, "error_code" => 429} = body) do
    retry_after = get_in(body, ["parameters", "retry_after"]) || 1
    {:error, {:rate_limited, retry_after, Map.get(body, "description", "")}}
  end

  defp classify_decoded(_status, %{"ok" => false, "error_code" => code} = body)
       when code in [400, 403] do
    description = Map.get(body, "description", "")

    cond do
      parse_error_description?(description) ->
        {:error, {:parse_error, description}}

      dead_chat_description?(description) ->
        {:error, {:dead_chat, code, description}}

      true ->
        {:error, {:failed, code, description}}
    end
  end

  defp classify_decoded(_status, %{"ok" => false, "error_code" => code} = body)
       when is_integer(code) and code >= 500,
       do: {:error, {:transient, code, Map.get(body, "description", "")}}

  defp classify_decoded(status, %{"ok" => false} = body) when status >= 500,
    do: {:error, {:transient, status, Map.get(body, "description", "")}}

  defp classify_decoded(status, %{"ok" => false} = body),
    do: {:error, {:failed, Map.get(body, "error_code", status), Map.get(body, "description", "")}}

  defp classify_decoded(status, body) when status >= 500, do: {:error, {:transient, status, body}}
  defp classify_decoded(status, body), do: {:error, {:unexpected_response, status, body}}

  @dead_chat_markers [
    "bot was blocked",
    "chat not found",
    "user is deactivated",
    "bot was kicked",
    "peer_id_invalid",
    "group chat was upgraded",
    "chat was deleted"
  ]

  @doc "True when a Telegram error description names a permanently dead recipient."
  def dead_chat_description?(description) when is_binary(description) do
    down = String.downcase(description)
    Enum.any?(@dead_chat_markers, &String.contains?(down, &1))
  end

  def dead_chat_description?(_), do: false

  defp parse_error_description?(description) do
    down = String.downcase(to_string(description))
    String.contains?(down, "parse") or String.contains?(down, "entities")
  end
end

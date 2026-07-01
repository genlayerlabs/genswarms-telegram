defmodule Genswarms.Telegram.Addressing do
  @moduledoc """
  Pure Telegram addressing helpers.

  These helpers decide whether text or a normalized parser event is addressed to
  the current bot. They do not know about any consuming swarm's commands or
  product policy.
  """

  alias Genswarms.Telegram.ConversationId

  @doc """
  Classify the first token of a Telegram slash command.
  """
  def command_target(text) do
    case text |> to_string() |> String.trim_leading() |> String.split(~r/\s+/, parts: 2) do
      ["/" <> raw | _] ->
        case String.split(raw, "@", parts: 2) do
          [_verb, target] when target != "" -> {:target, target}
          _ -> :bare
        end

      _ ->
        :not_command
    end
  end

  @doc """
  Return true when a slash command is meant for this bot.

  Bare commands are accepted. Commands with an `@botname` suffix are accepted
  only when the suffix matches `bot_username`.
  """
  def command_addressed?(text, bot_username) do
    case command_target(text) do
      :bare -> true
      {:target, target} -> same_username?(target, bot_username)
      :not_command -> false
    end
  end

  @doc """
  Return true when a parsed event is addressed to this bot.

  DMs are always addressed. Groups require a bot username unless
  `:fail_open_without_username?` is true. Group text is addressed when it replies
  to the bot or mentions `@bot_username`.
  """
  def addressed?(event, bot_username, opts \\ %{}) when is_map(event) do
    case ConversationId.chat_type(Map.get(event, :conversation_id)) do
      :dm -> true
      :group -> group_addressed?(event, bot_username, opts)
      :unknown -> false
    end
  end

  def group_addressed?(event, bot_username, opts \\ %{}) when is_map(event) do
    cond do
      is_nil(bot_username) ->
        option(opts, :fail_open_without_username?, false)

      same_username?(Map.get(event, :reply_to_bot_username), bot_username) ->
        true

      mentioned?(Map.get(event, :text, ""), bot_username) ->
        true

      true ->
        false
    end
  end

  def mentioned?(text, bot_username) when is_binary(bot_username) and bot_username != "" do
    String.match?(to_string(text), mention_regex(bot_username))
  end

  def mentioned?(_text, _bot_username), do: false

  def same_username?(_left, nil), do: false
  def same_username?(nil, _right), do: false

  def same_username?(left, right) do
    String.downcase(to_string(left)) == String.downcase(to_string(right))
  end

  def mention_regex(username), do: ~r/(^|[^\w])@#{Regex.escape(username)}([^\w]|$)/i

  defp option(opts, key, default) when is_map(opts), do: Map.get(opts, key, default)
  defp option(opts, key, default) when is_list(opts), do: Keyword.get(opts, key, default)
  defp option(_opts, _key, default), do: default
end

defmodule Genswarms.Telegram.BotRef do
  @moduledoc """
  Non-secret bot namespace helpers.

  Telegram bot tokens must not appear in paths, logs, or persisted local state.
  `from_token/1` creates a stable short fingerprint suitable for file paths.
  """

  @doc "Return a stable, non-secret fingerprint for a Telegram bot token."
  def from_token(token) when is_binary(token) and token != "" do
    :crypto.hash(:sha256, token)
    |> Base.url_encode64(padding: false)
    |> binary_part(0, 16)
  end

  def from_token(_), do: "unknown_bot"

  @doc "Return a filesystem-safe path segment for a bot namespace or configured ref."
  def path_key(ref) do
    ref
    |> to_string()
    |> String.replace(~r/[^A-Za-z0-9_.-]/, "_")
    |> case do
      "" -> "unknown_bot"
      "." -> "unknown_bot"
      ".." -> "unknown_bot"
      safe -> safe
    end
  end
end

defmodule Genswarms.Telegram.BotRef do
  @moduledoc """
  Non-secret bot namespace helpers.

  Telegram bot tokens must not appear in paths, logs, or persisted local state.
  `from_token/1` creates a stable short fingerprint suitable for file paths.
  """

  @doc """
  Resolve the bot token from an object config (gsp design §14.2.1 x-secret
  contract). Precedence: literal `:bot_token` (tests/legacy) → the env var
  NAMED by `:bot_token_env` → `GENSWARMS_TELEGRAM_BOT_TOKEN`. With
  `bot_token_env` the swarm config carries only the variable name, so the
  secret never appears in configs, overlay logs, snapshots or config UIs.
  """
  def resolve_token(config) do
    Map.get(config, :bot_token) ||
      env_token(Map.get(config, :bot_token_env)) ||
      System.get_env("GENSWARMS_TELEGRAM_BOT_TOKEN")
  end

  defp env_token(var) when is_binary(var) and var != "", do: System.get_env(var)
  defp env_token(_), do: nil

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

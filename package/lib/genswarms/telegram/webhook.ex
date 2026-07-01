defmodule Genswarms.Telegram.Webhook do
  @moduledoc """
  Telegram webhook verification and decoding helpers.

  v0.1 provides helpers only; the host owns the HTTP server.
  """

  alias Genswarms.Telegram.Parser

  @secret_header "x-telegram-bot-api-secret-token"

  def parse(body, headers, opts \\ []) when is_binary(body) do
    with {:ok, update} <- decode_update(body, headers, opts) do
      Parser.parse_update(update)
    end
  end

  def decode_update(body, headers, opts \\ []) when is_binary(body) do
    with :ok <- verify_secret(headers, Keyword.get(opts, :secret_token)),
         {:ok, update} <- Jason.decode(body) do
      {:ok, update}
    else
      {:error, %Jason.DecodeError{} = error} -> {:error, {:bad_json, error}}
      other -> other
    end
  end

  def verify_secret(_headers, nil), do: :ok
  def verify_secret(_headers, ""), do: :ok

  def verify_secret(headers, expected) do
    actual =
      headers
      |> normalize_headers()
      |> Map.get(@secret_header)

    if actual == expected, do: :ok, else: {:error, :invalid_secret_token}
  end

  defp normalize_headers(headers) when is_map(headers) do
    Map.new(headers, fn {k, v} -> {String.downcase(to_string(k)), to_string(v)} end)
  end

  defp normalize_headers(headers) when is_list(headers) do
    Map.new(headers, fn {k, v} -> {String.downcase(to_string(k)), to_string(v)} end)
  end
end

defmodule Genswarms.Telegram.OffsetFile do
  @moduledoc """
  Small getUpdates offset-file helper.

  This is useful for hosts that already store the polling offset as a single
  integer file instead of using `Genswarms.Telegram.Store.File`'s JSON state.
  """

  @doc """
  Derive a per-token offset file path from a configured base path.

  The token is never written to the path; a short hash suffix is used instead.
  """
  def path(nil, _token), do: nil
  def path(base, nil), do: base
  def path(base, ""), do: base
  def path(base, token), do: base <> "." <> token_tag(token)

  @doc "Read a persisted getUpdates offset, returning 0 when absent or unreadable."
  def read(nil), do: 0

  def read(path) do
    case File.read(path) do
      {:ok, content} ->
        case Integer.parse(String.trim(content)) do
          {n, _} when n >= 0 -> n
          _ -> 0
        end

      _ ->
        0
    end
  end

  @doc "Persist the getUpdates offset best-effort."
  def write(nil, _offset), do: :ok

  def write(path, offset) when is_integer(offset) and offset >= 0 do
    File.mkdir_p(Path.dirname(path))
    File.write(path, Integer.to_string(offset))
    :ok
  rescue
    _ -> :ok
  end

  def write(_path, _offset), do: :ok

  def token_tag(token),
    do: :crypto.hash(:sha256, token) |> Base.encode16(case: :lower) |> binary_part(0, 8)
end

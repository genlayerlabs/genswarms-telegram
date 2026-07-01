defmodule Genswarms.Telegram.Poller do
  @moduledoc """
  Telegram `getUpdates` polling helpers.

  The poller only fetches and computes the next offset. The caller should process
  the returned updates first, then persist the offset, so a crash during handling
  replays through the normal update-id dedupe path instead of skipping messages.
  """

  alias Genswarms.Telegram.Client

  def fetch_updates(client, store, bot_ref, opts \\ []) do
    offset = store.read_offset(bot_ref)
    payload = get_updates_payload(offset, opts)

    case Client.get_updates(client, payload, Keyword.fetch!(opts, :client_opts)) do
      {:ok, updates} when is_list(updates) ->
        {:ok, updates, next_offset(offset, updates)}

      {:ok, other} ->
        {:error, {:bad_updates_result, other}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def get_updates_payload(offset, opts \\ []) do
    %{
      offset: offset,
      timeout: Keyword.get(opts, :timeout_s, 25),
      allowed_updates:
        Keyword.get(opts, :allowed_updates, [
          "message",
          "channel_post",
          "callback_query",
          "my_chat_member"
        ])
    }
  end

  def next_offset(offset, updates) when is_list(updates) do
    updates
    |> Enum.map(&Map.get(&1, "update_id"))
    |> Enum.filter(&is_integer/1)
    |> case do
      [] -> offset
      ids -> Enum.max(ids) + 1
    end
  end
end

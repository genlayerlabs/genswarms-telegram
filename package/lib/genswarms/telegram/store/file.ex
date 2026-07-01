defmodule Genswarms.Telegram.Store.File do
  @moduledoc """
  Local file-backed store for demos, tests, and small bots.

  This is bot-level transport state, not conversation memory.
  """

  @behaviour Genswarms.Telegram.Store

  @seen_limit 1_000

  @impl true
  def update_seen?(bot_ref, update_id) when is_integer(update_id) do
    update_id in Map.get(read(bot_ref), "seen_updates", [])
  end

  def update_seen?(_bot_ref, _update_id), do: false

  @impl true
  def mark_update_seen(bot_ref, update_id) when is_integer(update_id) do
    update(bot_ref, fn state ->
      seen = Map.get(state, "seen_updates", [])

      if update_id in seen do
        {:duplicate, state}
      else
        seen = [update_id | seen] |> Enum.uniq() |> Enum.take(@seen_limit)
        {:new, Map.put(state, "seen_updates", seen)}
      end
    end)
  end

  def mark_update_seen(_bot_ref, _update_id), do: :new

  @impl true
  def read_offset(bot_ref) do
    bot_ref
    |> read()
    |> Map.get("offset", 0)
  end

  @impl true
  def write_offset(bot_ref, offset) when is_integer(offset) and offset >= 0 do
    update(bot_ref, fn state -> {:ok, Map.put(state, "offset", offset)} end)
  end

  @doc "Resolve the package state dir."
  def root_dir do
    Application.get_env(:genswarms_telegram, :state_dir) ||
      Path.join([xdg_state_home(), "genswarms", "telegram"])
  end

  def state_path(bot_ref), do: Path.join([root_dir(), safe_ref(bot_ref), "state.json"])

  def read(bot_ref) do
    path = state_path(bot_ref)

    case File.read(path) do
      {:ok, body} ->
        case Jason.decode(body) do
          {:ok, state} when is_map(state) -> state
          _ -> default_state()
        end

      {:error, _} ->
        default_state()
    end
  end

  def update(bot_ref, fun) do
    path = state_path(bot_ref)

    :global.trans({__MODULE__, path}, fn ->
      state = read(bot_ref)
      {reply, next_state} = fun.(state)

      case write_atomic(path, next_state) do
        :ok -> reply
        {:error, reason} -> {:error, reason}
      end
    end)
  end

  defp write_atomic(path, state) do
    dir = Path.dirname(path)
    File.mkdir_p!(dir)
    tmp = path <> ".#{System.unique_integer([:positive])}.tmp"

    with :ok <- File.write(tmp, Jason.encode!(state), [:exclusive]),
         :ok <- File.rename(tmp, path) do
      :ok
    else
      error ->
        File.rm(tmp)
        error
    end
  end

  defp default_state, do: %{"offset" => 0, "seen_updates" => []}

  defp xdg_state_home do
    System.get_env("XDG_STATE_HOME") ||
      Path.join(System.get_env("HOME") || ".", ".local/state")
  end

  defp safe_ref(bot_ref), do: Genswarms.Telegram.BotRef.path_key(bot_ref)
end

defmodule Genswarms.Telegram.Context.MemoryMd do
  @moduledoc """
  Durable per-conversation MEMORY.md context.

  Durable files live outside reusable slot workspaces and are keyed by bot and
  conversation id. A host may expose a copy or read-only bind into each fresh
  workspace.
  """

  @behaviour Genswarms.Telegram.Context

  alias Genswarms.Telegram.ConversationId
  alias Genswarms.Telegram.Store.File, as: FileStore

  @default_max_bytes 24_000

  @impl true
  def init_session(bot_ref, conversation_id, opts \\ %{}) do
    path = memory_path(bot_ref, conversation_id)

    unless File.exists?(path) do
      File.mkdir_p!(Path.dirname(path))
      File.write(path, template(conversation_id), [:exclusive])
    else
      :ok
    end
    |> case do
      :ok ->
        expose_to_workspace(path, Map.get(opts, :workspace))

      {:error, :eexist} ->
        expose_to_workspace(path, Map.get(opts, :workspace))

      error ->
        error
    end
  end

  @impl true
  def before_turn(bot_ref, conversation_id, _text, opts \\ %{}) do
    init_session(bot_ref, conversation_id, opts)
    max_bytes = Map.get(opts, :max_bytes, @default_max_bytes)

    bot_ref
    |> memory_path(conversation_id)
    |> read_tail(max_bytes)
  end

  @impl true
  def after_turn(bot_ref, conversation_id, role, text, opts \\ %{}) do
    init_session(bot_ref, conversation_id, opts)
    path = memory_path(bot_ref, conversation_id)
    line = "- #{role}: " <> sanitize(text) <> "\n"

    with :ok <- File.write(path, line, [:append]),
         :ok <- trim(path, Map.get(opts, :max_bytes, @default_max_bytes)) do
      :ok
    end
  end

  def memory_path(bot_ref, conversation_id) do
    Path.join([
      FileStore.root_dir(),
      Genswarms.Telegram.BotRef.path_key(bot_ref),
      "conversations",
      ConversationId.encode_for_path(conversation_id),
      "MEMORY.md"
    ])
  end

  def delete(bot_ref, conversation_id) do
    bot_ref
    |> memory_path(conversation_id)
    |> Path.dirname()
    |> File.rm_rf()

    :ok
  end

  defp expose_to_workspace(_durable_path, nil), do: :ok

  defp expose_to_workspace(durable_path, workspace) when is_binary(workspace) do
    File.mkdir_p!(workspace)
    File.cp(durable_path, Path.join(workspace, "MEMORY.md"))
  end

  defp template(conversation_id) do
    """
    # Memory

    ## Conversation
    - Telegram conversation: #{conversation_id}
    - Last updated: #{DateTime.utc_now() |> DateTime.to_iso8601()}

    ## Notes

    ## Recent Turns
    """
  end

  defp read_tail(path, max_bytes) do
    case File.read(path) do
      {:ok, body} ->
        if byte_size(body) > max_bytes do
          binary_part(body, byte_size(body) - max_bytes, max_bytes)
        else
          body
        end

      {:error, _} ->
        ""
    end
  end

  defp trim(path, max_bytes) do
    case File.read(path) do
      {:ok, body} when byte_size(body) > max_bytes ->
        keep = binary_part(body, byte_size(body) - max_bytes, max_bytes)
        File.write(path, "# Memory\n\n" <> keep)

      {:ok, _body} ->
        :ok

      error ->
        error
    end
  end

  defp sanitize(text) do
    text
    |> to_string()
    |> String.replace(~r/[\r\n]+/, " ")
    |> String.slice(0, 2_000)
  end
end

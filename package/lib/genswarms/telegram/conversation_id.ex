defmodule Genswarms.Telegram.ConversationId do
  @moduledoc """
  Canonical Telegram conversation id helpers.

      tg:<chat_id>:<thread_id_or_0>

  Positive chat ids are DMs. Negative chat ids are groups, supergroups, channels,
  or topics. Privacy-sensitive consumers should use `dm?/1`, which fails closed.
  """

  @doc ~s(Build "tg:<chat_id>:<thread_id>".)
  def build(chat_id, thread_id \\ "0"), do: "tg:#{chat_id}:#{thread_id || "0"}"

  @doc "Strictly parse `tg:<chat>:<thread>`."
  def parse(cid) when is_binary(cid) do
    case String.split(cid, ":") do
      ["tg", chat, thread] -> {:ok, %{chat_id: chat, thread_id: thread}}
      _ -> :error
    end
  end

  def parse(cid), do: cid |> to_string() |> parse()

  @doc "True only for strict `tg:<integer_chat>:<integer_thread>` conversation ids."
  def valid?(cid) do
    case parse(cid) do
      {:ok, %{chat_id: chat, thread_id: thread}} ->
        integer_string?(chat) and nonnegative_integer_string?(thread)

      :error ->
        false
    end
  end

  @doc "True only when the cid parses and the Telegram chat id is positive."
  def dm?(cid) do
    case parse(cid) do
      {:ok, %{chat_id: chat}} -> dm_chat?(chat)
      :error -> false
    end
  end

  @doc "Positive integer chat ids are DMs. Junk fails closed."
  def dm_chat?(chat_id) do
    case Integer.parse(to_string(chat_id)) do
      {n, ""} -> n > 0
      {_n, _rest} -> false
      :error -> false
    end
  end

  @doc "Return `dm`, `group`, or `unknown`."
  def chat_type("tg:" <> _ = cid) do
    if valid?(cid), do: if(dm?(cid), do: :dm, else: :group), else: :unknown
  end

  def chat_type(_), do: :unknown

  @doc "Extract chat id from `tg:<chat>:<thread>` or legacy `tg_<chat>_<thread>`."
  def chat_id("tg:" <> _ = cid) do
    case String.split(cid, ":") do
      ["tg", chat, _thread] -> chat
      _ -> cid
    end
  end

  def chat_id("tg_" <> _ = cid) do
    case String.split(cid, "_") do
      ["tg", chat, _thread] -> chat
      _ -> cid
    end
  end

  def chat_id(other), do: other

  @doc "Extract thread id from `tg:<chat>:<thread>` or legacy `tg_<chat>_<thread>`."
  def thread_id("tg:" <> _ = cid) do
    case String.split(cid, ":") do
      ["tg", _chat, thread] -> thread
      _ -> nil
    end
  end

  def thread_id("tg_" <> _ = cid) do
    case String.split(cid, "_") do
      ["tg", _chat, thread] -> thread
      _ -> nil
    end
  end

  def thread_id(_), do: nil

  @doc "Path-safe, reversible conversation key."
  def encode_for_path(cid) when is_binary(cid), do: Base.url_encode64(cid, padding: false)
  def encode_for_path(cid), do: cid |> to_string() |> encode_for_path()

  @doc "Parse a non-negative thread id, returning nil when invalid or absent."
  def thread_integer(cid) do
    case thread_id(cid) do
      nil ->
        nil

      thread ->
        case Integer.parse(to_string(thread)) do
          {0, ""} -> nil
          {n, ""} when n > 0 -> n
          _ -> nil
        end
    end
  end

  defp integer_string?(value) do
    case Integer.parse(to_string(value)) do
      {_n, ""} -> true
      _ -> false
    end
  end

  defp nonnegative_integer_string?(value) do
    case Integer.parse(to_string(value)) do
      {n, ""} -> n >= 0
      _ -> false
    end
  end
end

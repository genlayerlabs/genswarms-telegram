defmodule Genswarms.Telegram.Client.Fake do
  @moduledoc """
  In-memory Telegram client for tests and examples.
  """

  @behaviour Genswarms.Telegram.Client

  def start_link(script \\ []) do
    Agent.start_link(fn -> %{calls: [], script: List.wrap(script)} end)
  end

  def calls(pid) do
    Agent.get(pid, fn state -> Enum.reverse(state.calls) end)
  end

  def push_response(pid, response) do
    Agent.update(pid, fn state -> %{state | script: state.script ++ [response]} end)
  end

  @impl true
  def request(method, payload, opts) do
    pid = Keyword.fetch!(opts, :fake)

    Agent.get_and_update(pid, fn state ->
      response =
        case state.script do
          [next | rest] -> {next, %{state | script: rest}}
          [] -> {default_response(method, payload), state}
        end

      {reply, state} = response
      call = %{method: method, payload: payload}
      {reply, %{state | calls: [call | state.calls]}}
    end)
  end

  defp default_response(:get_me, _payload),
    do: {:ok, %{"username" => "FakeTelegramBot", "id" => 1}}

  defp default_response(:get_updates, _payload), do: {:ok, []}
  defp default_response(:send_message, _payload), do: {:ok, %{"message_id" => 1}}
  defp default_response(:send_photo, _payload), do: {:ok, %{"message_id" => 2}}
  defp default_response(:edit_message_text, _payload), do: {:ok, %{"message_id" => 3}}
  defp default_response(_method, _payload), do: {:ok, true}
end

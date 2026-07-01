defmodule Genswarms.Telegram.CommandRouter.Basic do
  @moduledoc "Minimal non-product command router."

  @behaviour Genswarms.Telegram.CommandRouter

  @impl true
  def handle_command(%{text: text}, _state) do
    case command_name(text) do
      "start" -> {:reply, "Started."}
      "help" -> {:reply, "Send a message and I will route it to the swarm."}
      _ -> {:reply, "Unknown command."}
    end
  end

  @impl true
  def handle_callback(_event, _state), do: :ok

  @impl true
  def command_menu(:dm, _state) do
    [
      %{command: "start", description: "Start"},
      %{command: "help", description: "Help"}
    ]
  end

  def command_menu(:group, _state), do: [%{command: "help", description: "Help"}]

  defp command_name("/" <> rest) do
    rest
    |> String.split(~r/\s+/, parts: 2)
    |> hd()
    |> String.split("@", parts: 2)
    |> hd()
  end

  defp command_name(_), do: ""
end

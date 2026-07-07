defmodule Genswarms.Telegram.CommandRouter.Basic do
  @moduledoc "Minimal non-product command router."

  @behaviour Genswarms.Telegram.CommandRouter

  # Deterministic fixed text — /about never touches an agent, so answering
  # "what is this bot?" costs zero LLM context. Swarm-agnostic on purpose:
  # GenLayer Labs is credited for the stack, not for whichever swarm adopted
  # this package. Kept out of command_menu/2 — discoverable, not advertised.
  @about_text """
              I'm an autonomous agent running on the GenLayer stack, built by GenLayer Labs:

              • Subzeroclaw — a tiny agent loop (2–4 MB, one tool: the shell). My body. subzeroclaw.com
              • Unhardcoded — a runtime router picking the right model for each step. My brain. unhardcoded.com
              • GenSwarms — isolated agents coordinating through tools, objects, and each other. My world. genswarms.com

              GenLayer Labs also builds the GenLayer protocol — a network where independent AI validators settle the outcomes plain code can't judge. genlayer.com

              The stack acts. The protocol judges.

              More: https://genlayerlabs.com
              """
              |> String.trim()

  @impl true
  def handle_command(%{text: text}, _state) do
    case command_name(text) do
      "start" -> {:reply, "Started."}
      "help" -> {:reply, "Send a message and I will route it to the swarm."}
      "about" -> {:reply, @about_text}
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

  defp command_name(text) when is_binary(text) do
    trimmed = String.trim_leading(text)
    if trimmed == text, do: "", else: command_name(trimmed)
  end

  defp command_name(_), do: ""
end

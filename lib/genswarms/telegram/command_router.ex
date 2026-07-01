defmodule Genswarms.Telegram.CommandRouter do
  @moduledoc "Slash command and callback routing behaviour."

  @callback handle_command(map(), map()) :: :ok | {:reply, String.t()} | {:error, term()}
  @callback handle_callback(map(), map()) :: :ok | {:reply, String.t()} | {:error, term()}
  @callback command_menu(:dm | :group, map()) :: [map()]
end

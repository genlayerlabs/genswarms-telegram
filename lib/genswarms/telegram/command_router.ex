defmodule Genswarms.Telegram.CommandRouter do
  @moduledoc "Slash command and callback routing behaviour."

  @type route_result ::
          :ok
          | {:reply, String.t()}
          | {:send, atom(), String.t() | map()}
          | {:send_many, [{atom(), String.t() | map()}]}
          | {:error, term()}

  @callback handle_command(map(), map()) :: route_result()
  @callback handle_callback(map(), map()) :: route_result()
  @callback command_menu(:dm | :group, map()) :: [map()]

  @optional_callbacks command_menu: 2
end

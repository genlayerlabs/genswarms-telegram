defmodule Genswarms.Telegram.CommandRouter do
  @moduledoc """
  Slash command and callback routing behaviour.

  Adapters may be configured either as `Module` or `{Module, opts}`. Tuple
  adapters can implement the callback with one extra final `opts` argument; the
  package will prefer that arity when it exists.
  """

  @type route_result ::
          :ok
          | {:reply, String.t()}
          | {:send, atom(), String.t() | map()}
          | {:send_many, [{atom(), String.t() | map()}]}
          | {:error, term()}

  @callback handle_command(map(), map()) :: route_result()
  @callback handle_command(map(), map(), map()) :: route_result()
  @callback handle_callback(map(), map()) :: route_result()
  @callback handle_callback(map(), map(), map()) :: route_result()
  @callback command_menu(:dm | :group, map()) :: [map()]
  @callback command_menu(:dm | :group, map(), map()) :: [map()]

  @optional_callbacks handle_command: 3,
                      handle_callback: 3,
                      command_menu: 2,
                      command_menu: 3
end

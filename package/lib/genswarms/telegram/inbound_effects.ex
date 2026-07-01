defmodule Genswarms.Telegram.InboundEffects do
  @moduledoc """
  Optional inbound hooks for host-specific behavior around generic Telegram ingress.
  """

  @type effect_state :: term()
  @type meta :: map()

  @callback init(map()) :: {:ok, effect_state()} | effect_state()

  @callback before_route(map(), meta(), effect_state()) ::
              {:cont, map(), effect_state()}
              | {:drop, term(), effect_state()}
              | {:send, atom(), map() | String.t(), effect_state()}
              | {:send_many, [{atom(), map() | String.t()}], effect_state()}

  @callback on_non_text(map(), meta(), effect_state()) ::
              {:ok, effect_state()}
              | {:send, atom(), map() | String.t(), effect_state()}
              | {:send_many, [{atom(), map() | String.t()}], effect_state()}

  @callback on_skipped(map(), term(), meta(), effect_state()) :: {:ok, effect_state()}
  @callback after_routed(map(), map(), meta(), effect_state()) :: {:ok, effect_state()}

  @optional_callbacks init: 1,
                      before_route: 3,
                      on_non_text: 3,
                      on_skipped: 4,
                      after_routed: 4
end

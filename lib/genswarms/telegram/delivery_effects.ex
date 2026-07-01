defmodule Genswarms.Telegram.DeliveryEffects do
  @moduledoc """
  Optional outbound delivery side effects.

  Adapters may be configured either as `Module` or `{Module, opts}`. Tuple
  adapters can implement the callback with one extra final `opts` argument; the
  package will prefer that arity when it exists.
  """

  @callback before_send(map()) :: :ok | {:error, term()}
  @callback before_send(map(), map()) :: :ok | {:error, term()}
  @callback after_send(map(), map()) :: :ok | {:error, term()}
  @callback after_send(map(), map(), map()) :: :ok | {:error, term()}
  @callback delivery_failed(map(), term()) :: :ok
  @callback delivery_failed(map(), term(), map()) :: :ok
  @callback redact_outbound(String.t(), map()) :: String.t()
  @callback redact_outbound(String.t(), map(), map()) :: String.t()
  @callback after_delivery(map(), map(), map()) :: :ok | {:error, term()}
  @callback after_delivery(map(), map(), map(), map()) :: :ok | {:error, term()}
  @callback on_unreachable(String.t(), term(), map()) :: :ok | {:error, term()}
  @callback on_unreachable(String.t(), term(), map(), map()) :: :ok | {:error, term()}

  @optional_callbacks before_send: 2,
                      after_send: 3,
                      delivery_failed: 3,
                      redact_outbound: 3,
                      after_delivery: 3,
                      after_delivery: 4,
                      on_unreachable: 3,
                      on_unreachable: 4
end

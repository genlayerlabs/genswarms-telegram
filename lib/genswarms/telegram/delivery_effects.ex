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

  # Observability hooks for paths that never produce a logical delivery, so
  # `after_delivery` cannot see them. All optional — hosts that want a display
  # feed / metrics implement them; the sender no-ops otherwise.

  @doc """
  An agent reply was suppressed by the sender's spam window (the conversation
  was answered recently and nothing is owed). `meta` carries `origin`/`from`.
  """
  @callback reply_suppressed(String.t(), map()) :: :ok
  @callback reply_suppressed(String.t(), map(), map()) :: :ok

  @doc """
  A progress/status message was posted (`:post`) or edited (`:edit`).
  """
  @callback progress_sent(String.t(), :post | :edit, map()) :: :ok
  @callback progress_sent(String.t(), :post | :edit, map(), map()) :: :ok

  @doc """
  An agent reply could not be resolved to a conversation target (the logical
  delivery never happened). `from` is the sending object/slot.
  """
  @callback reply_unresolvable(term(), map()) :: :ok
  @callback reply_unresolvable(term(), map(), map()) :: :ok

  @doc """
  Asked once at sender init: the CURRENT slot→conversation bindings, so a
  restarted sender (whose claims are process-local) re-seeds them instead of
  dropping in-flight agent replies as "no target" until the next inbound
  re-binds. Return a list of `%{slot: ..., conversation_id: ...}` maps
  (atom or string keys); anything else — or a raise — is treated as "no
  bindings". Hosts without a live session registry simply don't implement it.
  """
  @callback current_bindings() :: [map()]
  @callback current_bindings(map()) :: [map()]

  @optional_callbacks before_send: 2,
                      after_send: 3,
                      delivery_failed: 3,
                      redact_outbound: 3,
                      after_delivery: 3,
                      after_delivery: 4,
                      on_unreachable: 3,
                      on_unreachable: 4,
                      reply_suppressed: 2,
                      reply_suppressed: 3,
                      progress_sent: 3,
                      progress_sent: 4,
                      reply_unresolvable: 2,
                      reply_unresolvable: 3,
                      current_bindings: 0,
                      current_bindings: 1
end

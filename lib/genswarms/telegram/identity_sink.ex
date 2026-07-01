defmodule Genswarms.Telegram.IdentitySink do
  @moduledoc """
  Optional identity and reachability sink behaviour.

  Adapters may be configured either as `Module` or `{Module, opts}`. Tuple
  adapters can implement the callback with one extra final `opts` argument; the
  package will prefer that arity when it exists.
  """

  @callback upsert_identity(String.t(), String.t(), map()) :: :ok | {:error, term()}
  @callback upsert_identity(String.t(), String.t(), map(), map()) :: :ok | {:error, term()}
  @callback mark_reachable(String.t(), String.t(), map()) :: :ok | {:error, term()}
  @callback mark_reachable(String.t(), String.t(), map(), map()) :: :ok | {:error, term()}
  @callback mark_unreachable(String.t(), String.t(), term()) :: :ok | {:error, term()}
  @callback mark_unreachable(String.t(), String.t(), term(), map()) :: :ok | {:error, term()}

  @optional_callbacks upsert_identity: 4,
                      mark_reachable: 4,
                      mark_unreachable: 4
end

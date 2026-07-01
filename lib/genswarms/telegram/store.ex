defmodule Genswarms.Telegram.Store do
  @moduledoc """
  Bot-level Telegram transport state behaviour.

  Adapters may be configured either as `Module` or `{Module, opts}`. Tuple
  adapters can implement the callback with one extra final `opts` argument; the
  package will prefer that arity when it exists.
  """

  @callback update_seen?(String.t(), integer()) :: boolean()
  @callback update_seen?(String.t(), integer(), map()) :: boolean()
  @callback mark_update_seen(String.t(), integer()) :: :new | :duplicate | {:error, term()}
  @callback mark_update_seen(String.t(), integer(), map()) ::
              :new | :duplicate | {:error, term()}
  @callback read_offset(String.t()) :: non_neg_integer()
  @callback read_offset(String.t(), map()) :: non_neg_integer()
  @callback write_offset(String.t(), non_neg_integer()) :: :ok | {:error, term()}
  @callback write_offset(String.t(), non_neg_integer(), map()) :: :ok | {:error, term()}

  @optional_callbacks update_seen?: 3,
                      mark_update_seen: 3,
                      read_offset: 2,
                      write_offset: 3
end

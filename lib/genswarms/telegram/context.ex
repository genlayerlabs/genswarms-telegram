defmodule Genswarms.Telegram.Context do
  @moduledoc """
  Conversation context behaviour.

  Adapters may be configured either as `Module` or `{Module, opts}`. Tuple
  adapters can implement the callback with one extra final `opts` argument; the
  package will prefer that arity when it exists.
  """

  @callback init_session(String.t(), String.t(), map()) :: :ok | {:error, term()}
  @callback init_session(String.t(), String.t(), map(), map()) :: :ok | {:error, term()}
  @callback before_turn(String.t(), String.t(), String.t(), map()) :: String.t()
  @callback before_turn(String.t(), String.t(), String.t(), map(), map()) :: String.t()
  @callback after_turn(String.t(), String.t(), :user | :assistant, String.t(), map()) ::
              :ok | {:error, term()}
  @callback after_turn(String.t(), String.t(), :user | :assistant, String.t(), map(), map()) ::
              :ok | {:error, term()}

  @optional_callbacks init_session: 4,
                      before_turn: 5,
                      after_turn: 6
end

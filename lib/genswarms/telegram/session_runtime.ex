defmodule Genswarms.Telegram.SessionRuntime do
  @moduledoc """
  Per-conversation session runtime behaviour.

  Adapters may be configured either as `Module` or `{Module, opts}`. Tuple
  adapters can implement callbacks with one extra final `opts` argument; the
  package will prefer that arity when it exists. Prefer `ensure_session/4` for
  tuple adapters that need both the Telegram event and adapter opts.
  """

  @type session :: %{
          required(:slot) => atom(),
          required(:conversation_id) => String.t(),
          optional(:workspace) => String.t(),
          optional(:env) => map(),
          optional(:binding_sinks) => [atom()]
        }

  @type admission_result :: {:ok, session()} | {:skip, term()} | {:error, term()}

  @callback ensure_session(String.t(), map()) :: admission_result()
  @callback ensure_session(String.t(), map(), map()) :: admission_result()
  @callback ensure_session(String.t(), map(), map(), map()) :: admission_result()
  @callback bind_session(session(), String.t(), [atom()], map()) :: :ok | {:error, term()}
  @callback bind_session(session(), String.t(), [atom()], map(), map()) :: :ok | {:error, term()}
  @callback deliver_to_session(session(), String.t(), map()) :: :ok | {:error, term()}
  @callback deliver_to_session(session(), String.t(), map(), map()) :: :ok | {:error, term()}
  @callback deliver_turn(session(), map(), map()) :: :ok | {:error, term()}
  @callback deliver_turn(session(), map(), map(), map()) :: :ok | {:error, term()}
  @callback teardown_session(session(), term(), map()) :: :ok | {:error, term()}
  @callback teardown_session(session(), term(), map(), map()) :: :ok | {:error, term()}

  @optional_callbacks ensure_session: 2,
                      ensure_session: 3,
                      ensure_session: 4,
                      bind_session: 4,
                      bind_session: 5,
                      deliver_to_session: 3,
                      deliver_to_session: 4,
                      deliver_turn: 3,
                      deliver_turn: 4,
                      teardown_session: 3,
                      teardown_session: 4
end

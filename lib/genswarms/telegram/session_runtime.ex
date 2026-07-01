defmodule Genswarms.Telegram.SessionRuntime do
  @moduledoc "Per-conversation session runtime behaviour."

  @type session :: %{
          required(:slot) => atom(),
          required(:conversation_id) => String.t(),
          optional(:workspace) => String.t(),
          optional(:env) => map(),
          optional(:binding_sinks) => [atom()]
        }

  @callback ensure_session(String.t(), map()) :: {:ok, session()} | {:error, term()}
  @callback bind_session(session(), String.t(), [atom()], map()) :: :ok | {:error, term()}
  @callback deliver_to_session(session(), String.t(), map()) :: :ok | {:error, term()}
  @callback teardown_session(session(), term(), map()) :: :ok | {:error, term()}

  @optional_callbacks bind_session: 4
end

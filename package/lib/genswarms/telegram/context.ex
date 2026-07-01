defmodule Genswarms.Telegram.Context do
  @moduledoc "Conversation context behaviour."

  @callback init_session(String.t(), String.t(), map()) :: :ok | {:error, term()}
  @callback before_turn(String.t(), String.t(), String.t(), map()) :: String.t()
  @callback after_turn(String.t(), String.t(), :user | :assistant, String.t(), map()) ::
              :ok | {:error, term()}
end

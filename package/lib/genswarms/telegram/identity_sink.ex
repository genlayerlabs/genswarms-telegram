defmodule Genswarms.Telegram.IdentitySink do
  @moduledoc "Optional identity and reachability sink behaviour."

  @callback upsert_identity(String.t(), String.t(), map()) :: :ok | {:error, term()}
  @callback mark_reachable(String.t(), String.t(), map()) :: :ok | {:error, term()}
  @callback mark_unreachable(String.t(), String.t(), term()) :: :ok | {:error, term()}
end

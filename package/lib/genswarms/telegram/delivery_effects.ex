defmodule Genswarms.Telegram.DeliveryEffects do
  @moduledoc "Optional outbound delivery side effects."

  @callback before_send(map()) :: :ok | {:error, term()}
  @callback after_send(map(), map()) :: :ok | {:error, term()}
  @callback delivery_failed(map(), term()) :: :ok
  @callback redact_outbound(String.t(), map()) :: String.t()
end

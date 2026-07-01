defmodule Genswarms.Telegram.DeliveryEffects.Noop do
  @behaviour Genswarms.Telegram.DeliveryEffects

  @impl true
  def before_send(_payload), do: :ok

  @impl true
  def after_send(_payload, _result), do: :ok

  @impl true
  def delivery_failed(_payload, _reason), do: :ok

  @impl true
  def redact_outbound(text, _meta), do: text
end

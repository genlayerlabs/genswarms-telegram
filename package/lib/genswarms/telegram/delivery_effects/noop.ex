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

  @impl true
  def after_delivery(_delivery, _outcome, _meta), do: :ok

  @impl true
  def on_unreachable(_conversation_id, _reason, _meta), do: :ok
end

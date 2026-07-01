defmodule Genswarms.Telegram.InboundEffects.Noop do
  @moduledoc "No-op inbound effects adapter."

  @behaviour Genswarms.Telegram.InboundEffects

  @impl true
  def init(_opts), do: {:ok, %{}}

  @impl true
  def before_route(event, _meta, state), do: {:cont, event, state}

  @impl true
  def on_non_text(_event, _meta, state), do: {:ok, state}

  @impl true
  def on_skipped(_event, _reason, _meta, state), do: {:ok, state}

  @impl true
  def after_routed(_event, _route, _meta, state), do: {:ok, state}
end

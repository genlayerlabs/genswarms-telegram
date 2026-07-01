defmodule Genswarms.Telegram.IdentitySink.Noop do
  @behaviour Genswarms.Telegram.IdentitySink

  @impl true
  def upsert_identity(_bot_ref, _conversation_id, _identity), do: :ok

  @impl true
  def mark_reachable(_bot_ref, _conversation_id, _event), do: :ok

  @impl true
  def mark_unreachable(_bot_ref, _conversation_id, _reason), do: :ok
end

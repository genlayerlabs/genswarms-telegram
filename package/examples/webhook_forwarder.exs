defmodule GenswarmsTelegramWebhookForwarderExample do
  @moduledoc """
  Minimal shape for hosts that already own an HTTP server.

  Pass request body and headers through
  `Genswarms.Telegram.Webhook.decode_update/3`, then send that update to
  `Genswarms.Telegram.Objects.Ingress` with
  `{"action":"inject_update","update": update}`.
  """
end

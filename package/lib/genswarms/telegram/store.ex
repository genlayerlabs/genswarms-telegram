defmodule Genswarms.Telegram.Store do
  @moduledoc "Bot-level Telegram transport state behaviour."

  @callback update_seen?(String.t(), integer()) :: boolean()
  @callback mark_update_seen(String.t(), integer()) :: :new | :duplicate | {:error, term()}
  @callback read_offset(String.t()) :: non_neg_integer()
  @callback write_offset(String.t(), non_neg_integer()) :: :ok | {:error, term()}
end

defmodule Genswarms.Telegram do
  @moduledoc """
  Reusable Telegram transport for GenSwarms.

  This package intentionally contains Telegram transport, local defaults, and
  GenSwarms object handlers only. Product policy, persona, private data, quota
  logic, and domain commands belong in the consuming swarm.
  """

  @version "0.2.0"

  def version, do: @version
end

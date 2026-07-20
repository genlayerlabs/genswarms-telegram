defmodule GenswarmsTelegramEditor do
  @moduledoc """
  Asset locator and schema attestation for the Telegram rich-message preview.

  The renderer itself is `priv/preview/telegram_preview.mjs` (browser ESM,
  no dependencies). Hosts serve `asset_dir/0` read-only and compare
  `supported_schema/0` with `Genswarms.Telegram.Card.schema_info().version`
  at boot — mismatched pins must fail loud, not render lies.
  """

  @doc "Card schema version this editor's preview understands."
  def supported_schema do
    :genswarms_telegram_editor
    |> :code.priv_dir()
    |> Path.join("tags.json")
    |> File.read!()
    |> Jason.decode!()
    |> Map.fetch!("schema_version")
  end

  @doc "Absolute path of the preview assets (mjs/css/html) for host asset routes."
  def asset_dir do
    :genswarms_telegram_editor
    |> :code.priv_dir()
    |> Path.join("preview")
  end
end

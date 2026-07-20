defmodule GenswarmsTelegramEditorTest do
  use ExUnit.Case, async: true

  test "supported_schema matches tags.json" do
    tags =
      :genswarms_telegram_editor
      |> :code.priv_dir()
      |> Path.join("tags.json")
      |> File.read!()
      |> Jason.decode!()

    assert GenswarmsTelegramEditor.supported_schema() == tags["schema_version"]
    assert tags["schema_version"] == "1"
    assert tags["bot_api_version"] == "10.1"
  end

  test "asset_dir exists and contains the tags vocabulary" do
    dir = GenswarmsTelegramEditor.asset_dir()
    assert File.exists?(Path.join(dir, "tags.mjs"))
    assert String.ends_with?(dir, "priv/preview")
  end
end

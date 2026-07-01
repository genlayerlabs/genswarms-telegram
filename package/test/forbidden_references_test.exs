defmodule Genswarms.Telegram.ForbiddenReferencesTest do
  use ExUnit.Case, async: true

  test "package code does not leak Wingston assumptions" do
    root = Path.expand("..", __DIR__)

    files =
      ["lib", "priv", "examples"]
      |> Enum.map(&Path.join(root, &1))
      |> Enum.filter(&File.exists?/1)
      |> Enum.flat_map(fn dir -> Path.wildcard(Path.join(dir, "**/*")) end)
      |> Enum.filter(&File.regular?/1)

    forbidden = [
      "Wingston",
      "WINGSTON_",
      "rally_data",
      "/tmp/szc-workspace/wingston",
      "wingston_agent"
    ]

    offenders =
      for file <- files,
          body = File.read!(file),
          term <- forbidden,
          String.contains?(body, term),
          do: {Path.relative_to(file, root), term}

    assert offenders == []
  end
end

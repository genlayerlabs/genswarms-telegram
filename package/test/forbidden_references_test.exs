defmodule Genswarms.Telegram.ForbiddenReferencesTest do
  use ExUnit.Case, async: true

  test "package code does not leak downstream app assumptions" do
    root = Path.expand("..", __DIR__)

    files =
      packaged_paths(root)
      |> Enum.filter(&File.regular?/1)

    downstream_name = string([87, 105, 110, 103, 115, 116, 111, 110])
    downstream_lower = String.downcase(downstream_name)
    event_prefix = string([114, 97, 108, 108, 121])
    shell_agent_name = string([83, 117, 98, 90, 101, 114, 111, 67, 108, 97, 119])
    shell_prefix = string([83, 117, 98, 90, 101, 114, 111])

    forbidden = [
      downstream_name,
      String.upcase(downstream_name) <> "_",
      String.capitalize(event_prefix),
      String.upcase(event_prefix) <> "_",
      event_prefix <> "_data",
      shell_agent_name,
      shell_prefix,
      Path.join(["/tmp", "szc-workspace", downstream_lower]),
      downstream_lower <> "_agent"
    ]

    offenders =
      for file <- files,
          body = File.read!(file),
          term <- forbidden,
          String.contains?(body, term),
          do: {Path.relative_to(file, root), term}

    assert offenders == []
  end

  defp packaged_paths(root) do
    directories =
      ["lib", "priv", "examples"]
      |> Enum.map(&Path.join(root, &1))
      |> Enum.filter(&File.exists?/1)
      |> Enum.flat_map(fn dir -> Path.wildcard(Path.join(dir, "**/*")) end)

    files =
      ~w(mix.exs README.md LICENSE CHANGELOG.md swarmidx.json)
      |> Enum.map(&Path.join(root, &1))
      |> Enum.filter(&File.exists?/1)

    directories ++ files
  end

  defp string(codepoints), do: List.to_string(codepoints)
end

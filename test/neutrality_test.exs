defmodule Genswarms.Telegram.NeutralityTest do
  use ExUnit.Case, async: true

  @root Path.expand("..", __DIR__)
  @scan_patterns [
    "lib/**/*",
    "priv/**/*",
    "examples/**/*",
    "docs/**/*",
    "README.md",
    "CHANGELOG.md"
  ]

  test "shipped package files do not contain product-specific fixture terms" do
    regex = forbidden_regex()

    failures =
      @scan_patterns
      |> Enum.flat_map(fn pattern -> Path.wildcard(Path.join(@root, pattern)) end)
      |> Enum.uniq()
      |> Enum.reject(&File.dir?/1)
      |> Enum.flat_map(fn path ->
        rel_path = Path.relative_to(path, @root)

        path
        |> File.stream!([], :line)
        |> Stream.with_index(1)
        |> Enum.flat_map(fn {line, line_number} ->
          if Regex.match?(regex, line) do
            ["#{rel_path}:#{line_number}: #{String.trim_trailing(line)}"]
          else
            []
          end
        end)
      end)

    assert failures == [],
           "Product-specific fixture terms found in shipped files:\n#{Enum.join(failures, "\n")}"
  end

  defp forbidden_regex do
    # "Subzero Claw" — the stack component's proper name in the /about text —
    # is deliberately permitted; bare "subzero" / "subzero-swarm" stays
    # forbidden (that's the accidental-internals leak this gate exists for).
    terms = ["wing" <> "ston", "ra" <> "lly", "sub" <> "zero" <> "(?!\\s+claw)"]
    Regex.compile!("\\b(" <> Enum.join(terms, "|") <> ")\\b", "i")
  end
end

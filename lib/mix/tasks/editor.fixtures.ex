defmodule Mix.Tasks.Editor.Fixtures do
  @shortdoc "Render Card.examples() to editor/test/fixtures/examples.json"
  @moduledoc """
  Bridges Elixir card rendering into the editor's node tests: every example
  card is rendered with the real Card.to_rich_message/2 and dumped as JSON
  {name, kind, action, draft, html}. Regenerate whenever examples or the
  card renderer change; the editor round-trip test consumes this file.
  """
  use Mix.Task

  alias Genswarms.Telegram.Card

  @out "editor/test/fixtures/examples.json"

  @impl true
  def run(_argv) do
    fixtures =
      for example <- Card.examples(), card = example[:card], card != nil do
        draft = example[:action] == "stream_card"
        {:ok, rich} = Card.to_rich_message(card, %{draft?: draft})

        %{
          name: example[:name],
          kind: example[:kind],
          action: example[:action],
          draft: draft,
          html: rich.html
        }
      end

    File.write!(@out, Jason.encode!(fixtures, pretty: true) <> "\n")
    Mix.shell().info("wrote #{@out} (#{length(fixtures)} fixtures)")
  end
end

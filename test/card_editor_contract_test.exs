defmodule Genswarms.Telegram.CardEditorContractTest do
  use ExUnit.Case, async: true

  alias Genswarms.Telegram.Card

  @tags "editor/priv/tags.json" |> File.read!() |> Jason.decode!()

  test "contract schema version matches the card schema" do
    assert @tags["schema_version"] == Card.schema_info().version
  end

  test "every tag emitted by examples and the all-kinds card is in tags.json" do
    known =
      MapSet.new(@tags["block_elements"] ++ @tags["inline_elements"] ++ @tags["void_elements"])

    cards =
      [all_kinds_card() | Enum.map(Card.examples(), & &1[:card])]
      |> Enum.reject(&is_nil/1)

    for card <- cards do
      opts = if has_thinking?(card), do: %{draft?: true}, else: %{}
      assert {:ok, %{html: html}} = Card.to_rich_message(card, opts)

      emitted =
        Regex.scan(~r/<\/?([a-zA-Z][a-zA-Z0-9-]*)/, html)
        |> Enum.map(fn [_, name] -> String.downcase(name) end)
        |> MapSet.new()

      unknown = MapSet.difference(emitted, known)

      assert MapSet.size(unknown) == 0,
             "card emits tags missing from editor contract: #{inspect(MapSet.to_list(unknown))}"
    end
  end

  defp has_thinking?(card) do
    (card["blocks"] || [])
    |> Enum.any?(&(&1["kind"] == "thinking"))
  end

  defp all_kinds_card do
    span = fn kind, extra -> Map.merge(%{"kind" => kind, "text" => kind}, extra) end

    inline_sampler = [
      "plain ",
      span.("bold", %{}),
      span.("italic", %{}),
      span.("underline", %{}),
      span.("strikethrough", %{}),
      span.("spoiler", %{}),
      span.("mark", %{}),
      span.("code", %{}),
      span.("sub", %{}),
      span.("sup", %{}),
      span.("link", %{"url" => "https://example.com/"}),
      span.("custom_emoji", %{"emoji_id" => "5368324170671202286"}),
      span.("date_time", %{"unix" => 1_800_000_000}),
      span.("mention", %{"username" => "example"}),
      span.("text_mention", %{"user_id" => 123}),
      %{"kind" => "mathematical_expression", "expression" => "e = mc^2"},
      span.("email_address", %{"email_address" => "a@example.com"}),
      span.("phone_number", %{"phone_number" => "+34600000000"}),
      span.("bank_card_number", %{"bank_card_number" => "4111111111111111"}),
      span.("hashtag", %{}),
      span.("cashtag", %{}),
      span.("bot_command", %{}),
      %{"kind" => "anchor", "name" => "top"},
      span.("anchor_link", %{"anchor_name" => "top"}),
      span.("reference_link", %{"name" => "ref1"}),
      span.("reference", %{"name" => "ref-inline"})
    ]

    %{
      "title" => "All kinds",
      "footer" => "footer text",
      "blocks" => [
        %{"kind" => "heading", "level" => 2, "text" => "Heading"},
        %{"kind" => "paragraph", "text" => inline_sampler},
        %{"kind" => "list", "ordered" => true, "start" => 3, "items" => ["a", "b"]},
        %{
          "kind" => "checklist",
          "items" => [%{"text" => "done", "checked" => true}, %{"text" => "todo"}]
        },
        %{
          "kind" => "table",
          "bordered" => true,
          "striped" => true,
          "caption" => "cap",
          "headers" => ["H"],
          "rows" => [["c"]]
        },
        %{
          "kind" => "details",
          "open" => true,
          "summary" => "More",
          "blocks" => [%{"kind" => "paragraph", "text" => "inner"}]
        },
        %{"kind" => "quote", "text" => "q", "credit" => "who"},
        %{"kind" => "blockquote", "expandable" => true, "text" => "long quote"},
        %{"kind" => "pullquote", "text" => "pull", "credit" => "who"},
        %{"kind" => "code", "language" => "elixir", "text" => "IO.puts(:ok)"},
        %{"kind" => "pre", "text" => "preformatted"},
        %{"kind" => "footer", "text" => "block footer"},
        %{"kind" => "divider"},
        %{"kind" => "mathematical_expression", "expression" => "\\sum_{i=0}^n i"},
        %{"kind" => "anchor", "name" => "sec"},
        %{
          "kind" => "media",
          "media_type" => "photo",
          "url" => "https://example.com/a.jpg",
          "caption" => "photo",
          "spoiler" => true
        },
        %{"kind" => "media", "media_type" => "video", "url" => "https://example.com/v.mp4"},
        %{"kind" => "media", "media_type" => "audio", "url" => "https://example.com/a.mp3"},
        %{"kind" => "media", "media_type" => "animation", "url" => "https://example.com/a.mp4"},
        %{"kind" => "media", "media_type" => "voice_note", "url" => "https://example.com/v.ogg"},
        %{
          "kind" => "collage",
          "items" => [
            %{"media_type" => "photo", "url" => "https://example.com/1.jpg"},
            %{"media_type" => "photo", "url" => "https://example.com/2.jpg"}
          ]
        },
        %{
          "kind" => "slideshow",
          "blocks" => [
            %{"kind" => "media", "media_type" => "photo", "url" => "https://example.com/3.jpg"},
            %{"kind" => "media", "media_type" => "photo", "url" => "https://example.com/4.jpg"}
          ]
        },
        %{"kind" => "references", "items" => [%{"name" => "ref1", "text" => "Reference one"}]},
        %{"kind" => "time", "unix" => 1_800_000_000, "format" => "relative", "text" => "soon"},
        %{"kind" => "map", "latitude" => 41.3874, "longitude" => 2.1686, "zoom" => 12},
        %{"kind" => "thinking", "text" => "draft only"}
      ]
    }
  end
end

defmodule Genswarms.Telegram.CardContractTest do
  use ExUnit.Case

  alias Genswarms.Telegram.Card

  test "card validation fails closed on malformed blocks and unsafe inline entities" do
    assert {:error, [%{path: "card", reason: "card must be an object"}]} = Card.validate("bad")

    assert {:error, [%{path: "card.title"}]} =
             Card.validate(%{"title" => 123, "blocks" => []})

    assert {:error, [%{path: "card.blocks", reason: "blocks must be a list"}]} =
             Card.validate(%{"blocks" => "bad"})

    assert {:error, [%{path: "card.blocks[0]", reason: "block must be an object"}]} =
             Card.validate(%{"blocks" => ["bad"]})

    assert {:error, [%{path: "card.blocks[0].kind", reason: "block kind is required"}]} =
             Card.validate(%{"blocks" => [%{}]})

    assert {:error, [%{path: "card.blocks[0].kind"}]} =
             Card.validate(%{"blocks" => [%{"kind" => "unknown"}]})

    assert {:error, [%{path: "card.blocks[0].media_type"}]} =
             Card.validate(%{
               "blocks" => [
                 %{"kind" => "media", "media_type" => "pdf", "url" => "https://example.com/a"}
               ]
             })

    assert {:error, [%{path: "card.blocks[0].url"}]} =
             Card.validate(%{
               "blocks" => [
                 %{"kind" => "media", "media_type" => "photo", "url" => "ftp://example.com/a"}
               ]
             })

    assert {:error, [%{path: "card.blocks[0].longitude"}]} =
             Card.validate(%{"blocks" => [%{"kind" => "map", "latitude" => 1.0}]})

    assert {:error, [%{path: "card.blocks[0].latitude"}]} =
             Card.validate(%{
               "blocks" => [%{"kind" => "map", "latitude" => "north", "longitude" => 2.0}]
             })

    assert {:error, [%{path: "card.blocks[0].rows[0]"}]} =
             Card.validate(%{
               "blocks" => [%{"kind" => "table", "headers" => ["a"], "rows" => ["bad"]}]
             })

    invalid_inline_cases = [
      {%{"kind" => "custom_emoji", "text" => "x"}, "emoji_id"},
      {%{"kind" => "date_time", "text" => "now"}, "unix"},
      {%{"kind" => "text_mention", "text" => "Ada"}, "user_id"},
      {%{"kind" => "mention", "text" => "Ada"}, "user_id"},
      {%{"kind" => "math", "text" => ""}, "expression"},
      {%{"kind" => "email", "email" => "not-email"}, "email_address"},
      {%{"kind" => "phone", "text" => "Call"}, "phone_number"},
      {%{"kind" => "bank_card", "text" => "Card"}, "bank_card_number"},
      {%{"kind" => "hashtag", "text" => ""}, "hashtag"},
      {%{"kind" => "cashtag", "text" => ""}, "cashtag"},
      {%{"kind" => "bot_command", "text" => ""}, "bot_command"},
      {%{"kind" => "anchor", "text" => ""}, "name"},
      {%{"kind" => "anchor_link", "text" => "Jump"}, "anchor_name"},
      {%{"kind" => "reference", "text" => "Ref"}, "reference_name"},
      {%{"kind" => "alien", "text" => "x"}, "kind"}
    ]

    for {inline, field} <- invalid_inline_cases do
      assert {:error, [%{path: path}]} =
               Card.validate(%{"blocks" => [%{"kind" => "paragraph", "text" => [inline]}]})

      assert path =~ field
    end
  end

  test "card validation errors teach agents how to repair malformed cards" do
    broken_cards = [
      {Card.validate(%{"blocks" => []}, %{require_title?: true}), "missing required title"},
      {Card.validate(%{"blocks" => [%{"kind" => "paragraph", "text" => ""}]}),
       "empty paragraph text"},
      {Card.validate(%{"blocks" => [%{"kind" => "unknown"}]}), "bad block kind"},
      {Card.validate(%{
         "blocks" => [%{"kind" => "paragraph", "text" => "Choose"}],
         "buttons" => [
           [%{"text" => "Run", "callback_data" => String.duplicate("x", 65)}]
         ]
       }), "oversized callback data"},
      {Card.validate(%{
         "blocks" => [
           %{"kind" => "media", "media_type" => "photo", "url" => "file:///tmp/a.jpg"}
         ]
       }), "non-http media URL"},
      {Card.validate(%{"blocks" => [%{"kind" => "thinking", "text" => "Working"}]}),
       "thinking block in final card"}
    ]

    for {{:error, errors}, label} <- broken_cards do
      assert errors != [], label

      assert Enum.all?(errors, fn error ->
               is_binary(error[:path]) and error[:path] != "" and
                 is_binary(error[:hint]) and error[:hint] != ""
             end),
             label
    end
  end

  test "card rendering covers rich block types and inline entities without leaking unsafe text" do
    card = %{
      "title" => "Ops <Status>",
      "is_rtl" => "true",
      "skip_entity_detection" => 1,
      "blocks" => [
        %{"kind" => "heading", "level" => "2", "text" => "Summary"},
        %{
          "kind" => "paragraph",
          "text" => [
            %{"kind" => "bold", "text" => "bold"},
            " ",
            %{"kind" => "italic", "text" => "italic"},
            " ",
            %{"kind" => "underline", "text" => "under"},
            " ",
            %{"kind" => "strikethrough", "text" => "gone"},
            " ",
            %{"kind" => "spoiler", "text" => "secret"},
            " ",
            %{"kind" => "mark", "text" => "mark"},
            " ",
            %{"kind" => "code", "text" => "x < y"},
            " ",
            %{"kind" => "sub", "text" => "i"},
            %{"kind" => "sup", "text" => "2"},
            " ",
            %{"kind" => "link", "text" => "Open", "url" => "https://example.com"},
            " ",
            %{"kind" => "custom_emoji", "emoji_id" => "emoji-1", "text" => "CE"},
            " ",
            %{
              "kind" => "date_time",
              "unix" => 1_800_000_000,
              "format" => "date",
              "text" => "date"
            },
            " ",
            %{"kind" => "mention", "username" => "ada", "text" => "Ada"},
            " ",
            %{"kind" => "mention", "username" => "wingston"},
            " ",
            %{"kind" => "text_mention", "user_id" => 123, "text" => "User"},
            " ",
            %{"kind" => "math", "expression" => "x^2"},
            " ",
            %{"kind" => "email", "email" => "team@example.com"},
            " ",
            %{"kind" => "phone", "phone" => "+12025550123"},
            " ",
            %{"kind" => "bank_card", "bank_card" => "4242"},
            " ",
            %{"kind" => "hashtag", "hashtag" => "ops"},
            " ",
            %{"kind" => "cashtag", "cashtag" => "GL"},
            " ",
            %{"kind" => "bot_command", "command" => "start"},
            " ",
            %{"kind" => "anchor", "name" => "top"},
            %{"kind" => "anchor_link", "anchor_name" => "top", "text" => "Top"},
            " ",
            %{"kind" => "reference", "reference_name" => "r1", "text" => "Ref"},
            " ",
            %{"kind" => "reference_link", "reference_name" => "r1", "text" => "Go"}
          ]
        },
        %{
          "kind" => "list",
          "ordered" => true,
          "start" => 2,
          "items" => [%{"text" => "two", "value" => 2}]
        },
        %{"kind" => "checklist", "items" => [%{"text" => "done", "checked" => true}]},
        %{
          "kind" => "table",
          "bordered" => true,
          "striped" => true,
          "caption" => "Numbers",
          "headers" => ["a"],
          "rows" => [[1]]
        },
        %{
          "kind" => "details",
          "open" => true,
          "summary" => "More",
          "blocks" => [%{"kind" => "paragraph", "text" => "Inside"}]
        },
        %{"kind" => "quote", "expandable" => true, "text" => "Quote", "cite" => "Source"},
        %{
          "kind" => "blockquote",
          "blocks" => [%{"kind" => "paragraph", "text" => "Nested"}],
          "text" => "Block",
          "credit" => "Credit"
        },
        %{"kind" => "pullquote", "text" => "Pull", "credit" => "Author"},
        %{"kind" => "pre", "language" => "elixir", "text" => "IO.puts(\"hi\")"},
        %{"kind" => "math", "expression" => "a+b"},
        %{"kind" => "anchor", "name" => "section"},
        %{"kind" => "footer", "text" => "Footer"},
        %{"kind" => "divider"},
        %{
          "kind" => "media",
          "media_type" => "audio",
          "url" => "https://example.com/a.mp3",
          "spoiler" => true,
          "caption" => "Audio"
        },
        %{
          "kind" => "collage",
          "caption" => "Gallery",
          "items" => [
            %{"kind" => "media", "media_type" => "photo", "url" => "https://example.com/a.jpg"},
            %{
              "kind" => "media",
              "media_type" => "voice_note",
              "url" => "https://example.com/v.ogg"
            }
          ]
        },
        %{
          "kind" => "slideshow",
          "caption" => "Slides",
          "slides" => [
            %{
              "kind" => "media",
              "media_type" => "animation",
              "url" => "https://example.com/a.mp4"
            }
          ]
        },
        %{"kind" => "references", "items" => [%{"id" => "r1", "text" => "Reference"}]},
        %{
          "kind" => "time",
          "unix_time" => 1_800_000_000,
          "format" => "datetime",
          "text" => "When"
        },
        %{
          "kind" => "map",
          "latitude" => "41.3",
          "longitude" => "2.1",
          "zoom" => 10,
          "caption" => "HQ"
        },
        %{"kind" => "thinking", "text" => "Working"}
      ],
      "footer" => [%{"kind" => "url", "text" => "Docs", "href" => "https://example.com/docs"}]
    }

    assert {:ok, %{html: html, is_rtl: true, skip_entity_detection: true}} =
             Card.to_rich_message(card, %{draft?: true})

    assert html =~ "<h3>Ops &lt;Status&gt;</h3>"
    assert html =~ "<h2>Summary</h2>"
    assert html =~ "<b>bold</b>"
    assert html =~ "<i>italic</i>"
    assert html =~ "<u>under</u>"
    assert html =~ "<s>gone</s>"
    assert html =~ "<tg-spoiler>secret</tg-spoiler>"
    assert html =~ "<mark>mark</mark>"
    assert html =~ "<code>x &lt; y</code>"
    assert html =~ "<sub>i</sub><sup>2</sup>"
    assert html =~ ~s(<a href="https://example.com">Open</a>)
    assert html =~ ~s(<tg-emoji emoji-id="emoji-1">CE</tg-emoji>)
    assert html =~ ~s(<tg-time unix="1800000000" format="date">date</tg-time>)
    assert html =~ "Ada @wingston"
    assert html =~ ~s(<a href="tg://user?id=123">User</a>)
    assert html =~ "<tg-math>x^2</tg-math>"
    assert html =~ ~s(<a href="mailto:team@example.com">team@example.com</a>)
    assert html =~ ~s(<a href="tel:+12025550123">+12025550123</a>)
    assert html =~ "4242"
    assert html =~ "#ops"
    assert html =~ "$GL"
    assert html =~ "/start"
    assert html =~ ~s(<a name="top"></a>)
    assert html =~ ~s(<a href="#top">Top</a>)
    assert html =~ ~s(<tg-reference name="r1">Ref</tg-reference>)
    assert html =~ ~s(<a href="#r1">Go</a>)
    assert html =~ ~s(<ol start="2">)
    assert html =~ ~s(<li value="2">two</li>)
    assert html =~ ~s(<input type="checkbox" checked/>done)
    assert html =~ "<table bordered striped>"
    assert html =~ "<details open><summary>More</summary>"
    assert html =~ "<blockquote expandable>Quote<cite>Source</cite></blockquote>"
    assert html =~ "<aside>Pull<cite>Author</cite></aside>"
    assert html =~ "<pre><code class=\"language-elixir\">IO.puts(&quot;hi&quot;)</code></pre>"
    assert html =~ "<tg-math-block>a+b</tg-math-block>"
    assert html =~ "<hr/>"
    assert html =~ ~s(<audio tg-spoiler src="https://example.com/a.mp3"></audio>)
    assert html =~ "<tg-collage>"
    assert html =~ ~s(<audio src="https://example.com/v.ogg"></audio>)
    assert html =~ "<tg-slideshow>"
    assert html =~ ~s(<video src="https://example.com/a.mp4"></video>)
    assert html =~ ~s(<tg-reference name="r1">Reference</tg-reference>)
    assert html =~ ~s(<tg-time unix="1800000000" format="datetime">When</tg-time>)
    assert html =~ ~s(<tg-map lat="41.3" long="2.1" zoom="10"/>)
    assert html =~ "<tg-thinking>Working</tg-thinking>"
    assert html =~ ~s(<footer><a href="https://example.com/docs">Docs</a></footer>)
  end

  test "card examples remain valid agent-facing payloads" do
    assert length(Card.examples()) > 0

    for %{} = example <- Card.examples() do
      case {Map.get(example, :action), Map.get(example, :card) || Map.get(example, "card")} do
        {action, card} when is_map(card) ->
          opts = if action in ["stream_card"], do: %{draft?: true}, else: %{}
          assert :ok = Card.validate(card, opts)
          assert {:ok, _rich_message} = Card.to_rich_message(card, opts)

        {"reply", nil} ->
          :ok
      end
    end
  end

  test "card examples are product neutral" do
    examples = inspect(Card.examples())

    for disallowed <- [
          "Wing" <> "ston",
          "wing" <> "ston",
          "Ra" <> "lly",
          "ra" <> "lly",
          "Sub" <> "Zero"
        ] do
      refute examples =~ disallowed
    end
  end

  test "agent guide is flat and product neutral" do
    guide_dir = Path.expand("../priv/agent-guide", __DIR__)

    assert guide_dir
           |> File.ls!()
           |> Enum.sort() == [
             "INDEX.md",
             "blocks.md",
             "cards.md",
             "media.md",
             "quotes.md",
             "spans.md",
             "streaming.md"
           ]

    guide_text =
      guide_dir
      |> File.ls!()
      |> Enum.map(fn file ->
        path = Path.join(guide_dir, file)
        refute File.dir?(path)
        File.read!(path)
      end)
      |> Enum.join("\n")

    for disallowed <- [
          "Wing" <> "ston",
          "wing" <> "ston",
          "Ra" <> "lly",
          "ra" <> "lly",
          "Sub" <> "Zero"
        ] do
      refute guide_text =~ disallowed
    end
  end
end

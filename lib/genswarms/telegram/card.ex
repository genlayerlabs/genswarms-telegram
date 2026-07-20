defmodule Genswarms.Telegram.Card do
  @moduledoc """
  Structured, agent-facing Telegram card schema.

  The card schema is intentionally narrower than Telegram HTML. Agents should
  prefer this module over raw HTML: it validates URLs and block shapes, escapes
  dynamic text, and renders a Telegram `InputRichMessage`.
  """

  alias Genswarms.Telegram.{Capabilities, RichMessage}

  @schema_version "1"
  @block_kinds ~w(heading paragraph list checklist table details quote blockquote pullquote code pre footer divider mathematical_expression anchor media collage slideshow references time map thinking)
  @inline_kinds ~w(bold italic underline strikethrough spoiler mark marked code sub subscript sup superscript link url custom_emoji date_time mention text_mention mathematical_expression math email_address email phone_number phone bank_card_number bank_card hashtag cashtag bot_command anchor anchor_link reference reference_link)
  @media_kinds ~w(photo video animation audio voice_note)
  @button_callback_data_max_bytes 64
  @limits %{
    text_utf16_units: 4_096,
    caption_utf16_units: 1_024,
    media_group_items: %{min: 2, max: 10},
    inline_query_results: %{min: 1, max: 50},
    callback_text_chars: %{min: 0, max: 200},
    callback_data_bytes: %{min: 1, max: @button_callback_data_max_bytes}
  }

  @doc "Return the package-level Telegram card capabilities."
  def capabilities, do: Capabilities.sender()

  @doc "Return the structured-card schema version, supported kinds, and package limits."
  def schema_info do
    %{
      version: @schema_version,
      blocks: @block_kinds,
      inline: @inline_kinds,
      media: @media_kinds,
      limits: @limits
    }
  end

  @doc "Machine-readable examples for agents."
  def examples do
    [
      %{
        name: "block_paragraph",
        kind: "card_block",
        action: "send_card",
        card: %{
          "blocks" => [%{"kind" => "paragraph", "text" => "Plain text can stand alone."}]
        }
      },
      %{
        name: "block_heading",
        kind: "card_block",
        action: "send_card",
        card: %{
          "blocks" => [%{"kind" => "heading", "level" => 2, "text" => "Status"}]
        }
      },
      %{
        name: "block_list",
        kind: "card_block",
        action: "send_card",
        card: %{
          "blocks" => [
            %{"kind" => "list", "ordered" => true, "items" => ["First step", "Second step"]}
          ]
        }
      },
      %{
        name: "block_checklist",
        kind: "card_block",
        action: "send_card",
        card: %{
          "blocks" => [
            %{
              "kind" => "checklist",
              "items" => [
                %{"text" => "Draft answer", "checked" => true},
                %{"text" => "Send final", "checked" => false}
              ]
            }
          ]
        }
      },
      %{
        name: "block_table",
        kind: "card_block",
        action: "send_card",
        card: %{
          "blocks" => [
            %{"kind" => "table", "headers" => ["Item", "State"], "rows" => [["Plan", "Ready"]]}
          ]
        }
      },
      %{
        name: "block_quote",
        kind: "card_block",
        action: "send_card",
        card: %{
          "blocks" => [%{"kind" => "quote", "text" => "Use the smallest clear answer."}]
        }
      },
      %{
        name: "block_code",
        kind: "card_block",
        action: "send_card",
        card: %{
          "blocks" => [%{"kind" => "code", "language" => "elixir", "text" => "IO.puts(\"ok\")"}]
        }
      },
      %{
        name: "block_divider",
        kind: "card_block",
        action: "send_card",
        card: %{
          "blocks" => [
            %{"kind" => "paragraph", "text" => "Before"},
            %{"kind" => "divider"},
            %{"kind" => "paragraph", "text" => "After"}
          ]
        }
      },
      %{
        name: "block_media",
        kind: "card_block",
        action: "send_card",
        card: %{
          "blocks" => [
            %{
              "kind" => "media",
              "media_type" => "photo",
              "url" => "https://example.com/photo.jpg",
              "caption" => "A safe HTTPS image."
            }
          ]
        }
      },
      %{
        name: "block_collage",
        kind: "card_block",
        action: "send_card",
        card: %{
          "blocks" => [
            %{
              "kind" => "collage",
              "items" => [
                %{
                  "kind" => "media",
                  "media_type" => "photo",
                  "url" => "https://example.com/a.jpg"
                },
                %{
                  "kind" => "media",
                  "media_type" => "photo",
                  "url" => "https://example.com/b.jpg"
                }
              ]
            }
          ]
        }
      },
      %{
        name: "block_slideshow",
        kind: "card_block",
        action: "send_card",
        card: %{
          "blocks" => [
            %{
              "kind" => "slideshow",
              "slides" => [
                %{
                  "kind" => "media",
                  "media_type" => "photo",
                  "url" => "https://example.com/slide-1.jpg"
                },
                %{
                  "kind" => "media",
                  "media_type" => "video",
                  "url" => "https://example.com/slide-2.mp4"
                }
              ]
            }
          ]
        }
      },
      %{
        name: "block_references",
        kind: "card_block",
        action: "send_card",
        card: %{
          "blocks" => [
            %{
              "kind" => "references",
              "items" => [%{"id" => "source-1", "text" => "Reference note"}]
            }
          ]
        }
      },
      %{
        name: "composed_summary",
        kind: "composed_card",
        action: "send_card",
        card: %{
          "title" => "Acme Concierge",
          "blocks" => [
            %{"kind" => "heading", "level" => 2, "text" => "Daily brief"},
            %{
              "kind" => "paragraph",
              "text" => [
                "Everything is ",
                %{"kind" => "bold", "text" => "ready"},
                " for review."
              ]
            },
            %{
              "kind" => "checklist",
              "items" => [
                %{"text" => "Inputs checked", "checked" => true},
                %{"text" => "Final sent", "checked" => false}
              ]
            }
          ],
          "buttons" => [[%{"text" => "Open", "url" => "https://example.com/"}]]
        }
      },
      %{
        name: "composed_analysis",
        kind: "composed_card",
        action: "send_card",
        card: %{
          "title" => "trivia_quest",
          "blocks" => [
            %{"kind" => "heading", "text" => "Round summary"},
            %{
              "kind" => "table",
              "headers" => ["Metric", "Value"],
              "rows" => [["Questions", "5"], ["Score", "4"]]
            },
            %{
              "kind" => "quote",
              "text" => "Answer the strongest clue first.",
              "cite" => "example_bot"
            }
          ],
          "footer" => [
            %{"kind" => "link", "text" => "Rules", "url" => "https://example.com/rules"}
          ]
        }
      },
      %{
        name: "action_send_card",
        kind: "action",
        action: "send_card",
        conversation_id: "tg:123:0",
        card: %{
          "title" => "Update",
          "blocks" => [
            %{"kind" => "paragraph", "text" => "Here is the concise answer."}
          ]
        }
      },
      %{
        name: "action_stream_card",
        kind: "action",
        action: "stream_card",
        conversation_id: "tg:123:0",
        draft_id: 1,
        card: %{
          "title" => "Composing answer",
          "blocks" => [
            %{"kind" => "thinking", "text" => "Checking the current context."},
            %{
              "kind" => "checklist",
              "items" => [
                %{"text" => "Read input", "checked" => true},
                %{"text" => "Draft final", "checked" => false}
              ]
            }
          ]
        }
      },
      %{
        name: "action_edit_card",
        kind: "action",
        action: "edit_card",
        conversation_id: "tg:123:0",
        message_id: 123,
        card: %{
          "title" => "Updated answer",
          "blocks" => [%{"kind" => "paragraph", "text" => "The message has been revised."}]
        }
      },
      %{
        name: "action_reply_with_quote",
        kind: "action",
        action: "reply",
        conversation_id: "tg:123:0",
        reply_to_message_id: 456,
        quote: "specific phrase",
        quote_position: 12,
        quote_parse_mode: "HTML",
        text: "Replying to that exact phrase."
      },
      %{
        name: "block_details",
        kind: "card_block",
        action: "send_card",
        card: %{
          "blocks" => [
            %{
              "kind" => "details",
              "summary" => "What changed?",
              "blocks" => [%{"kind" => "paragraph", "text" => "Everything important."}]
            }
          ]
        }
      },
      %{
        name: "block_blockquote_expandable",
        kind: "card_block",
        action: "send_card",
        card: %{
          "blocks" => [
            %{
              "kind" => "blockquote",
              "expandable" => true,
              "text" => "A long quotation that Telegram collapses until tapped.",
              "credit" => "Source"
            }
          ]
        }
      },
      %{
        name: "block_pullquote",
        kind: "card_block",
        action: "send_card",
        card: %{
          "blocks" => [
            %{"kind" => "pullquote", "text" => "Ship the smallest clear card.", "credit" => "Ops"}
          ]
        }
      },
      %{
        name: "block_pre",
        kind: "card_block",
        action: "send_card",
        card: %{
          "blocks" => [%{"kind" => "pre", "text" => "plain preformatted text"}]
        }
      },
      %{
        name: "block_footer",
        kind: "card_block",
        action: "send_card",
        card: %{
          "blocks" => [
            %{"kind" => "paragraph", "text" => "Body"},
            %{"kind" => "footer", "text" => "Fine print lives here."}
          ]
        }
      },
      %{
        name: "block_math",
        kind: "card_block",
        action: "send_card",
        card: %{
          "blocks" => [
            %{"kind" => "mathematical_expression", "expression" => "p = \\frac{yes}{yes + no}"}
          ]
        }
      },
      %{
        name: "block_anchor",
        kind: "card_block",
        action: "send_card",
        card: %{
          "blocks" => [
            %{"kind" => "anchor", "name" => "summary"},
            %{
              "kind" => "paragraph",
              "text" => [
                "Jump back to ",
                %{"kind" => "anchor_link", "text" => "the summary", "anchor_name" => "summary"}
              ]
            }
          ]
        }
      },
      %{
        name: "block_time",
        kind: "card_block",
        action: "send_card",
        card: %{
          "blocks" => [
            %{
              "kind" => "time",
              "unix" => 1_800_000_000,
              "format" => "relative",
              "text" => "window closes"
            }
          ]
        }
      },
      %{
        name: "block_map",
        kind: "card_block",
        action: "send_card",
        card: %{
          "blocks" => [
            %{"kind" => "map", "latitude" => 41.3874, "longitude" => 2.1686, "zoom" => 12}
          ]
        }
      },
      %{
        name: "block_thinking_draft",
        kind: "card_block",
        action: "stream_card",
        card: %{
          "blocks" => [%{"kind" => "thinking", "text" => "Checking market state..."}]
        }
      },
      %{
        name: "inline_span_sampler",
        kind: "card_block",
        action: "send_card",
        card: %{
          "blocks" => [
            %{
              "kind" => "paragraph",
              "text" => [
                "Spans: ",
                %{"kind" => "bold", "text" => "bold"},
                " ",
                %{"kind" => "italic", "text" => "italic"},
                " ",
                %{"kind" => "underline", "text" => "underline"},
                " ",
                %{"kind" => "strikethrough", "text" => "strike"},
                " ",
                %{"kind" => "spoiler", "text" => "spoiler"},
                " ",
                %{"kind" => "mark", "text" => "mark"},
                " ",
                %{"kind" => "code", "text" => "code"},
                " ",
                %{"kind" => "sub", "text" => "sub"},
                %{"kind" => "sup", "text" => "sup"},
                " ",
                %{"kind" => "link", "text" => "link", "url" => "https://example.com/"},
                " ",
                %{"kind" => "custom_emoji", "text" => "⭐", "emoji_id" => "5368324170671202286"},
                " ",
                %{"kind" => "date_time", "text" => "then", "unix" => 1_800_000_000},
                " ",
                %{"kind" => "mention", "text" => "@example", "username" => "example"},
                " ",
                %{"kind" => "text_mention", "text" => "Alice", "user_id" => 123},
                " ",
                %{"kind" => "mathematical_expression", "expression" => "x^2"},
                " ",
                %{"kind" => "email_address", "email_address" => "a@example.com"},
                " ",
                %{"kind" => "phone_number", "phone_number" => "+34600000000"},
                " ",
                %{"kind" => "hashtag", "text" => "markets"},
                " ",
                %{"kind" => "cashtag", "text" => "USDC"},
                " ",
                %{"kind" => "bot_command", "text" => "start"}
              ]
            }
          ]
        }
      }
    ]
  end

  @doc "Validate a structured card. Returns `:ok` or `{:error, [error]}`."
  def validate(card, opts \\ %{})

  def validate(card, opts) when is_map(card) do
    errors =
      []
      |> validate_title(card, opts)
      |> validate_inline_fields(card, "card", [:footer])
      |> validate_blocks(blocks(card), "card.blocks", opts)
      |> validate_buttons(get(card, :buttons), "card.buttons")

    if errors == [], do: :ok, else: {:error, Enum.reverse(errors)}
  end

  def validate(_card, _opts),
    do:
      {:error,
       [
         err("card", "card must be an object",
           expected: "object",
           got: "non-object",
           hint: "send a JSON object with a \"blocks\" list, not a bare value"
         )
       ]}

  @doc "Render a structured card into `InputRichMessage`."
  def to_rich_message(card, opts \\ %{}) do
    with :ok <- validate(card, opts) do
      html =
        [
          render_title(card),
          render_blocks(blocks(card), opts),
          render_footer(card)
        ]
        |> List.flatten()
        |> Enum.reject(&(&1 in [nil, ""]))
        |> Enum.join("\n")

      {:ok,
       RichMessage.html(html,
         is_rtl: truthy?(get(card, :is_rtl)),
         skip_entity_detection: truthy?(get(card, :skip_entity_detection))
       )}
    end
  end

  defp validate_title(errors, card, opts) do
    case get(card, :title) do
      nil ->
        if required_title?(opts) do
          [
            err("card.title", "title is required",
              expected: "non-empty string",
              got: nil,
              hint: "add a non-empty \"title\" field to this card"
            )
            | errors
          ]
        else
          errors
        end

      title when is_binary(title) ->
        if required_title?(opts) and blank?(title) do
          [
            err("card.title", "title must be non-empty",
              expected: "non-empty string",
              got: title,
              hint: "replace the empty card title with visible text"
            )
            | errors
          ]
        else
          errors
        end

      other ->
        [
          err("card.title", "title must be a string",
            expected: "string",
            got: other,
            hint: "replace \"title\" with a plain text string"
          )
          | errors
        ]
    end
  end

  defp validate_blocks(errors, blocks, path, opts) when is_list(blocks) do
    blocks
    |> Enum.with_index()
    |> Enum.reduce(errors, fn {block, idx}, acc ->
      validate_block(acc, block, "#{path}[#{idx}]", opts)
    end)
  end

  defp validate_blocks(errors, _blocks, path, _opts),
    do: [err(path, "blocks must be a list") | errors]

  defp validate_block(errors, block, path, opts) when is_map(block) do
    case get(block, :kind) || get(block, :type) do
      kind when kind in ["heading", "paragraph", "quote", "pullquote", "footer"] ->
        errors
        |> validate_required_inline(block, :text, "#{path}.text")
        |> validate_inline_fields(block, path, [:cite, :credit])

      kind when kind in ["code", "pre"] ->
        validate_required_text(errors, block, :text, "#{path}.text")

      "divider" ->
        errors

      "time" ->
        validate_inline_fields(errors, block, path, [:text, :cite, :credit])

      kind when kind in ["mathematical_expression", "math"] ->
        validate_required_text(errors, block, :expression, "#{path}.expression")

      "anchor" ->
        validate_required_text(errors, block, :name, "#{path}.name")

      "blockquote" ->
        errors
        |> validate_inline_fields(block, path, [:text, :cite, :credit])
        |> validate_blocks(get(block, :blocks) || [], "#{path}.blocks", opts)

      "map" ->
        validate_map(errors, block, path)

      "list" ->
        errors
        |> validate_required_list(block, :items, "#{path}.items")
        |> validate_inline_items(get(block, :items), "#{path}.items")

      "checklist" ->
        errors
        |> validate_required_list(block, :items, "#{path}.items")
        |> validate_inline_items(get(block, :items), "#{path}.items")

      "table" ->
        errors
        |> validate_required_list(block, :headers, "#{path}.headers")
        |> validate_required_list(block, :rows, "#{path}.rows")
        |> validate_inline_items(get(block, :headers), "#{path}.headers")
        |> validate_inline_rows(get(block, :rows), "#{path}.rows")
        |> validate_inline_fields(block, path, [:caption])

      "details" ->
        errors
        |> validate_inline_fields(block, path, [:summary])
        |> validate_blocks(get(block, :blocks) || [], "#{path}.blocks", opts)

      "media" ->
        errors
        |> validate_media(block, path)
        |> validate_inline_fields(block, path, [:caption])

      "collage" ->
        errors
        |> validate_collage_content(block, path, opts)
        |> validate_inline_fields(block, path, [:caption])

      "slideshow" ->
        errors
        |> validate_blocks(slideshow_blocks(block), "#{path}.#{slideshow_path_key(block)}", opts)
        |> validate_inline_fields(block, path, [:caption])

      "references" ->
        errors
        |> validate_required_list(block, :items, "#{path}.items")
        |> validate_inline_items(get(block, :items), "#{path}.items")

      "thinking" ->
        if Map.get(opts, :draft?, false),
          do: errors,
          else: [
            err(path, "thinking blocks are only allowed for streaming drafts",
              expected: "no thinking block in final cards",
              got: "thinking",
              hint:
                "remove this thinking block before a final send, or validate with draft?: true while streaming"
            )
            | errors
          ]

      nil ->
        [
          err("#{path}.kind", "block kind is required",
            expected: @block_kinds,
            got: nil,
            hint: "add a \"kind\" field such as \"paragraph\", \"heading\", or \"media\""
          )
          | errors
        ]

      kind ->
        [
          err("#{path}.kind", "unsupported block kind #{inspect(kind)}",
            expected: @block_kinds,
            got: kind,
            hint: "replace this block kind with one of the supported card block kinds"
          )
          | errors
        ]
    end
  end

  defp validate_block(errors, _block, path, _opts),
    do: [
      err(path, "block must be an object",
        expected: "object",
        got: "non-object",
        hint:
          "replace this block with an object like %{\"kind\" => \"paragraph\", \"text\" => \"...\"}"
      )
      | errors
    ]

  defp validate_required_list(errors, block, key, path) do
    case get(block, key) do
      list when is_list(list) and list != [] ->
        errors

      other ->
        [
          err(path, "must be a non-empty list",
            expected: "non-empty list",
            got: other,
            hint: "add at least one item to #{field_label(path)}"
          )
          | errors
        ]
    end
  end

  defp validate_required_text(errors, block, key, path) do
    case get(block, key) do
      value when is_binary(value) ->
        if blank?(value) do
          [
            err(path, "must be non-empty",
              expected: "non-empty string",
              got: value,
              hint: "add non-empty text to #{field_label(path)}"
            )
            | errors
          ]
        else
          errors
        end

      other ->
        [
          err(path, "must be a non-empty string",
            expected: "non-empty string",
            got: other,
            hint: "add a non-empty string to #{field_label(path)}"
          )
          | errors
        ]
    end
  end

  defp validate_required_inline(errors, block, key, path) do
    case get(block, key) do
      value when is_binary(value) ->
        if blank?(value) do
          [
            err(path, "must be non-empty",
              expected: "non-empty inline text",
              got: value,
              hint: "add non-empty \"text\" content to this #{block_kind(block)} block"
            )
            | errors
          ]
        else
          errors
        end

      value when is_list(value) and value != [] ->
        validate_inline(errors, value, path)

      value when is_map(value) ->
        validate_inline(errors, value, path)

      other ->
        [
          err(path, "must be non-empty inline text",
            expected: "string, inline span, or non-empty list",
            got: other,
            hint: "add a non-empty \"text\" field to this #{block_kind(block)} block"
          )
          | errors
        ]
    end
  end

  defp validate_media(errors, block, path) do
    kind = get(block, :media_type) || get(block, :type)
    url = get(block, :url)

    cond do
      kind not in @media_kinds ->
        [
          err("#{path}.media_type", "must be one of #{Enum.join(@media_kinds, ", ")}",
            expected: @media_kinds,
            got: kind,
            hint: "set \"media_type\" to one of: #{Enum.join(@media_kinds, ", ")}"
          )
          | errors
        ]

      not safe_http_url?(url) ->
        [
          err("#{path}.url", "media URL must be http or https",
            expected: "http or https URL",
            got: url,
            hint: "use an absolute http:// or https:// URL for this media block"
          )
          | errors
        ]

      true ->
        errors
    end
  end

  defp validate_map(errors, block, path) do
    lat = get(block, :latitude)
    lon = get(block, :longitude)

    cond do
      is_nil(lat) ->
        [
          err("#{path}.latitude", "latitude is required",
            expected: "number",
            got: nil,
            hint: "add a numeric \"latitude\" value to this map block"
          )
          | errors
        ]

      is_nil(lon) ->
        [
          err("#{path}.longitude", "longitude is required",
            expected: "number",
            got: nil,
            hint: "add a numeric \"longitude\" value to this map block"
          )
          | errors
        ]

      not numeric?(lat) ->
        [
          err("#{path}.latitude", "latitude must be numeric",
            expected: "number",
            got: lat,
            hint: "replace \"latitude\" with a numeric value such as 41.3874"
          )
          | errors
        ]

      not numeric?(lon) ->
        [
          err("#{path}.longitude", "longitude must be numeric",
            expected: "number",
            got: lon,
            hint: "replace \"longitude\" with a numeric value such as 2.1686"
          )
          | errors
        ]

      true ->
        errors
    end
  end

  defp validate_media_items(errors, items, path) when is_list(items) and items != [] do
    Enum.with_index(items)
    |> Enum.reduce(errors, fn {item, idx}, acc ->
      acc
      |> validate_media(item, "#{path}[#{idx}]")
      |> validate_inline_fields(item, "#{path}[#{idx}]", [:caption])
    end)
  end

  defp validate_media_items(errors, _items, path),
    do: [
      err(path, "must be a non-empty list",
        expected: "non-empty list of media items",
        got: "missing or empty",
        hint: "add one or more media items with media_type and https URL fields"
      )
      | errors
    ]

  defp validate_collage_content(errors, block, path, opts) do
    case get(block, :blocks) do
      blocks when is_list(blocks) ->
        validate_blocks(errors, blocks, "#{path}.blocks", opts)

      _ ->
        validate_media_items(errors, get(block, :items), "#{path}.items")
    end
  end

  defp validate_inline_fields(errors, block, path, fields) do
    Enum.reduce(fields, errors, fn field, acc ->
      case get(block, field) do
        nil -> acc
        value -> validate_inline(acc, value, "#{path}.#{field}")
      end
    end)
  end

  defp validate_inline_items(errors, items, path) when is_list(items) do
    items
    |> Enum.with_index()
    |> Enum.reduce(errors, fn {item, idx}, acc ->
      validate_inline(acc, item_text(item), "#{path}[#{idx}].text")
    end)
  end

  defp validate_inline_items(errors, _items, _path), do: errors

  defp validate_inline_rows(errors, rows, path) when is_list(rows) do
    rows
    |> Enum.with_index()
    |> Enum.reduce(errors, fn {row, row_idx}, acc ->
      if is_list(row) do
        row
        |> Enum.with_index()
        |> Enum.reduce(acc, fn {cell, cell_idx}, cell_acc ->
          validate_inline(cell_acc, cell, "#{path}[#{row_idx}][#{cell_idx}]")
        end)
      else
        [
          err("#{path}[#{row_idx}]", "row must be a list",
            expected: "list of table cells",
            got: row,
            hint: "replace this table row with a list such as [\"Label\", \"Value\"]"
          )
          | acc
        ]
      end
    end)
  end

  defp validate_inline_rows(errors, _rows, _path), do: errors

  defp validate_inline(errors, value, _path) when is_binary(value) or is_number(value), do: errors

  defp validate_inline(errors, value, path) when is_list(value) do
    value
    |> Enum.with_index()
    |> Enum.reduce(errors, fn {part, idx}, acc ->
      validate_inline(acc, part, "#{path}[#{idx}]")
    end)
  end

  defp validate_inline(errors, value, path) when is_map(value) do
    kind = get(value, :kind) || get(value, :type) || get(value, :style)
    text = get(value, :text) || get(value, :children) || get(value, :content) || ""

    cond do
      kind not in @inline_kinds ->
        [
          err("#{path}.kind", "unsupported inline kind #{inspect(kind)}",
            expected: @inline_kinds,
            got: kind,
            hint: "replace this inline span kind with one of the supported inline kinds"
          )
          | errors
        ]

      kind in ["link", "url"] and not safe_http_url?(get(value, :url) || get(value, :href)) ->
        [
          err("#{path}.url", "inline link URL must be http or https",
            expected: "http or https URL",
            got: get(value, :url) || get(value, :href),
            hint: "set this link span's \"url\" or \"href\" to an http:// or https:// URL"
          )
          | errors
        ]

      kind == "custom_emoji" and blank?(get(value, :emoji_id) || get(value, :custom_emoji_id)) ->
        [
          err("#{path}.emoji_id", "custom emoji requires emoji_id",
            expected: "emoji_id",
            got: get(value, :emoji_id) || get(value, :custom_emoji_id),
            hint: "add the Telegram custom emoji id as \"emoji_id\""
          )
          | errors
        ]

      kind in ["date_time"] and is_nil(get(value, :unix) || get(value, :unix_time)) ->
        [
          err("#{path}.unix", "date_time requires unix",
            expected: "unix timestamp",
            got: nil,
            hint: "add a Unix timestamp in the \"unix\" field"
          )
          | errors
        ]

      kind == "text_mention" and is_nil(get(value, :user_id)) ->
        [
          err("#{path}.user_id", "text_mention requires user_id",
            expected: "Telegram user id",
            got: nil,
            hint: "add the mentioned user's numeric Telegram id as \"user_id\""
          )
          | errors
        ]

      kind == "mention" and is_nil(get(value, :user_id)) and blank?(get(value, :username)) ->
        [
          err("#{path}.user_id", "mention requires user_id or username",
            expected: "user_id or username",
            got: nil,
            hint: "add either \"user_id\" or \"username\" to this mention span"
          )
          | errors
        ]

      kind in ["mathematical_expression", "math"] and blank?(inline_expression(value)) ->
        [
          err("#{path}.expression", "mathematical_expression requires expression",
            expected: "math expression",
            got: inline_expression(value),
            hint: "add the formula to the \"expression\" field"
          )
          | errors
        ]

      kind in ["email_address", "email"] and
          not valid_email?(get(value, :email_address) || get(value, :email)) ->
        [
          err("#{path}.email_address", "email_address requires a valid email",
            expected: "email address",
            got: get(value, :email_address) || get(value, :email),
            hint: "set \"email_address\" or \"email\" to a valid address such as name@example.com"
          )
          | errors
        ]

      kind in ["phone_number", "phone"] and
          blank?(get(value, :phone_number) || get(value, :phone)) ->
        [
          err("#{path}.phone_number", "phone_number requires phone_number",
            expected: "phone number",
            got: get(value, :phone_number) || get(value, :phone),
            hint: "add the phone number to \"phone_number\" or \"phone\""
          )
          | errors
        ]

      kind in ["bank_card_number", "bank_card"] and
          blank?(get(value, :bank_card_number) || get(value, :bank_card)) ->
        [
          err("#{path}.bank_card_number", "bank_card_number requires bank_card_number",
            expected: "bank card number",
            got: get(value, :bank_card_number) || get(value, :bank_card),
            hint: "add the card number text to \"bank_card_number\" or \"bank_card\""
          )
          | errors
        ]

      kind == "hashtag" and blank?(get(value, :hashtag) || get(value, :tag) || text) ->
        [
          err("#{path}.hashtag", "hashtag requires hashtag",
            expected: "hashtag text",
            got: get(value, :hashtag) || get(value, :tag) || text,
            hint: "add hashtag text to \"hashtag\", \"tag\", or \"text\""
          )
          | errors
        ]

      kind == "cashtag" and blank?(get(value, :cashtag) || get(value, :tag) || text) ->
        [
          err("#{path}.cashtag", "cashtag requires cashtag",
            expected: "cashtag text",
            got: get(value, :cashtag) || get(value, :tag) || text,
            hint: "add cashtag text to \"cashtag\", \"tag\", or \"text\""
          )
          | errors
        ]

      kind == "bot_command" and blank?(get(value, :bot_command) || get(value, :command) || text) ->
        [
          err("#{path}.bot_command", "bot_command requires bot_command",
            expected: "bot command",
            got: get(value, :bot_command) || get(value, :command) || text,
            hint: "add command text to \"bot_command\", \"command\", or \"text\""
          )
          | errors
        ]

      kind == "anchor" and blank?(get(value, :name)) ->
        [
          err("#{path}.name", "anchor requires name",
            expected: "anchor name",
            got: get(value, :name),
            hint: "add a non-empty \"name\" field to this anchor span"
          )
          | errors
        ]

      kind == "anchor_link" and is_nil(get(value, :anchor_name) || get(value, :name)) ->
        [
          err("#{path}.anchor_name", "anchor_link requires anchor_name",
            expected: "anchor name",
            got: get(value, :anchor_name) || get(value, :name),
            hint: "add \"anchor_name\" that matches an anchor span or block"
          )
          | errors
        ]

      kind in ["reference", "reference_link"] and
          blank?(get(value, :reference_name) || get(value, :name)) ->
        [
          err("#{path}.reference_name", "#{kind} requires reference_name",
            expected: "reference name",
            got: get(value, :reference_name) || get(value, :name),
            hint: "add \"reference_name\" that matches a references item"
          )
          | errors
        ]

      true ->
        validate_inline(errors, text, "#{path}.text")
    end
  end

  defp validate_inline(errors, _value, path),
    do: [
      err(path, "inline text must be a string, list, or object",
        expected: "string, list, or inline span object",
        got: "unsupported value",
        hint: "replace this inline value with text or a supported inline span object"
      )
      | errors
    ]

  defp validate_buttons(errors, nil, _path), do: errors

  defp validate_buttons(errors, buttons, path) when is_list(buttons) do
    buttons
    |> Enum.with_index()
    |> Enum.reduce(errors, fn {row, row_idx}, acc ->
      row_buttons = if is_list(row), do: row, else: [row]

      row_buttons
      |> Enum.with_index()
      |> Enum.reduce(acc, fn {button, button_idx}, button_acc ->
        validate_button(button_acc, button, "#{path}[#{row_idx}][#{button_idx}]")
      end)
    end)
  end

  defp validate_buttons(errors, buttons, path) do
    [
      err(path, "buttons must be a list",
        expected: "list of button rows",
        got: buttons,
        hint:
          "make \"buttons\" a list of rows, for example [[%{\"text\" => \"Open\", \"url\" => \"https://example.com\"}]]"
      )
      | errors
    ]
  end

  defp validate_button(errors, button, path) when is_map(button) do
    errors
    |> validate_button_text(button, path)
    |> validate_button_url(button, path)
    |> validate_button_callback_data(button, path)
    |> validate_button_web_app(button, path)
  end

  defp validate_button(errors, button, path) do
    [
      err(path, "button must be an object",
        expected: "button object",
        got: button,
        hint:
          "replace this button with an object containing at least \"text\" and one action field"
      )
      | errors
    ]
  end

  defp validate_button_text(errors, button, path) do
    case get(button, :text) do
      text when is_binary(text) ->
        if blank?(text) do
          [
            err("#{path}.text", "button text must be non-empty",
              expected: "non-empty string",
              got: text,
              hint: "add visible text to this button"
            )
            | errors
          ]
        else
          errors
        end

      other ->
        [
          err("#{path}.text", "button text must be non-empty",
            expected: "non-empty string",
            got: other,
            hint: "add a non-empty \"text\" field to this button"
          )
          | errors
        ]
    end
  end

  defp validate_button_url(errors, button, path) do
    case get(button, :url) do
      nil ->
        errors

      url ->
        if safe_http_url?(url) do
          errors
        else
          [
            err("#{path}.url", "button URL must be http or https",
              expected: "http or https URL",
              got: url,
              hint: "set this button URL to an absolute http:// or https:// URL"
            )
            | errors
          ]
        end
    end
  end

  defp validate_button_callback_data(errors, button, path) do
    case get(button, :callback_data) || get(button, :action) do
      nil ->
        errors

      data when is_binary(data) and byte_size(data) in 1..@button_callback_data_max_bytes ->
        errors

      data ->
        [
          err("#{path}.callback_data", "callback_data must be 1 to 64 bytes",
            expected: "1 to 64 bytes",
            got: data,
            hint: "shorten this callback_data to 64 bytes or fewer"
          )
          | errors
        ]
    end
  end

  defp validate_button_web_app(errors, button, path) do
    case get(button, :web_app) do
      nil ->
        errors

      url when is_binary(url) ->
        if safe_http_url?(url) do
          errors
        else
          [
            err("#{path}.web_app.url", "web_app URL must be http or https",
              expected: "http or https URL",
              got: url,
              hint: "set this Web App URL to an absolute http:// or https:// URL"
            )
            | errors
          ]
        end

      web_app when is_map(web_app) ->
        url = get(web_app, :url)

        if safe_http_url?(url) do
          errors
        else
          [
            err("#{path}.web_app.url", "web_app URL must be http or https",
              expected: "http or https URL",
              got: url,
              hint: "set this Web App URL to an absolute http:// or https:// URL"
            )
            | errors
          ]
        end

      other ->
        [
          err("#{path}.web_app", "web_app must be a URL or object with url",
            expected: "URL string or %{url: URL}",
            got: other,
            hint:
              "replace web_app with an https URL or an object like %{\"url\" => \"https://example.com/app\"}"
          )
          | errors
        ]
    end
  end

  defp render_title(card) do
    case get(card, :title) do
      nil -> nil
      title -> "<h3>#{escape(title)}</h3>"
    end
  end

  defp render_footer(card) do
    case get(card, :footer) do
      nil -> nil
      footer -> "<footer>#{render_inline(footer)}</footer>"
    end
  end

  defp render_blocks(blocks, opts), do: Enum.map(blocks, &render_block(&1, opts))

  defp render_block(block, opts) do
    case get(block, :kind) || get(block, :type) do
      "heading" ->
        level = block |> get(:level) |> normalize_heading_level()
        "<h#{level}>#{render_inline(get(block, :text) || "")}</h#{level}>"

      "paragraph" ->
        "<p>#{render_inline(get(block, :text) || "")}</p>"

      "list" ->
        items = get(block, :items) || []
        tag = if truthy?(get(block, :ordered)), do: "ol", else: "ul"

        "<#{tag}#{list_attrs(block)}>" <>
          Enum.map_join(items, "", fn item ->
            "<li#{list_item_attrs(item)}>#{render_inline(item_text(item))}</li>"
          end) <> "</#{tag}>"

      "checklist" ->
        items = get(block, :items) || []

        "<ul>" <>
          Enum.map_join(items, "", fn item ->
            checked = if truthy?(get_item(item, :checked)), do: " checked", else: ""
            ~s(<li><input type="checkbox"#{checked}/>#{render_inline(item_text(item))}</li>)
          end) <> "</ul>"

      "table" ->
        table_attrs = table_attrs(block)
        headers = get(block, :headers) || []
        rows = get(block, :rows) || []

        head =
          "<tr>" <>
            Enum.map_join(headers, "", fn cell -> "<th>#{render_inline(cell)}</th>" end) <>
            "</tr>"

        body =
          Enum.map_join(rows, "", fn row ->
            "<tr>" <>
              Enum.map_join(row, "", fn cell -> "<td>#{render_inline(cell)}</td>" end) <> "</tr>"
          end)

        caption =
          case get(block, :caption) do
            nil -> ""
            text -> "<caption>#{render_inline(text)}</caption>"
          end

        "<table#{table_attrs}>#{caption}#{head}#{body}</table>"

      "details" ->
        open = if truthy?(get(block, :open)), do: " open", else: ""
        summary = render_inline(get(block, :summary) || "Details")
        inner = render_blocks(get(block, :blocks) || [], opts)
        "<details#{open}><summary>#{summary}</summary>#{inner}</details>"

      "quote" ->
        expandable = if truthy?(get(block, :expandable)), do: " expandable", else: ""
        credit = cite(get(block, :credit) || get(block, :cite))
        "<blockquote#{expandable}>#{render_inline(get(block, :text) || "")}#{credit}</blockquote>"

      "blockquote" ->
        expandable = if truthy?(get(block, :expandable)), do: " expandable", else: ""
        blocks = render_blocks(get(block, :blocks) || [], opts)
        text = render_inline(get(block, :text) || "")
        credit = cite(get(block, :credit) || get(block, :cite))
        "<blockquote#{expandable}>#{blocks}#{text}#{credit}</blockquote>"

      "pullquote" ->
        credit = cite(get(block, :credit) || get(block, :cite))
        "<aside>#{render_inline(get(block, :text) || "")}#{credit}</aside>"

      "code" ->
        render_pre(block)

      "pre" ->
        render_pre(block)

      "mathematical_expression" ->
        "<tg-math-block>#{escape(get(block, :expression) || "")}</tg-math-block>"

      "math" ->
        "<tg-math-block>#{escape(get(block, :expression) || "")}</tg-math-block>"

      "anchor" ->
        ~s(<a name="#{escape_attr(get(block, :name) || "")}"></a>)

      "footer" ->
        "<footer>#{render_inline(get(block, :text) || "")}</footer>"

      "divider" ->
        "<hr/>"

      "media" ->
        render_media(block)

      "collage" ->
        inner =
          case get(block, :blocks) do
            blocks when is_list(blocks) -> Enum.map_join(blocks, "", &render_block(&1, opts))
            _ -> Enum.map_join(get(block, :items) || [], "", &render_media/1)
          end

        "<tg-collage>#{inner}#{figcaption(block)}</tg-collage>"

      "slideshow" ->
        slides = Enum.map_join(slideshow_blocks(block), "", &render_block(&1, opts))

        "<tg-slideshow>#{slides}#{figcaption(block)}</tg-slideshow>"

      "references" ->
        Enum.map_join(get(block, :items) || [], "", fn item ->
          name = escape_attr(get_item(item, :name) || get_item(item, :id) || "ref")
          text = render_inline(item_text(item))
          ~s(<tg-reference name="#{name}">#{text}</tg-reference>)
        end)

      "time" ->
        unix = get(block, :unix) || get(block, :unix_time) || get(block, :timestamp)
        format = time_format_attr(get(block, :format))
        label = render_inline(get(block, :text) || unix || "")
        ~s(<tg-time unix="#{escape_attr(unix || "")}"#{format}>#{label}</tg-time>)

      "map" ->
        lat = escape_attr(get(block, :latitude) || "")
        lon = escape_attr(get(block, :longitude) || "")
        zoom = escape_attr(get(block, :zoom) || 14)

        map = ~s(<tg-map lat="#{lat}" long="#{lon}" zoom="#{zoom}"/>)
        with_caption(map, block)

      "thinking" ->
        if Map.get(opts, :draft?, false),
          do: "<tg-thinking>#{render_inline(get(block, :text) || "")}</tg-thinking>",
          else: ""

      _ ->
        ""
    end
  end

  defp render_pre(block) do
    class =
      case get(block, :language) do
        nil -> ""
        language -> ~s( class="language-#{escape_attr(language)}")
      end

    "<pre><code#{class}>#{escape(get(block, :text) || "")}</code></pre>"
  end

  defp render_media(block) do
    url = escape_attr(get(block, :url) || "")
    tag = media_tag(get(block, :media_type) || get(block, :type))
    spoiler = if truthy?(get(block, :spoiler)), do: " tg-spoiler", else: ""

    media =
      if tag == "img" do
        ~s(<img#{spoiler} src="#{url}"/>)
      else
        ~s(<#{tag}#{spoiler} src="#{url}"></#{tag}>)
      end

    with_caption(media, block)
  end

  defp media_tag("photo"), do: "img"
  defp media_tag("video"), do: "video"
  defp media_tag("animation"), do: "video"
  defp media_tag("audio"), do: "audio"
  defp media_tag("voice_note"), do: "audio"
  defp media_tag(_), do: "img"

  defp with_caption(html, block) do
    case figcaption(block) do
      "" -> html
      caption -> "<figure>#{html}#{caption}</figure>"
    end
  end

  defp figcaption(block) do
    case get(block, :caption) do
      nil -> ""
      text -> "<figcaption>#{render_inline(text)}</figcaption>"
    end
  end

  defp render_inline(value) when is_binary(value), do: escape(value)
  defp render_inline(value) when is_integer(value) or is_float(value), do: escape(value)
  defp render_inline(value) when is_list(value), do: Enum.map_join(value, "", &render_inline/1)

  defp render_inline(value) when is_map(value) do
    kind = get(value, :kind) || get(value, :type) || get(value, :style)
    text = get(value, :text) || get(value, :children) || get(value, :content) || ""
    rendered = render_inline(text)

    case kind do
      "bold" -> "<b>#{rendered}</b>"
      "italic" -> "<i>#{rendered}</i>"
      "underline" -> "<u>#{rendered}</u>"
      "strikethrough" -> "<s>#{rendered}</s>"
      "spoiler" -> "<tg-spoiler>#{rendered}</tg-spoiler>"
      "mark" -> "<mark>#{rendered}</mark>"
      "marked" -> "<mark>#{rendered}</mark>"
      "code" -> "<code>#{rendered}</code>"
      "sub" -> "<sub>#{rendered}</sub>"
      "subscript" -> "<sub>#{rendered}</sub>"
      "sup" -> "<sup>#{rendered}</sup>"
      "superscript" -> "<sup>#{rendered}</sup>"
      "link" -> render_link(value, rendered)
      "url" -> render_link(value, rendered)
      "custom_emoji" -> render_custom_emoji(value, rendered)
      "date_time" -> render_inline_time(value, rendered)
      "mention" -> render_mention(value, rendered)
      "text_mention" -> render_user_mention(value, rendered)
      "mathematical_expression" -> render_inline_math(value)
      "math" -> render_inline_math(value)
      "email_address" -> render_email(value, rendered)
      "email" -> render_email(value, rendered)
      "phone_number" -> render_phone(value, rendered)
      "phone" -> render_phone(value, rendered)
      "bank_card_number" -> prefixed_text(value, rendered, :bank_card_number, "")
      "bank_card" -> prefixed_text(value, rendered, :bank_card, "")
      "hashtag" -> prefixed_text(value, rendered, :hashtag, "#")
      "cashtag" -> prefixed_text(value, rendered, :cashtag, "$")
      "bot_command" -> prefixed_text(value, rendered, :bot_command, "/")
      "anchor" -> ~s(<a name="#{escape_attr(get(value, :name) || "")}"></a>)
      "anchor_link" -> render_anchor_link(value, rendered)
      "reference" -> render_reference(value, rendered)
      "reference_link" -> render_reference_link(value, rendered)
      _ -> rendered
    end
  end

  defp render_inline(value), do: escape(value)

  defp render_link(value, rendered) do
    url = get(value, :url) || get(value, :href)
    ~s(<a href="#{escape_attr(url)}">#{rendered}</a>)
  end

  defp render_custom_emoji(value, rendered) do
    emoji_id = get(value, :emoji_id) || get(value, :custom_emoji_id)
    fallback = if rendered == "", do: "🙂", else: rendered
    ~s(<tg-emoji emoji-id="#{escape_attr(emoji_id)}">#{fallback}</tg-emoji>)
  end

  defp render_inline_time(value, rendered) do
    unix = get(value, :unix) || get(value, :unix_time)
    format = time_format_attr(get(value, :format))
    ~s(<tg-time unix="#{escape_attr(unix)}"#{format}>#{rendered}</tg-time>)
  end

  defp render_mention(value, rendered) do
    if get(value, :user_id) do
      render_user_mention(value, rendered)
    else
      prefixed_text(value, rendered, :username, "@")
    end
  end

  defp render_user_mention(value, rendered) do
    user_id = get(value, :user_id)
    ~s(<a href="tg://user?id=#{escape_attr(user_id)}">#{rendered}</a>)
  end

  defp render_inline_math(value) do
    "<tg-math>#{escape(inline_expression(value) || "")}</tg-math>"
  end

  defp render_email(value, rendered) do
    email = get(value, :email_address) || get(value, :email)
    text = if rendered == "", do: escape(email), else: rendered
    ~s(<a href="mailto:#{escape_attr(email)}">#{text}</a>)
  end

  defp render_phone(value, rendered) do
    phone = get(value, :phone_number) || get(value, :phone)
    text = if rendered == "", do: escape(phone), else: rendered
    ~s(<a href="tel:#{escape_attr(phone)}">#{text}</a>)
  end

  defp render_anchor_link(value, rendered) do
    anchor_name = get(value, :anchor_name) || get(value, :name) || ""
    ~s(<a href="##{escape_attr(anchor_name)}">#{rendered}</a>)
  end

  defp render_reference(value, rendered) do
    name = get(value, :reference_name) || get(value, :name)
    ~s(<tg-reference name="#{escape_attr(name)}">#{rendered}</tg-reference>)
  end

  defp render_reference_link(value, rendered) do
    name = get(value, :reference_name) || get(value, :name)
    ~s(<a href="##{escape_attr(name)}">#{rendered}</a>)
  end

  defp table_attrs(block) do
    [
      if(truthy?(get(block, :bordered)), do: " bordered"),
      if(truthy?(get(block, :striped)), do: " striped")
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.join("")
  end

  defp normalize_heading_level(level) when level in 1..6, do: level

  defp normalize_heading_level(level) when is_binary(level) do
    case Integer.parse(level) do
      {n, ""} when n in 1..6 -> n
      _ -> 4
    end
  end

  defp normalize_heading_level(_), do: 4

  defp time_format_attr(nil), do: ""
  defp time_format_attr(format), do: ~s( format="#{escape_attr(format)}")

  defp cite(nil), do: ""
  defp cite(text), do: "<cite>#{render_inline(text)}</cite>"

  defp list_attrs(block) do
    [
      if(truthy?(get(block, :reversed)), do: " reversed"),
      attr(:start, get(block, :start)),
      attr(:type, get(block, :list_type))
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.join("")
  end

  defp list_item_attrs(item) do
    [
      attr(:value, get_item(item, :value)),
      attr(:type, get_item(item, :list_type))
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.join("")
  end

  defp attr(_name, nil), do: nil
  defp attr(name, value), do: ~s( #{name}="#{escape_attr(value)}")

  defp prefixed_text(value, rendered, field, prefix) do
    raw = get(value, field) || get(value, :tag) || get(value, :command) || get(value, :text)
    text = if rendered == "", do: escape(ensure_prefix(raw, prefix)), else: rendered
    text
  end

  defp ensure_prefix(value, ""), do: to_string(value || "")

  defp ensure_prefix(value, prefix) do
    value = to_string(value || "")
    if String.starts_with?(value, prefix), do: value, else: prefix <> value
  end

  defp blocks(card), do: get(card, :blocks) || get(card, :sections) || []

  defp slideshow_blocks(block), do: get(block, :blocks) || get(block, :slides) || []

  defp slideshow_path_key(block) do
    if get(block, :blocks), do: "blocks", else: "slides"
  end

  defp item_text(item) when is_binary(item), do: item
  defp item_text(item) when is_map(item), do: get_item(item, :text) || ""
  defp item_text(item), do: to_string(item)

  defp get_item(map, key) when is_map(map), do: Map.get(map, key) || Map.get(map, to_string(key))
  defp get_item(_map, _key), do: nil

  defp get(map, key) when is_map(map), do: Map.get(map, key) || Map.get(map, to_string(key))

  defp required_title?(opts) when is_map(opts),
    do: Map.get(opts, :require_title?, false) or Map.get(opts, :title_required?, false)

  defp required_title?(opts) when is_list(opts),
    do: Keyword.get(opts, :require_title?, false) or Keyword.get(opts, :title_required?, false)

  defp required_title?(_opts), do: false

  defp truthy?(value), do: value in [true, "true", 1, "1"]

  defp blank?(value), do: is_nil(value) or String.trim(to_string(value)) == ""

  defp block_kind(block), do: get(block, :kind) || get(block, :type) || "card"

  defp field_label(path) do
    path
    |> String.split(".")
    |> List.last()
    |> String.replace(~r/\[\d+\]/, "")
  end

  defp inline_expression(value), do: get(value, :expression) || get(value, :text)

  defp valid_email?(value) when is_binary(value) do
    value =~ ~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/
  end

  defp valid_email?(_value), do: false

  defp numeric?(value) when is_integer(value) or is_float(value), do: true

  defp numeric?(value) when is_binary(value) do
    case Float.parse(value) do
      {_number, ""} -> true
      _ -> false
    end
  end

  defp numeric?(_value), do: false

  defp safe_http_url?(url) when is_binary(url) do
    uri = URI.parse(url)
    uri.scheme in ["http", "https"] and is_binary(uri.host) and uri.host != ""
  end

  defp safe_http_url?(_), do: false

  defp escape(text) do
    text
    |> to_string()
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
  end

  defp escape_attr(text), do: escape(text) |> String.replace("\"", "&quot;")

  defp err(path, reason, opts \\ []) do
    hint = Keyword.get(opts, :hint) || default_hint(path, reason)

    %{path: path, reason: reason, hint: hint}
    |> maybe_put_error(:expected, opts)
    |> maybe_put_error(:got, opts)
  end

  defp maybe_put_error(error, key, opts) do
    if Keyword.has_key?(opts, key) do
      Map.put(error, key, Keyword.get(opts, key))
    else
      error
    end
  end

  defp default_hint(path, reason),
    do: "fix #{path} so it satisfies this rule: #{reason}"
end

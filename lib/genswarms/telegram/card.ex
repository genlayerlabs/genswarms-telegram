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
  @limits %{
    text_utf16_units: 4_096,
    caption_utf16_units: 1_024,
    media_group_items: %{min: 2, max: 10},
    inline_query_results: %{min: 1, max: 50},
    callback_text_chars: %{min: 0, max: 200}
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
        name: "welcome",
        action: "send_card",
        card: %{
          "title" => "Welcome",
          "blocks" => [
            %{
              "kind" => "paragraph",
              "text" => [
                "Your ",
                %{"kind" => "bold", "text" => "Telegram agent"},
                " instance is ready."
              ]
            },
            %{
              "kind" => "media",
              "media_type" => "animation",
              "url" => "https://example.com/boot.mp4"
            },
            %{
              "kind" => "details",
              "summary" => "What can I do?",
              "blocks" => [
                %{"kind" => "list", "items" => ["campaigns", "drafts", "budget status"]}
              ]
            }
          ],
          "buttons" => [[%{"text" => "Open", "url" => "https://example.com/"}]]
        }
      },
      %{
        name: "operator_table",
        action: "send_card",
        card: %{
          "title" => "Operator Snapshot",
          "blocks" => [
            %{
              "kind" => "table",
              "bordered" => true,
              "striped" => true,
              "headers" => ["identity", "runs", "spend", "state"],
              "rows" => [["global", "42", "$0.44", "ok"]]
            }
          ]
        }
      },
      %{
        name: "streaming_draft",
        action: "stream_card",
        draft_id: 123,
        card: %{
          "title" => "Composing answer",
          "blocks" => [
            %{"kind" => "thinking", "text" => "Checking campaigns..."},
            %{
              "kind" => "checklist",
              "items" => [
                %{"text" => "identity", "checked" => true},
                %{"text" => "router", "checked" => false}
              ]
            }
          ]
        }
      },
      %{
        name: "answer_callback",
        action: "answer_callback",
        callback_query_id: "cb_123",
        text: "Done"
      },
      %{
        name: "answer_inline_query",
        action: "answer_inline_query",
        inline_query_id: "inline_123",
        results: [
          %{
            "type" => "article",
            "id" => "status",
            "title" => "Status",
            "input_message_content" => %{"message_text" => "Ready"}
          }
        ]
      },
      %{
        name: "post_story",
        action: "post_story",
        business_connection_id: "biz_123",
        content: %{"type" => "photo", "photo" => "attach://story-photo"},
        active_period: 86_400,
        caption: "Launch"
      },
      %{
        name: "chat_action",
        action: "send_chat_action",
        conversation_id: "tg:123:0",
        chat_action: "typing"
      },
      %{
        name: "reaction",
        action: "set_reaction",
        conversation_id: "tg:123:0",
        message_id: 123,
        reaction: "👍"
      },
      %{
        name: "edit_message",
        action: "edit_message",
        conversation_id: "tg:123:0",
        message_id: 123,
        text: "Updated status",
        buttons: [[%{"text" => "Open", "url" => "https://example.com/"}]]
      },
      %{
        name: "stop_poll",
        action: "stop_poll",
        conversation_id: "tg:123:0",
        message_id: 124,
        buttons: [[%{"text" => "Closed", "callback_data" => "poll_closed"}]]
      },
      %{
        name: "native_checklist",
        action: "send_checklist",
        conversation_id: "tg:123:0",
        business_connection_id: "biz_123",
        title: "Launch",
        tasks: ["Draft", %{"id" => 4, "text" => "Review"}]
      },
      %{
        name: "paid_media",
        action: "send_paid_media",
        conversation_id: "tg:123:0",
        star_count: 5,
        media: [%{"type" => "photo", "media" => "file-paid-photo-id"}],
        payload: "premium-drop-1"
      },
      %{
        name: "invoice",
        action: "send_invoice",
        conversation_id: "tg:123:0",
        title: "Access",
        description: "Premium media access",
        payload: "invoice-1",
        currency: "XTR",
        prices: [%{"label" => "Access", "amount" => 25}],
        buttons: [[%{"text" => "Pay", "pay" => true}]]
      },
      %{
        name: "invoice_link",
        action: "create_invoice_link",
        title: "Access",
        description: "Premium media access",
        payload: "invoice-link-1",
        currency: "XTR",
        prices: [%{"label" => "Access", "amount" => 25}]
      },
      %{
        name: "edit_media",
        action: "edit_media",
        conversation_id: "tg:123:0",
        message_id: 125,
        media_type: "photo",
        media: "file-photo-id"
      },
      %{
        name: "copy_message",
        action: "copy_message",
        conversation_id: "tg:123:0",
        from_chat_id: "@source",
        message_id: 200
      },
      %{
        name: "sticker",
        action: "send_sticker",
        conversation_id: "tg:123:0",
        sticker: "file-sticker-id",
        emoji: "👍"
      },
      %{
        name: "reply_keyboard",
        action: "send",
        conversation_id: "tg:123:0",
        text: "Choose",
        reply_markup: %{
          keyboard: [["Yes", "No"]],
          resize_keyboard: true,
          one_time_keyboard: true
        }
      }
    ]
  end

  @doc "Validate a structured card. Returns `:ok` or `{:error, [error]}`."
  def validate(card, opts \\ %{})

  def validate(card, opts) when is_map(card) do
    errors =
      []
      |> validate_title(card)
      |> validate_inline_fields(card, "card", [:footer])
      |> validate_blocks(blocks(card), "card.blocks", opts)

    if errors == [], do: :ok, else: {:error, Enum.reverse(errors)}
  end

  def validate(_card, _opts),
    do: {:error, [%{path: "card", reason: "card must be an object"}]}

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

  defp validate_title(errors, card) do
    case get(card, :title) do
      nil -> errors
      title when is_binary(title) -> errors
      _ -> [err("card.title", "title must be a string") | errors]
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
      kind
      when kind in [
             "heading",
             "paragraph",
             "quote",
             "pullquote",
             "code",
             "pre",
             "footer",
             "divider",
             "time"
           ] ->
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
          else: [err(path, "thinking blocks are only allowed for streaming drafts") | errors]

      nil ->
        [err("#{path}.kind", "block kind is required") | errors]

      kind ->
        [err("#{path}.kind", "unsupported block kind #{inspect(kind)}") | errors]
    end
  end

  defp validate_block(errors, _block, path, _opts),
    do: [err(path, "block must be an object") | errors]

  defp validate_required_list(errors, block, key, path) do
    case get(block, key) do
      list when is_list(list) and list != [] -> errors
      _ -> [err(path, "must be a non-empty list") | errors]
    end
  end

  defp validate_required_text(errors, block, key, path) do
    case get(block, key) do
      value when is_binary(value) ->
        if blank?(value), do: [err(path, "must be non-empty") | errors], else: errors

      _ ->
        [err(path, "must be a non-empty string") | errors]
    end
  end

  defp validate_media(errors, block, path) do
    kind = get(block, :media_type) || get(block, :type)
    url = get(block, :url)

    cond do
      kind not in @media_kinds ->
        [err("#{path}.media_type", "must be one of #{Enum.join(@media_kinds, ", ")}") | errors]

      not safe_http_url?(url) ->
        [err("#{path}.url", "media URL must be http or https") | errors]

      true ->
        errors
    end
  end

  defp validate_map(errors, block, path) do
    lat = get(block, :latitude)
    lon = get(block, :longitude)

    cond do
      is_nil(lat) ->
        [err("#{path}.latitude", "latitude is required") | errors]

      is_nil(lon) ->
        [err("#{path}.longitude", "longitude is required") | errors]

      not numeric?(lat) ->
        [err("#{path}.latitude", "latitude must be numeric") | errors]

      not numeric?(lon) ->
        [err("#{path}.longitude", "longitude must be numeric") | errors]

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
    do: [err(path, "must be a non-empty list") | errors]

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
        [err("#{path}[#{row_idx}]", "row must be a list") | acc]
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
        [err("#{path}.kind", "unsupported inline kind #{inspect(kind)}") | errors]

      kind in ["link", "url"] and not safe_http_url?(get(value, :url) || get(value, :href)) ->
        [err("#{path}.url", "inline link URL must be http or https") | errors]

      kind == "custom_emoji" and blank?(get(value, :emoji_id) || get(value, :custom_emoji_id)) ->
        [err("#{path}.emoji_id", "custom emoji requires emoji_id") | errors]

      kind in ["date_time"] and is_nil(get(value, :unix) || get(value, :unix_time)) ->
        [err("#{path}.unix", "date_time requires unix") | errors]

      kind == "text_mention" and is_nil(get(value, :user_id)) ->
        [err("#{path}.user_id", "text_mention requires user_id") | errors]

      kind == "mention" and is_nil(get(value, :user_id)) and blank?(get(value, :username)) ->
        [err("#{path}.user_id", "mention requires user_id or username") | errors]

      kind in ["mathematical_expression", "math"] and blank?(inline_expression(value)) ->
        [err("#{path}.expression", "mathematical_expression requires expression") | errors]

      kind in ["email_address", "email"] and
          not valid_email?(get(value, :email_address) || get(value, :email)) ->
        [err("#{path}.email_address", "email_address requires a valid email") | errors]

      kind in ["phone_number", "phone"] and
          blank?(get(value, :phone_number) || get(value, :phone)) ->
        [err("#{path}.phone_number", "phone_number requires phone_number") | errors]

      kind in ["bank_card_number", "bank_card"] and
          blank?(get(value, :bank_card_number) || get(value, :bank_card)) ->
        [err("#{path}.bank_card_number", "bank_card_number requires bank_card_number") | errors]

      kind == "hashtag" and blank?(get(value, :hashtag) || get(value, :tag) || text) ->
        [err("#{path}.hashtag", "hashtag requires hashtag") | errors]

      kind == "cashtag" and blank?(get(value, :cashtag) || get(value, :tag) || text) ->
        [err("#{path}.cashtag", "cashtag requires cashtag") | errors]

      kind == "bot_command" and blank?(get(value, :bot_command) || get(value, :command) || text) ->
        [err("#{path}.bot_command", "bot_command requires bot_command") | errors]

      kind == "anchor" and blank?(get(value, :name)) ->
        [err("#{path}.name", "anchor requires name") | errors]

      kind == "anchor_link" and is_nil(get(value, :anchor_name) || get(value, :name)) ->
        [err("#{path}.anchor_name", "anchor_link requires anchor_name") | errors]

      kind in ["reference", "reference_link"] and
          blank?(get(value, :reference_name) || get(value, :name)) ->
        [err("#{path}.reference_name", "#{kind} requires reference_name") | errors]

      true ->
        validate_inline(errors, text, "#{path}.text")
    end
  end

  defp validate_inline(errors, _value, path),
    do: [err(path, "inline text must be a string, list, or object") | errors]

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

  defp truthy?(value), do: value in [true, "true", 1, "1"]

  defp blank?(value), do: is_nil(value) or String.trim(to_string(value)) == ""

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
  defp err(path, reason), do: %{path: path, reason: reason}
end

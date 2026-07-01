# Blocks

Each block is an object with a `kind`. These examples are valid card fragments.

```json
{"kind": "heading", "level": 2, "text": "Status"}
{"kind": "paragraph", "text": "Plain text can stand alone."}
{"kind": "list", "ordered": true, "items": ["First", "Second"]}
{"kind": "checklist", "items": [{"text": "Draft", "checked": true}]}
{"kind": "table", "headers": ["Item", "State"], "rows": [["Plan", "Ready"]]}
{"kind": "details", "summary": "More", "blocks": [{"kind": "paragraph", "text": "Inside."}]}
{"kind": "quote", "text": "Use the smallest clear answer.", "cite": "example_bot"}
{"kind": "blockquote", "blocks": [{"kind": "paragraph", "text": "Nested quote."}]}
{"kind": "pullquote", "text": "A short highlighted line."}
{"kind": "code", "language": "elixir", "text": "IO.puts(\"ok\")"}
{"kind": "pre", "language": "json", "text": "{\"ok\":true}"}
{"kind": "footer", "text": "Sent by example_bot"}
{"kind": "divider"}
{"kind": "mathematical_expression", "expression": "x^2 + y^2"}
{"kind": "anchor", "name": "top"}
{"kind": "media", "media_type": "photo", "url": "https://example.com/photo.jpg"}
{"kind": "collage", "items": [
  {"kind": "media", "media_type": "photo", "url": "https://example.com/a.jpg"},
  {"kind": "media", "media_type": "photo", "url": "https://example.com/b.jpg"}
]}
{"kind": "slideshow", "slides": [
  {"kind": "media", "media_type": "photo", "url": "https://example.com/slide.jpg"}
]}
{"kind": "references", "items": [{"id": "source-1", "text": "Reference note"}]}
{"kind": "time", "unix": 1800000000, "format": "datetime", "text": "Scheduled time"}
{"kind": "map", "latitude": 41.3874, "longitude": 2.1686, "caption": "Meeting point"}
{"kind": "thinking", "text": "Checking context."}
```

Validation notes:

- `paragraph`, `heading`, `quote`, `pullquote`, `footer`, `code`, and `pre` need non-empty text.
- `list`, `checklist`, `references`, table `headers`, and table `rows` must be non-empty lists.
- Table rows must be lists of cells.
- `media`, `collage` media items, and `slideshow` media slides need safe `http` or `https` URLs.
- `thinking` is only for `stream_card` drafts, never final cards.

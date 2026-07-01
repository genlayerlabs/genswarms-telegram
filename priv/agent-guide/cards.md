# Cards

A card is a JSON object with optional `title`, optional `footer`, optional `buttons`, and a `blocks` list. The card validator returns structured errors with `path`, `reason`, and `hint`; use the hint to repair the exact field and retry.

Minimal send:

```json
{
  "action": "send_card",
  "conversation_id": "tg:123:0",
  "card": {
    "blocks": [
      {"kind": "paragraph", "text": "Here is the concise answer."}
    ]
  }
}
```

Richer card:

```json
{
  "action": "send_card",
  "conversation_id": "tg:123:0",
  "card": {
    "title": "Acme Concierge",
    "blocks": [
      {"kind": "heading", "level": 2, "text": "Daily brief"},
      {"kind": "paragraph", "text": ["Everything is ", {"kind": "bold", "text": "ready"}, "."]},
      {"kind": "checklist", "items": [
        {"text": "Inputs checked", "checked": true},
        {"text": "Final sent", "checked": false}
      ]}
    ],
    "buttons": [[{"text": "Open", "url": "https://example.com/"}]]
  }
}
```

Card rules:

- `blocks` must be a list when present.
- Text blocks that speak to the user need non-empty `text`.
- Button `callback_data` must be 1 to 64 bytes.
- Button and span URLs must use `http` or `https`.
- Final cards must not include `thinking` blocks.
- Use `validate_card` before sending if you are unsure.

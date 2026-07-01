# Spans

Inline text fields may be a string, number, list, or span object. Use lists to mix plain text and rich spans.

```json
[
  "Read ",
  {"kind": "bold", "text": "this"},
  " at ",
  {"kind": "link", "text": "the source", "url": "https://example.com"}
]
```

Supported span kinds include:

- Style: `bold`, `italic`, `underline`, `strikethrough`, `spoiler`, `mark`, `code`, `sub`, `sup`.
- Links: `link`, `url`.
- Identity: `mention`, `text_mention`.
- Telegram entities: `custom_emoji`, `date_time`, `bot_command`, `hashtag`, `cashtag`.
- Structured text: `mathematical_expression`, `math`, `email_address`, `phone_number`, `bank_card_number`.
- Anchors and references: `anchor`, `anchor_link`, `reference`, `reference_link`.

Validation rules:

- Link spans require an `http` or `https` `url` or `href`.
- `custom_emoji` requires `emoji_id`.
- `date_time` requires `unix`.
- `text_mention` requires `user_id`.
- `mention` requires `user_id` or `username`.
- Math spans require `expression`.
- Email spans require a valid email address.
- Phone, bank card, hashtag, cashtag, and bot command spans require their matching value field or non-empty `text`.
- `anchor` requires `name`; `anchor_link` requires `anchor_name` or `name`.
- `reference` and `reference_link` require `reference_name` or `name`.

# Quote-Replies

Inbound message events can include reply context:

```json
{
  "replied_to": {
    "message_id": 19,
    "text": "Please focus on that part of the answer.",
    "quote": {"text": "that part", "position": 16}
  }
}
```

Outbound quote-reply:

```json
{
  "action": "reply",
  "conversation_id": "tg:123:0",
  "reply_to_message_id": 19,
  "quote": "that part",
  "quote_position": 16,
  "quote_parse_mode": "HTML",
  "text": "Replying to that exact phrase."
}
```

Rules:

- `quote`, `quote_position`, and `quote_parse_mode` are only emitted when `reply_to_message_id` is valid.
- If quote fields are present without `reply_to_message_id`, the package drops the quote fields instead of sending invalid Telegram payloads.
- Quote only text from the message you are replying to in the current conversation. Do not construct quotes for unseen messages or other conversations.
- Use inbound `replied_to.quote.text` when it exists; otherwise quote a substring you can see in `replied_to.text`.

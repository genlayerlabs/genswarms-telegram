# Streaming

Use streaming for visible work-in-progress in a live chat. Use a normal send when the answer is already known, short, or should be persistent immediately.

`stream_text`:

```json
{
  "action": "stream_text",
  "conversation_id": "tg:123:0",
  "draft_id": 1,
  "text": "Checking the current context..."
}
```

`stream_card`:

```json
{
  "action": "stream_card",
  "conversation_id": "tg:123:0",
  "draft_id": 1,
  "card": {
    "blocks": [
      {"kind": "thinking", "text": "Checking the current context."},
      {"kind": "checklist", "items": [{"text": "Read input", "checked": true}]}
    ]
  }
}
```

Rules:

- `draft_id` must be a non-zero integer.
- Draft cards may include `thinking` blocks.
- Final cards must not include `thinking` blocks.
- Follow a stream with a persistent `send`, `reply`, or `send_card` when the final answer is ready.
- Reuse the same `draft_id` while updating the same draft.

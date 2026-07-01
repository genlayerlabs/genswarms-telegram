# GenSwarms Telegram Agent Guide

Use these files when authoring Telegram messages from an agent sandbox:

- `cards.md`: card shape, `send_card`, and a minimal-to-rich path.
- `blocks.md`: every supported card block with a tiny valid example.
- `spans.md`: inline rich-text spans and the validation rules that matter.
- `media.md`: media blocks and native Telegram media actions.
- `streaming.md`: `stream_text`, `stream_card`, draft ids, and final sends.
- `quotes.md`: quote-replies and the reply privacy rule.

To discover the current runtime surface, call the `capabilities` action. To copy known-good payloads, call the `examples` action.

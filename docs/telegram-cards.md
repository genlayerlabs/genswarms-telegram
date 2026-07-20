# Telegram Cards

`Genswarms.Telegram.Objects.Sender` exposes a safe card interface for agents.
Agents should prefer structured cards over raw Telegram HTML. The sender
validates cards, renders Telegram rich messages, dispatches through the package
client seam, and returns structured errors before Telegram is called when input
is invalid.

## Agent-Facing Actions

- `capabilities` - return supported delivery modes, blocks, media, and
  interactions.
- `examples` - return compact machine-readable examples.
- `validate_card` - validate a card without sending anything.
- `stream_text` - stream an ephemeral plain-text draft with Telegram
  `sendMessageDraft`.
- `answer_callback` - answer an inline-keyboard callback query and clear the
  Telegram client spinner.
- `answer_web_app` - answer a Web App query with a raw `InlineQueryResult`.
- `answer_inline_query` - answer inline mode with 1-50 raw
  `InlineQueryResult` objects.
- `answer_guest_query` - answer a Telegram guest message query with a raw
  `InlineQueryResult`.
- `save_prepared_inline_message` - store a Mini App prepared inline message for
  a target user.
- `save_prepared_keyboard_button` - store a Mini App keyboard button for a
  target user.
- `get_user_chat_boosts` / `get_business_connection` - inspect chat boosts and
  business connection state.
- `get_managed_bot_token` / `replace_managed_bot_token` /
  `get_managed_bot_access_settings` / `set_managed_bot_access_settings` /
  `get_user_personal_chat_messages` - manage or inspect Telegram managed-bot
  state. These actions require host policy because they expose or rotate bot
  credentials and account access.
- `set_my_commands` / `delete_my_commands` / `get_my_commands` /
  `set_my_name` / `get_my_name` / `set_my_description` /
  `get_my_description` / `set_my_short_description` /
  `get_my_short_description` / `set_my_profile_photo` /
  `remove_my_profile_photo` / `set_chat_menu_button` /
  `get_chat_menu_button` / `set_my_default_administrator_rights` /
  `get_my_default_administrator_rights` - configure bot profile, commands,
  menu, and default administrator rights.
- `post_story` / `repost_story` / `edit_story` / `delete_story` - manage
  Telegram stories for a managed business account with `can_manage_stories`.
- Chat administration actions: `ban_chat_member`, `unban_chat_member`,
  `restrict_chat_member`, `promote_chat_member`,
  `set_chat_administrator_custom_title`, `set_chat_member_tag`,
  `ban_chat_sender_chat`, `unban_chat_sender_chat`, `set_chat_permissions`,
  invite link creation/edit/revoke, join request approval/decline/query Mini
  App handling, chat photo/title/description/pin/unpin/info reads, chat sticker
  set controls, and message reaction deletion.
- Forum actions: `get_forum_topic_icon_stickers`, `create_forum_topic`,
  `edit_forum_topic`, `close_forum_topic`, `reopen_forum_topic`,
  `delete_forum_topic`, `unpin_all_forum_topic_messages`, and general topic
  close/reopen/hide/unhide/unpin controls.
- Utility actions: `get_file`, `get_user_profile_photos`,
  `get_user_profile_audios`, and `set_user_emoji_status`.
- Infrastructure client helpers include `getMe`, `getUpdates`, `setWebhook`,
  `deleteWebhook`, `getWebhookInfo`, `logOut`, and `close`; these are exposed
  by the client layer and cataloged separately from normal message/card sends.
- Sticker-set actions: `get_sticker_set`, `get_custom_emoji_stickers`,
  `upload_sticker_file`, `create_new_sticker_set`, `add_sticker_to_set`,
  `replace_sticker_in_set`, `delete_sticker_from_set`,
  `set_sticker_emoji_list`, `set_sticker_keywords`,
  `set_sticker_mask_position`, `set_sticker_set_title`,
  `set_sticker_set_thumbnail`, `set_custom_emoji_sticker_set_thumbnail`, and
  `delete_sticker_set`.
- `send_card` - render and send a structured rich card.
- `stream_card` - render and send an ephemeral rich draft with `draft_id`.
- `edit_card` - render and edit an existing rich/text message.
- `edit_message` - edit an existing text message with optional inline buttons.
- `edit_caption` - edit a media message caption with optional inline buttons.
- `edit_media` - replace media on an existing media message.
- `edit_live_location` - move an existing live-location message.
- `stop_live_location` - stop an existing live-location message.
- `edit_reply_markup` - edit or clear an existing message's inline buttons.
- `copy_message` / `copy_messages` - copy one or more existing Telegram
  messages into the target conversation.
- `forward_message` / `forward_messages` - forward one or more existing
  Telegram messages into the target conversation.
- `delete_message` / `delete_messages` - delete one or more bot-manageable
  Telegram messages.
- `send_media` - send photo, video, animation, audio, voice, or document media.
- `send_live_photo` - send a Telegram live photo from reusable file IDs or upload references.
- `send_video_note` - send a Telegram round video note from a reusable file ID or upload reference.
- `send_sticker` - send a static, animated, or video Telegram sticker by file
  ID, upload reference, or supported URL.
- `send_media_group` - send a 2-10 item media album.
- `send_paid_media` - send Telegram Stars-gated media. Host policy should
  approve monetized sends.
- `send_poll` - send a poll/quiz-style workflow message, including current Bot
  API poll options such as media, descriptions, revoting, shuffling, member
  gates, and multiple quiz correct answers.
- `stop_poll` - stop a bot-created poll and optionally replace its inline
  buttons.
- `send_checklist` - send a native Telegram interactive checklist on behalf of
  a connected business account.
- `edit_checklist` - replace a native Telegram checklist on behalf of a
  connected business account.
- `send_invoice` - send a Telegram invoice. Host policy should approve payment
  flows before agents use it.
- `get_my_star_balance` / `get_star_transactions` - inspect the bot's Telegram
  Stars balance and transaction ledger.
- `get_available_gifts` / `send_gift` / `gift_premium_subscription` - inspect
  sendable gifts, send gifts, or gift Telegram Premium subscriptions.
- `get_business_account_star_balance` / `transfer_business_account_stars` -
  inspect or transfer Stars for a managed business account with the required
  business bot rights.
- `get_business_account_gifts` / `get_user_gifts` / `get_chat_gifts` - inspect
  owned gifts with Telegram's gift filters and pagination.
- `convert_gift_to_stars` / `upgrade_gift` / `transfer_gift` - manage owned
  gifts for a business account. These are money-moving/business-scoped actions
  and should be host-gated.
- `verify_user` / `verify_chat` / `remove_user_verification` /
  `remove_chat_verification` - manage organization verification represented by
  the bot.
- `read_business_message` / `delete_business_messages` /
  `set_business_account_name` / `set_business_account_username` /
  `set_business_account_bio` / `set_business_account_profile_photo` /
  `remove_business_account_profile_photo` /
  `set_business_account_gift_settings` - manage business account state with the
  relevant Telegram business bot rights.
- `approve_suggested_post` / `decline_suggested_post` - decide suggested posts
  in channel direct-message chats.
- `set_passport_data_errors` - report Telegram Passport validation errors.
- `set_game_score` / `get_game_high_scores` - manage BotFather game scoreboards.
- `send_game` - send a BotFather-configured Telegram game.
- `send_location` - send a Telegram location with numeric latitude/longitude.
- `send_venue` - send a Telegram venue with coordinates, title, and address.
- `send_contact` - send a Telegram contact card.
- `send_dice` - send Telegram's native random animated emoji/dice message.
- `send_chat_action` - send a one-shot Telegram status such as `typing`,
  `upload_photo`, or `find_location`.
- `set_reaction` - set or clear one non-paid reaction on a target message.
- `send_rich_raw` - expert escape hatch for prebuilt `InputRichMessage`.

## Structured Card Shape

```json
{
  "action": "send_card",
  "conversation_id": "tg:123:0",
  "card": {
    "title": "Welcome",
    "blocks": [
      {"kind": "paragraph", "text": "Your instance is ready."},
      {"kind": "media", "media_type": "animation", "url": "https://example.com/boot.mp4"},
      {
        "kind": "details",
        "summary": "What can I do?",
        "blocks": [{"kind": "list", "items": ["campaigns", "drafts", "budget"]}]
      }
    ],
    "buttons": [[{"text": "Open", "url": "https://example.com/"}]]
  }
}
```

Supported blocks:

- `heading`
- `paragraph`
- `list`
- `checklist`
- `table`
- `details`
- `quote`
- `blockquote`
- `pullquote`
- `code`
- `pre`
- `footer`
- `divider`
- `mathematical_expression` / `math`
- `anchor`
- `media`
- `collage`
- `slideshow`
- `references`
- `time`
- `map`
- `thinking` for drafts only

Inline text fields can be either a plain string or a list of text/spans:

```json
[
  "Open ",
  {"kind": "bold", "text": "report"},
  " at ",
  {"kind": "link", "text": "example.com", "url": "https://example.com/"}
]
```

Supported inline span kinds:

- `bold`
- `italic`
- `underline`
- `strikethrough`
- `spoiler`
- `mark`
- `code`
- `sub` / `subscript`
- `sup` / `superscript`
- `link` / `url`
- `custom_emoji`
- `date_time`
- `mention` with either `user_id` or `username`
- `text_mention` with `user_id`
- `mathematical_expression` / `math`
- `email_address` / `email`
- `phone_number` / `phone`
- `bank_card_number` / `bank_card`
- `hashtag`
- `cashtag`
- `bot_command`
- `anchor`
- `anchor_link`
- `reference`
- `reference_link`

## Inline And Web App Responses

Inline/Web App actions answer Telegram query IDs rather than sending directly to
a `conversation_id`. Raw `InlineQueryResult` objects are accepted so the package
does not lag behind Telegram's many inline result subtypes; the package still
validates the common required `type` and `id` fields before dispatch.

```json
{
  "action": "answer_callback",
  "callback_query_id": "cb_123",
  "text": "Done",
  "show_alert": false
}
```

```json
{
  "action": "answer_inline_query",
  "inline_query_id": "inline_123",
  "results": [
    {
      "type": "article",
      "id": "status",
      "title": "Status",
      "input_message_content": {"message_text": "Ready"}
    }
  ],
  "is_personal": true
}
```

```json
{
  "action": "answer_web_app",
  "web_app_query_id": "web_123",
  "result": {
    "type": "article",
    "id": "web-status",
    "title": "Status",
    "input_message_content": {"message_text": "Ready"}
  }
}
```

```json
{
  "action": "save_prepared_inline_message",
  "user_id": 123,
  "result": {
    "type": "article",
    "id": "prepared-status",
    "title": "Status",
    "input_message_content": {"message_text": "Ready"}
  },
  "allow_user_chats": true
}
```

```json
{
  "action": "save_prepared_keyboard_button",
  "user_id": 123,
  "button": {
    "text": "Choose user",
    "request_users": {"request_id": 1}
  }
}
```

Rendering follows Telegram rich-message HTML:

- `map` renders as `<tg-map lat="..." long="..." zoom="..."/>` and requires
  numeric `latitude` and `longitude`.
- `time` renders as `<tg-time unix="..." format="...">...</tg-time>`.
- `mathematical_expression` renders as `<tg-math-block>...</tg-math-block>`.
- Inline `mathematical_expression` renders as `<tg-math>...</tg-math>`.
- `anchor` renders as `<a name="..."></a>` and `anchor_link` links to
  `#name`.
- `reference` renders as `<tg-reference name="...">...</tg-reference>` and
  `reference_link` links to `#name`.
- `checklist` renders list items with `<input type="checkbox">`.
- Media captions wrap media in `<figure>...<figcaption>...</figcaption></figure>`.
- Slideshows and collages accept Telegram-style `blocks`; legacy `slides` and
  `items` remain supported for compatibility. The renderer does not introduce
  unsupported wrapper tags.

## Buttons

Inline buttons are normalized from agent JSON and invalid buttons are dropped.
Supported button forms:

- `{"text":"Open","url":"https://example.com"}`
- `{"text":"Action","callback_data":"mode quiet"}`
- `{"text":"Action","action":"mode quiet"}` as a callback alias
- `{"text":"App","web_app":{"url":"https://example.com/app"}}`
- `{"text":"Search","switch_inline_query":"query"}`
- `{"text":"Search here","switch_inline_query_current_chat":"query"}`
- `{"text":"Choose","switch_inline_query_chosen_chat":{"query":"query","allow_user_chats":true}}`
- `{"text":"Copy","copy_text":{"text":"copy me"}}`
- `{"text":"Pay","pay":true}` for invoice contexts

For full Telegram reply markup, use `reply_markup` instead of `buttons`.
Supported safe forms:

```json
{
  "reply_markup": {
    "keyboard": [
      ["Yes", "No"],
      [{"text": "Share location", "request_location": true}],
      [{"text": "Open app", "web_app": {"url": "https://example.com/app"}}]
    ],
    "resize_keyboard": true,
    "one_time_keyboard": true,
    "input_field_placeholder": "Choose"
  }
}
```

```json
{"reply_markup": {"remove_keyboard": true}}
```

```json
{"reply_markup": {"force_reply": true, "input_field_placeholder": "Reply"}}
```

Reply keyboard buttons support text, `icon_custom_emoji_id`, `style`
(`danger`, `success`, or `primary`), `request_contact`, `request_location`,
`request_poll`, and `web_app`. A reply-keyboard button can specify at most one
action among contact, location, poll, or Web App.

## Drafts

`stream_text` uses Telegram `sendMessageDraft`. `stream_card` uses Telegram
`sendRichMessageDraft`. Drafts are ephemeral previews and should be followed by a
final `send`, `send_card`, or `edit_card`. Draft IDs must be non-zero. `thinking`
blocks are only accepted when rendering a rich draft.

```json
{
  "action": "stream_text",
  "conversation_id": "tg:123:0",
  "draft_id": 41,
  "text": "Checking campaign state..."
}
```

```json
{
  "action": "stream_card",
  "conversation_id": "tg:123:0",
  "draft_id": 42,
  "card": {
    "blocks": [
      {"kind": "thinking", "text": "Checking campaign state..."}
    ]
  }
}
```

## Editing Messages

Telegram edit methods and `stopPoll` only accept inline keyboards as
`reply_markup`. Use `buttons` or an explicit `{"inline_keyboard": ...}` shape;
reply keyboards, keyboard removal, and force-reply prompts are send-only.

```json
{
  "action": "edit_message",
  "conversation_id": "tg:123:0",
  "message_id": 123,
  "text": "Updated status",
  "buttons": [[{"text": "Open", "url": "https://example.com/"}]]
}
```

```json
{
  "action": "edit_caption",
  "conversation_id": "tg:123:0",
  "message_id": 124,
  "caption": "Updated media caption"
}
```

```json
{
  "action": "edit_reply_markup",
  "conversation_id": "tg:123:0",
  "message_id": 125,
  "buttons": [[{"text": "Done", "callback_data": "done"}]]
}
```

```json
{
  "action": "stop_poll",
  "conversation_id": "tg:123:0",
  "message_id": 126,
  "buttons": [[{"text": "Closed", "callback_data": "poll_closed"}]]
}
```

```json
{
  "action": "edit_media",
  "conversation_id": "tg:123:0",
  "message_id": 127,
  "media_type": "photo",
  "media": "file-photo-id",
  "buttons": [[{"text": "Done", "callback_data": "done"}]]
}
```

```json
{
  "action": "edit_live_location",
  "conversation_id": "tg:123:0",
  "message_id": 128,
  "latitude": 41.3874,
  "longitude": 2.1686
}
```

```json
{
  "action": "stop_live_location",
  "conversation_id": "tg:123:0",
  "message_id": 128
}
```

## Message Lifecycle

Copying preserves the source message content without a forward header.
Forwarding keeps Telegram's forward semantics. Batch copy/forward actions
require sorted, strictly increasing `message_ids` because that is the Bot API
shape. Delete batches accept 1 to 100 message IDs.

```json
{
  "action": "copy_message",
  "conversation_id": "tg:123:0",
  "from_chat_id": "@source_channel",
  "message_id": 200,
  "caption": "Optional replacement caption"
}
```

```json
{
  "action": "forward_messages",
  "conversation_id": "tg:123:0",
  "from_chat_id": "@source_channel",
  "message_ids": [201, 202]
}
```

```json
{
  "action": "delete_messages",
  "conversation_id": "tg:123:0",
  "message_ids": [301, 302]
}
```

## Native Checklists

`card.blocks[].kind = "checklist"` renders a visual rich-message checklist.
`send_checklist` and `edit_checklist` use Telegram's native `InputChecklist`
object. Native checklists require `business_connection_id`; Telegram only sends
or edits them on behalf of a connected business account.

```json
{
  "action": "send_checklist",
  "conversation_id": "tg:123:0",
  "business_connection_id": "biz_123",
  "title": "Launch tasks",
  "tasks": ["Draft", {"id": 4, "text": "Review"}],
  "buttons": [[{"text": "Open", "url": "https://example.com/"}]]
}
```

```json
{
  "action": "edit_checklist",
  "conversation_id": "tg:123:0",
  "message_id": 400,
  "business_connection_id": "biz_123",
  "checklist": {
    "title": "Updated launch tasks",
    "tasks": [{"id": 1, "text": "Ship"}],
    "others_can_add_tasks": true
  }
}
```

Checklist titles must be 1 to 255 characters. Checklist task text must be 1 to
100 characters. Task IDs must be positive and unique; omitted IDs are assigned
by order.

## Monetization Messages

`send_paid_media` and `send_invoice` can cause users to spend Telegram Stars or
external currency. They are implemented with strict payload validation, but
hosts should still gate them with delivery policy before exposing them to an
autonomous agent.

```json
{
  "action": "send_paid_media",
  "conversation_id": "tg:123:0",
  "star_count": 5,
  "media": [{"type": "photo", "media": "file-photo-id"}],
  "payload": "premium-drop-1",
  "caption": "Premium media"
}
```

```json
{
  "action": "send_invoice",
  "conversation_id": "tg:123:0",
  "title": "Access",
  "description": "Premium media access",
  "payload": "invoice-1",
  "currency": "XTR",
  "prices": [{"label": "Access", "amount": 25}],
  "buttons": [[{"text": "Pay", "pay": true}]]
}
```

```json
{
  "action": "send_game",
  "conversation_id": "tg:123:0",
  "game_short_name": "trivia_quest"
}
```

```json
{
  "action": "create_invoice_link",
  "title": "Access",
  "description": "Premium media access",
  "payload": "invoice-link-1",
  "currency": "XTR",
  "prices": [{"label": "Access", "amount": 25}]
}
```

```json
{
  "action": "answer_shipping_query",
  "shipping_query_id": "ship_123",
  "ok": true,
  "shipping_options": [
    {
      "id": "standard",
      "title": "Standard",
      "prices": [{"label": "Shipping", "amount": 5}]
    }
  ]
}
```

```json
{
  "action": "answer_pre_checkout_query",
  "pre_checkout_query_id": "pre_123",
  "ok": false,
  "error_message": "Sold out"
}
```

```json
{
  "action": "refund_star_payment",
  "user_id": 123,
  "telegram_payment_charge_id": "charge_123"
}
```

```json
{
  "action": "edit_user_star_subscription",
  "user_id": 123,
  "telegram_payment_charge_id": "charge_123",
  "is_canceled": true
}
```

```json
{"action": "get_my_star_balance"}
```

```json
{"action": "get_star_transactions", "offset": 0, "limit": 25}
```

```json
{"action": "get_available_gifts"}
```

```json
{
  "action": "send_gift",
  "user_id": 123,
  "gift_id": "gift_123",
  "text": "Enjoy",
  "pay_for_upgrade": true
}
```

```json
{
  "action": "gift_premium_subscription",
  "user_id": 123,
  "month_count": 3,
  "star_count": 1000
}
```

```json
{
  "action": "get_business_account_gifts",
  "business_connection_id": "biz_123",
  "exclude_unsaved": true,
  "sort_by_price": true,
  "limit": 50
}
```

```json
{
  "action": "transfer_gift",
  "business_connection_id": "biz_123",
  "owned_gift_id": "owned_gift_123",
  "new_owner_chat_id": 123,
  "star_count": 0
}
```

```json
{"action": "verify_user", "user_id": 123, "custom_description": "Official"}
```

```json
{"action": "verify_chat", "chat_id": "@channel"}
```

```json
{
  "action": "read_business_message",
  "business_connection_id": "biz_123",
  "chat_id": 123,
  "message_id": 456
}
```

```json
{
  "action": "set_business_account_name",
  "business_connection_id": "biz_123",
  "first_name": "Acme Concierge",
  "last_name": ""
}
```

```json
{
  "action": "set_business_account_gift_settings",
  "business_connection_id": "biz_123",
  "show_gift_button": true,
  "accepted_gift_types": {
    "unlimited_gifts": true,
    "limited_gifts": false,
    "unique_gifts": true,
    "premium_subscription": false
  }
}
```

```json
{
  "action": "answer_guest_query",
  "guest_query_id": "guest_123",
  "result": {
    "type": "article",
    "id": "status",
    "title": "Status",
    "input_message_content": {"message_text": "Ready"}
  }
}
```

```json
{"action": "get_managed_bot_token", "user_id": 123}
```

```json
{
  "action": "set_managed_bot_access_settings",
  "user_id": 123,
  "is_access_restricted": true,
  "added_user_ids": [456]
}
```

```json
{"action": "get_user_personal_chat_messages", "user_id": 123, "limit": 5}
```

```json
{
  "action": "set_my_commands",
  "commands": [{"command": "start", "description": "Start the bot"}],
  "language_code": "en"
}
```

```json
{"action": "set_my_name", "name": "Acme Concierge"}
```

```json
{"action": "set_my_description", "description": "support assistant"}
```

```json
{
  "action": "set_chat_menu_button",
  "chat_id": 123,
  "menu_button": {"type": "commands"}
}
```

```json
{
  "action": "set_my_default_administrator_rights",
  "rights": {"can_delete_messages": true},
  "for_channels": true
}
```

```json
{"action": "approve_suggested_post", "chat_id": 123, "message_id": 456}
```

```json
{
  "action": "set_passport_data_errors",
  "user_id": 123,
  "errors": [
    {
      "source": "data",
      "type": "personal_details",
      "field_name": "first_name",
      "data_hash": "hash",
      "message": "Invalid first name"
    }
  ]
}
```

```json
{
  "action": "set_game_score",
  "user_id": 123,
  "score": 42,
  "chat_id": "@gamechat",
  "message_id": 456
}
```

Paid media requires 1 to 25,000 Telegram Stars and 1 to 10 media items. Invoice
payloads must be 1 to 128 bytes. Telegram Stars invoices use currency `XTR` and
exactly one labeled price. If an invoice includes inline buttons, the first
button must be a Pay button. Gift text is limited to 128 characters.
`gift_premium_subscription` must use Telegram's official month/Stars pairs:
3/1000, 6/1500, or 12/2500. Business Star transfers are limited to 1-10,000
Stars, and gift list `limit` values are limited to 1-100. Pre-checkout queries
must be answered within Telegram's 10 second window.

## Stories

Story actions require a managed business account and Telegram's
`can_manage_stories` business bot right. Story content supports Telegram's
`InputStoryContentPhoto` and `InputStoryContentVideo`. Story media must use
upload references such as `attach://story-photo`; Telegram does not let story
media be reused like ordinary file IDs.

```json
{
  "action": "post_story",
  "business_connection_id": "biz_123",
  "content": {"type": "photo", "photo": "attach://story-photo"},
  "active_period": 86400,
  "caption": "Launch"
}
```

```json
{
  "action": "repost_story",
  "business_connection_id": "biz_123",
  "from_chat_id": -100123,
  "from_story_id": 12,
  "active_period": 43200
}
```

```json
{
  "action": "edit_story",
  "business_connection_id": "biz_123",
  "story_id": 13,
  "content": {"type": "video", "video": "attach://story-video"}
}
```

```json
{
  "action": "delete_story",
  "business_connection_id": "biz_123",
  "story_id": 14
}
```

Valid `active_period` values are `21600`, `43200`, `86400`, and `172800`.

## Validation Rules

The package validates common Telegram constraints before sending:

- Media URLs in rich cards must be `http` or `https`.
- Inline link URLs must be `http` or `https`.
- Inline custom emoji spans require `emoji_id`.
- Inline date-time spans require `unix`.
- Inline text mentions require `user_id`.
- Inline username mentions require `username`; legacy `mention` with `user_id`
  remains supported.
- Inline math spans and math blocks require `expression`.
- Inline email spans require a valid email address.
- Anchor/reference spans require stable names.
- Rich messages must contain exactly one of `html` or `markdown`.
- `answer_callback` text must be 0 to 200 characters.
- Inline query answers require 1 to 50 raw `InlineQueryResult` objects.
- Raw `InlineQueryResult` objects require non-empty `type` and `id`.
- Inline query `next_offset` must be 0 to 64 bytes.
- Prepared keyboard buttons require exactly one of `request_users`,
  `request_chat`, or `request_managed_bot`.
- Story actions require `business_connection_id`.
- Story `active_period` must be `21600`, `43200`, `86400`, or `172800`.
- Story content supports `photo` or `video`; video duration and cover timestamp
  must be 0 to 60 seconds when present.
- `thinking` blocks are draft-only.
- Polls require 1 to 12 options.
- Quiz polls use `correct_option_ids`; legacy single `correct_option_id` input
  is normalized to a one-item list.
- Callback button data must be at most 64 bytes.
- Unsafe button URLs are rejected.
- Web App button URLs must be `http` or `https`.
- Switch-inline query and copy-text payloads must be at most 256 bytes.
- Reply markup accepts `inline_keyboard`, `keyboard`, `remove_keyboard`, or
  `force_reply`.
- Edit actions and `stop_poll` accept inline-keyboard reply markup only.
- Copy/forward batches require 1 to 100 sorted, strictly increasing
  `message_ids`.
- Delete batches require 1 to 100 `message_ids`.
- `edit_media` accepts `photo`, `video`, `animation`, `audio`, `document`, or
  `live_photo` media.
- Native checklists require `business_connection_id`, a 1-255 character title,
  and 1 to 30 tasks.
- Native checklist task IDs must be positive and unique; task text must be 1 to
  100 characters.
- Paid media requires 1 to 25,000 Telegram Stars and 1 to 10 paid media items.
- Paid media payloads must be 0 to 128 bytes.
- Invoices require title, description, payload, currency, and at least one
  labeled price.
- Telegram Stars invoices use currency `XTR` and exactly one labeled price.
- Subscription invoice links require currency `XTR` and
  `subscription_period: 2592000`.
- Shipping query answers require `shipping_options` when `ok` is `true` and
  `error_message` when `ok` is `false`.
- Pre-checkout failures require `error_message`.
- Star transaction and gift list `limit` values must be 1 to 100.
- `send_gift` requires exactly one of `user_id` or `chat_id`; gift text must be
  0 to 128 characters.
- Premium gifts require one of Telegram's fixed month/Stars pairs: 3/1000,
  6/1500, or 12/2500.
- Business Star transfers require `business_connection_id` and 1 to 10,000
  Stars.
- Gift conversion, upgrade, and transfer require `owned_gift_id` and the
  relevant Telegram business bot rights.
- Organization verification descriptions must be 0 to 70 characters.
- Business message reads require `business_connection_id`, `chat_id`, and
  `message_id`; business message deletes require 1 to 100 `message_ids`.
- Business account names are 1 to 64 characters for `first_name` and 0 to 64
  for `last_name`; usernames are 0 to 32 characters; bios are 0 to 140
  characters.
- Business account profile photo changes require a non-empty
  `InputProfilePhoto` object.
- Business gift settings require `show_gift_button` and an
  `accepted_gift_types` object containing at least one accepted gift type.
- Guest query answers require a raw `InlineQueryResult` object with non-empty
  `type` and `id`.
- Managed bot access settings accept at most 10 `added_user_ids`.
- User personal chat message reads require `limit` 1 to 20.
- Bot commands require 1 to 100 commands. Command names must be 1 to 32
  lowercase letters, digits, or underscores; descriptions must be 1 to 256
  characters.
- Bot profile names are 0 to 64 characters, descriptions 0 to 512, and short
  descriptions 0 to 120.
- Bot profile photos require a non-empty `InputProfilePhoto` object.
- Bot menu buttons and default administrator rights use raw Telegram objects.
- Suggested post decline comments must be 0 to 128 characters.
- Passport data errors require `user_id` and at least one error with `source`,
  `type`, and `message`.
- Game scores require a non-negative `score` and either `inline_message_id` or
  `chat_id` with `message_id`.
- Star refunds and subscription edits require `user_id` and
  `telegram_payment_charge_id`.
- Invoice inline keyboards must start with a Pay button.
- Games require a `game_short_name` configured via BotFather.
- Reply keyboard Web App URLs must be `http` or `https`.
- Reply keyboard input placeholders must be 1 to 64 characters.
- Media groups require 2 to 10 `photo`, `video`, `audio`, `document`, or
  `live_photo` items with non-empty `media`.
- Stickers require a non-empty `sticker` value. Prefer Telegram file IDs or
  upload references; Telegram only fetches static `.WEBP` stickers from public
  HTTP URLs.
- Video notes and live photos use file IDs or upload references; Telegram does
  not support public URL fetching for video notes.
- Locations and venues require numeric `latitude` and `longitude`.
- Venues require non-empty `title` and `address`.
- Contacts require non-empty `phone_number` and `first_name`.
- Chat actions must be one of Telegram's supported `sendChatAction` values:
  `typing`, `upload_photo`, `record_video`, `upload_video`, `record_voice`,
  `upload_voice`, `upload_document`, `choose_sticker`, `find_location`,
  `record_video_note`, or `upload_video_note`.
- Reactions accept a single emoji reaction string, a single
  `{"type":"emoji","emoji":"..."}` object, a single
  `{"type":"custom_emoji","custom_emoji_id":"..."}` object, or `[]` to clear.
  Paid reactions are rejected.
- Reaction deletion accepts at most one actor selector: `user_id` or
  `actor_chat_id`.
- Chat admin and forum actions require the corresponding Telegram administrator
  rights in the target chat; the package validates payload shape but cannot
  grant those permissions.
- Invite link names are 0 to 32 characters. Subscription invite links require
  `subscription_period` of `2592000` and a `subscription_price` from 1 to 10000
  Stars.
- Join request query handling accepts `approve`, `decline`, or `queue`; Mini App
  handoff requires an HTTP(S) `web_app_url`.
- Forum topic names are 1 to 128 characters when creating topics; `icon_color`
  must be one of Telegram's supported topic color constants.
- `get_file` requires a non-empty `file_id`; user profile photo/audio queries
  accept `limit` from 1 to 100.
- Sticker file upload requires `sticker_format` of `static`, `animated`, or
  `video`; sticker sets require 1 to 50 `InputSticker` objects.
- Sticker emoji lists accept 1 to 20 values, and keyword lists accept 0 to 20
  values.

Errors are path-oriented so agents can recover:

```json
{
  "ok": false,
  "error": "invalid_card",
  "errors": [
    {"path": "card.blocks[0].url", "reason": "media URL must be http or https"}
  ]
}
```

## Raw Rich Escape Hatch

Raw rich messages are supported for expert callers, but they should not be the
default agent path.

```json
{
  "action": "send_rich_raw",
  "conversation_id": "tg:123:0",
  "rich_message": {"html": "<h3>Raw card</h3><p>Use carefully.</p>"}
}
```

## Prepared But Restricted

The package capability catalog names Telegram areas that are intentionally not
exposed as normal agent actions yet: admin chat management, business-account
management, managed bots, inline query answers, and Telegram Passport. These
need host-level policy, credentials, or permissions before they can be made
agent-safe. Monetized and story actions are implemented, but should be
host-gated with delivery policy.

## Watermarking

Watermarking is intentionally not part of card delivery. Telegram does not layer
watermarks over media. A future media preprocessor should render watermarks into
image/video bytes before the sender receives the final media URL.

## Previewing Rich Messages

The sibling `editor/` package (`genswarms_telegram_editor`, same repo, same
tag) ships a faithful browser preview of everything `Card.to_rich_message/2`
can emit, plus a generic editor shell. Hosts serve its `priv/preview/`
assets, provide a validate+render endpoint, and attest at boot that the
editor's `supported_schema/0` matches `Card.schema_info().version`. The
tag vocabulary contract lives in `editor/priv/tags.json`; the
`card_editor_contract_test` keeps generator and preview locked in one CI
run. See `editor/README.md`.

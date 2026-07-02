# GenSwarms Telegram

Reusable Telegram transport and GenSwarms object handlers.

The package gives a swarm Telegram ingress and sender objects without product
persona, private policy, quota logic, or domain commands.

## Install

```elixir
def deps do
  [
    {:genswarms_telegram, github: "genlayerlabs/genswarms-telegram", tag: "v0.2.0"}
  ]
end
```

Runtime tools used by defaults:

- `curl` for `Genswarms.Telegram.Client.Curl`;
- `jq` and `swarm-msg` for `priv/reply.sh`.

This is a GenSwarms handler package. `genswarms` is a peer/runtime dependency
provided by the host app; the default session runtime calls GenSwarms modules
dynamically when `session_opts.swarm_name` and `session_opts.agent_template` are
used. Consumers that do not want dynamic GenSwarms spawning can inject their own
`deliver` function or replace the session runtime.

## What Importers Get

- `Genswarms.Telegram.Objects.Ingress` — GenSwarms-native Telegram ingress handler
  with `inject_update`, optional `getUpdates` long polling, update dedupe, webhook
  forwarding support, callback acking, group addressing gates, identity hooks, and
  per-conversation session delivery through an injected runtime. Command-router
  replies are sent through Telegram before the update is marked processed.
- `Genswarms.Telegram.Objects.Sender` — outbound Telegram handler with slot-to-chat
  binding, fail-closed agent replies, async bounded `send_batch`, typing keepalive,
  owed-turn duplicate reply suppression, progress edit coalescing, inline keyboards,
  photo fallback, text/rich draft streaming, rich cards,
  media/poll/place/contact/dice delivery, live photo, video note, media group
  delivery, rate-limited chunking, parse-error plain-text retry, recent
  reply-tag validation, and a bounded audit trail.
- `Genswarms.Telegram.Client.Curl` — default shell-native Bot API adapter. It keeps
  bot tokens out of argv by using short-lived curl config/body files.
- `Genswarms.Telegram.Client.Fake` — deterministic test adapter.
- `Genswarms.Telegram.Poller` and `OffsetFile` — pure `getUpdates` offset/payload
  helpers, including a single-file offset adapter for hosts with existing state.
- `Genswarms.Telegram.Parser`, `Delivery`, `Buttons`, `Capabilities`, `Card`,
  `RichMessage`, `Addressing`, `SpamGuard`, `Format`, `ConversationId`,
  `Webhook` — pure Telegram update, payload, button, capability catalog,
  structured card, rich-message, addressing, spam-guard, formatting, id, webhook
  decode, and webhook registration helpers.
- `Genswarms.Telegram.Store.File` and `Context.MemoryMd` — minimal local
  adapters for bot transport state and optional durable per-conversation
  `MEMORY.md`.
- `priv/reply.sh` — agent reply helper using `GENSWARMS_TELEGRAM_CONVERSATION_ID`
  and `GENSWARMS_TELEGRAM_SENDER_OBJECT`. The helper does not include a Telegram
  target in the payload; the sender must resolve the target from the caller's bound
  slot identity.

## What Hosts Provide

The host swarm still owns product commands, persona, policy/privacy objects,
durable application databases, quota/accounting, dashboard sources, and any
product-specific webhooks. The package exposes behaviours for those boundaries.

`Genswarms.Telegram.SessionRuntime.Default` can either call an injected
`session_opts.deliver` function or, when used inside a GenSwarms app, use
`session_opts.swarm_name` plus `session_opts.agent_template` to call
`Genswarms.SwarmManager` / `Genswarms.Agents.AgentServer` dynamically. The
default runtime uses a bounded opaque slot pool; if a slot is reused it unbinds
the previous conversation before binding the new one. GenSwarms object binding is
serialized with an object-state barrier before user text is delivered. Production
systems can replace the runtime when they need a different persistence, spawn, or
eviction policy.

## Defaults

- App: `:genswarms_telegram`
- Modules: `Genswarms.Telegram.*`
- Swarmidx ref: `swarmidx:acastellana/genswarms-telegram@0.2.0` will be
  published during the gated release step; registry publish and the `v0.2.0`
  Git tag are not created by this prep branch.
- Sender object: `:telegram_sender`
- Ingress object: `:telegram_ingress`
- Agent conversation env: `GENSWARMS_TELEGRAM_CONVERSATION_ID`
- Reply helper sender env: `GENSWARMS_TELEGRAM_SENDER_OBJECT`
- Linux state dir: `${XDG_STATE_HOME:-$HOME/.local/state}/genswarms/telegram`
- Workspace root: `${TMPDIR:-/tmp}/genswarms-telegram`
- Memory policy: `:none` by default; use `memory_policy: :dm_only` or
  `memory_policy: :all` with `Context.MemoryMd` to persist conversation context.

## Client Adapters

`Genswarms.Telegram.Client.Curl` is the default runtime adapter. It keeps bot
tokens out of argv by writing the Telegram URL to a short-lived curl config file.

`Genswarms.Telegram.Client.Fake` is the test adapter and records Bot API calls
without network access.

Normal CI should use `Client.Fake`. Live Telegram smoke tests should be explicit
release checks with disposable credentials, because `getUpdates` is single-consumer
per bot token.

## Security Model

Agents do not choose Telegram targets. Sender binds an opaque slot to a
conversation id and forces replies from that slot back to the bound conversation.
Agent-like unbound slots fail closed. Explicit `conversation_id` targets are
accepted only from configured sender sources such as the ingress object or batch
senders. This assumes replies arrive at the sender from the GenSwarms agent slot
identity; shell helpers must be executed inside that bound agent context. In the
default GenSwarms runtime, ingress performs the sender binding before delivering
user text to the agent.

Durable `MEMORY.md` files live outside reusable slot workspaces:

```text
<state_dir>/<bot_fingerprint>/conversations/<encoded_conversation_id>/MEMORY.md
```

The agent can see a copy at `<workspace>/MEMORY.md`, but slot workspaces are
temporary and can be wiped safely.

By default, `Ingress` uses `memory_policy: :none`, so no durable `MEMORY.md`
files are created unless the host opts in. `memory_policy: :dm_only` persists
only private chats; `memory_policy: :all` also persists group and topic context.

## Object Protocol

Ingress:

- `{"action":"inject_update","update":{...}}`
- `{"action":"status"}`

Sender:

- `{"action":"reply","text":"...","reply_to_message_id":123}`
- `{"action":"send","conversation_id":"tg:123:0","text":"..."}`
- `{"action":"send","conversation_id":"tg:123:0","text":"Choose","reply_markup":{"keyboard":[["Yes","No"]],"resize_keyboard":true}}`
- `{"action":"send_batch","recipients":[{"conversation_id":"tg:123:0"}],"text":"..."}`
- `{"action":"progress","text":"...","conversation_id":"tg:123:0"}`
- `{"action":"typing","conversation_id":"tg:123:0","message_id":123}`
- `{"action":"capabilities"}`
- `{"action":"examples"}`
- `{"action":"validate_card","card":{"title":"...","blocks":[...]}}`
- `{"action":"stream_text","conversation_id":"tg:123:0","draft_id":123,"text":"Working..."}`
- `{"action":"answer_callback","callback_query_id":"cb_123","text":"Done"}`
- `{"action":"answer_inline_query","inline_query_id":"inline_123","results":[{"type":"article","id":"status","title":"Status","input_message_content":{"message_text":"Ready"}}]}`
- `{"action":"answer_web_app","web_app_query_id":"web_123","result":{"type":"article","id":"status","title":"Status","input_message_content":{"message_text":"Ready"}}}`
- `{"action":"answer_guest_query","guest_query_id":"guest_123","result":{"type":"article","id":"status","title":"Status","input_message_content":{"message_text":"Ready"}}}`
- `{"action":"save_prepared_inline_message","user_id":123,"result":{"type":"article","id":"status","title":"Status","input_message_content":{"message_text":"Ready"}}}`
- `{"action":"save_prepared_keyboard_button","user_id":123,"button":{"text":"Choose user","request_users":{"request_id":1}}}`
- `{"action":"get_user_chat_boosts","chat_id":"@channel","user_id":123}`
- `{"action":"get_business_connection","business_connection_id":"biz_123"}`
- `{"action":"get_managed_bot_token","user_id":123}`
- `{"action":"replace_managed_bot_token","user_id":123}`
- `{"action":"get_managed_bot_access_settings","user_id":123}`
- `{"action":"set_managed_bot_access_settings","user_id":123,"is_access_restricted":true,"added_user_ids":[456]}`
- `{"action":"get_user_personal_chat_messages","user_id":123,"limit":5}`
- `{"action":"set_my_commands","commands":[{"command":"start","description":"Start the bot"}]}`
- `{"action":"delete_my_commands","language_code":"en"}`
- `{"action":"get_my_commands","scope":{"type":"default"}}`
- `{"action":"set_my_name","name":"Acme Concierge"}`
- `{"action":"get_my_name","language_code":"en"}`
- `{"action":"set_my_description","description":"support assistant"}`
- `{"action":"get_my_description"}`
- `{"action":"set_my_short_description","short_description":"support assistant"}`
- `{"action":"get_my_short_description"}`
- `{"action":"set_my_profile_photo","photo":{"type":"static","photo":"attach://profile"}}`
- `{"action":"remove_my_profile_photo"}`
- `{"action":"set_chat_menu_button","chat_id":123,"menu_button":{"type":"commands"}}`
- `{"action":"get_chat_menu_button","chat_id":123}`
- `{"action":"set_my_default_administrator_rights","rights":{"can_delete_messages":true},"for_channels":true}`
- `{"action":"get_my_default_administrator_rights","for_channels":false}`
- `{"action":"post_story","business_connection_id":"biz_123","content":{"type":"photo","photo":"attach://story-photo"},"active_period":86400}`
- `{"action":"edit_story","business_connection_id":"biz_123","story_id":13,"content":{"type":"video","video":"attach://story-video"}}`
- `{"action":"delete_story","business_connection_id":"biz_123","story_id":14}`
- `{"action":"send_card","conversation_id":"tg:123:0","card":{"title":"...","blocks":[...]}}`
- `{"action":"stream_card","conversation_id":"tg:123:0","draft_id":123,"card":{"blocks":[...]}}`
- `{"action":"edit_card","conversation_id":"tg:123:0","message_id":123,"card":{"blocks":[...]}}`
- `{"action":"edit_message","conversation_id":"tg:123:0","message_id":123,"text":"Updated","buttons":[[{"text":"Open","url":"https://example.com"}]]}`
- `{"action":"edit_caption","conversation_id":"tg:123:0","message_id":124,"caption":"Updated caption"}`
- `{"action":"edit_media","conversation_id":"tg:123:0","message_id":124,"media_type":"photo","media":"<file_id>"}`
- `{"action":"edit_live_location","conversation_id":"tg:123:0","message_id":124,"latitude":41.3874,"longitude":2.1686}`
- `{"action":"stop_live_location","conversation_id":"tg:123:0","message_id":124}`
- `{"action":"edit_reply_markup","conversation_id":"tg:123:0","message_id":125,"buttons":[[{"text":"Done","callback_data":"done"}]]}`
- `{"action":"copy_message","conversation_id":"tg:123:0","from_chat_id":"@source","message_id":200}`
- `{"action":"copy_messages","conversation_id":"tg:123:0","from_chat_id":"@source","message_ids":[201,202]}`
- `{"action":"forward_message","conversation_id":"tg:123:0","from_chat_id":"@source","message_id":203}`
- `{"action":"forward_messages","conversation_id":"tg:123:0","from_chat_id":"@source","message_ids":[204,205]}`
- `{"action":"delete_message","conversation_id":"tg:123:0","message_id":206}`
- `{"action":"delete_messages","conversation_id":"tg:123:0","message_ids":[207,208]}`
- `{"action":"ban_chat_member","chat_id":-100123,"user_id":42,"revoke_messages":true}`
- `{"action":"create_chat_invite_link","chat_id":-100123,"name":"Support","creates_join_request":true}`
- `{"action":"answer_chat_join_request_query","query_id":"join_123","result":"approve"}`
- `{"action":"delete_all_message_reactions","chat_id":-100123,"actor_chat_id":-100456}`
- `{"action":"create_forum_topic","chat_id":-100123,"name":"Support","icon_color":7322096}`
- `{"action":"close_forum_topic","chat_id":-100123,"message_thread_id":5}`
- `{"action":"get_file","file_id":"<file_id>"}`
- `{"action":"get_custom_emoji_stickers","custom_emoji_ids":["emoji_1"]}`
- `{"action":"create_new_sticker_set","user_id":123,"name":"acme_by_bot","title":"Acme Concierge","stickers":[{"sticker":"attach://sticker","emoji_list":["🪽"],"format":"static"}]}`
- `{"action":"delete_sticker_set","name":"acme_by_bot"}`
- `{"action":"send_media","conversation_id":"tg:123:0","media_type":"animation","media":"https://..."}`
- `{"action":"send_live_photo","conversation_id":"tg:123:0","live_photo":"<file_id>","photo":"<file_id>"}`
- `{"action":"send_video_note","conversation_id":"tg:123:0","video_note":"<file_id>"}`
- `{"action":"send_sticker","conversation_id":"tg:123:0","sticker":"<file_id>","emoji":"👍"}`
- `{"action":"send_media_group","conversation_id":"tg:123:0","media":[{"type":"photo","media":"https://..."},{"type":"photo","media":"https://..."}]}`
- `{"action":"send_paid_media","conversation_id":"tg:123:0","star_count":5,"media":[{"type":"photo","media":"<file_id>"}]}`
- `{"action":"send_poll","conversation_id":"tg:123:0","question":"Pick","options":["A","B"]}`
- `{"action":"stop_poll","conversation_id":"tg:123:0","message_id":126}`
- `{"action":"send_checklist","conversation_id":"tg:123:0","business_connection_id":"biz_123","title":"Launch","tasks":["Draft","Review"]}`
- `{"action":"edit_checklist","conversation_id":"tg:123:0","message_id":127,"business_connection_id":"biz_123","title":"Updated","tasks":["Ship"]}`
- `{"action":"send_invoice","conversation_id":"tg:123:0","title":"Access","description":"Premium","payload":"invoice-1","currency":"XTR","prices":[{"label":"Access","amount":25}],"buttons":[[{"text":"Pay","pay":true}]]}`
- `{"action":"create_invoice_link","title":"Access","description":"Premium","payload":"invoice-link-1","currency":"XTR","prices":[{"label":"Access","amount":25}]}`
- `{"action":"answer_shipping_query","shipping_query_id":"ship_123","ok":true,"shipping_options":[{"id":"standard","title":"Standard","prices":[{"label":"Shipping","amount":5}]}]}`
- `{"action":"answer_pre_checkout_query","pre_checkout_query_id":"pre_123","ok":true}`
- `{"action":"get_my_star_balance"}`
- `{"action":"get_star_transactions","offset":0,"limit":25}`
- `{"action":"get_available_gifts"}`
- `{"action":"send_gift","user_id":123,"gift_id":"gift_123","text":"Enjoy"}`
- `{"action":"gift_premium_subscription","user_id":123,"month_count":3,"star_count":1000}`
- `{"action":"get_business_account_star_balance","business_connection_id":"biz_123"}`
- `{"action":"transfer_business_account_stars","business_connection_id":"biz_123","star_count":100}`
- `{"action":"get_business_account_gifts","business_connection_id":"biz_123","limit":50}`
- `{"action":"get_user_gifts","user_id":123,"exclude_unique":true}`
- `{"action":"get_chat_gifts","chat_id":"@channel","sort_by_price":true}`
- `{"action":"convert_gift_to_stars","business_connection_id":"biz_123","owned_gift_id":"owned_gift_123"}`
- `{"action":"upgrade_gift","business_connection_id":"biz_123","owned_gift_id":"owned_gift_123","star_count":0}`
- `{"action":"transfer_gift","business_connection_id":"biz_123","owned_gift_id":"owned_gift_123","new_owner_chat_id":123,"star_count":0}`
- `{"action":"verify_user","user_id":123,"custom_description":"Official"}`
- `{"action":"verify_chat","chat_id":"@channel"}`
- `{"action":"remove_user_verification","user_id":123}`
- `{"action":"remove_chat_verification","chat_id":"@channel"}`
- `{"action":"read_business_message","business_connection_id":"biz_123","chat_id":123,"message_id":456}`
- `{"action":"delete_business_messages","business_connection_id":"biz_123","message_ids":[456,457]}`
- `{"action":"set_business_account_name","business_connection_id":"biz_123","first_name":"Acme Concierge"}`
- `{"action":"set_business_account_username","business_connection_id":"biz_123","username":"example_bot"}`
- `{"action":"set_business_account_bio","business_connection_id":"biz_123","bio":"support assistant"}`
- `{"action":"set_business_account_profile_photo","business_connection_id":"biz_123","photo":{"type":"static","photo":"attach://profile-photo"}}`
- `{"action":"remove_business_account_profile_photo","business_connection_id":"biz_123","is_public":false}`
- `{"action":"set_business_account_gift_settings","business_connection_id":"biz_123","show_gift_button":true,"accepted_gift_types":{"unlimited_gifts":true,"limited_gifts":false,"unique_gifts":true,"premium_subscription":false}}`
- `{"action":"approve_suggested_post","chat_id":123,"message_id":456}`
- `{"action":"decline_suggested_post","chat_id":123,"message_id":456,"comment":"Needs changes"}`
- `{"action":"set_passport_data_errors","user_id":123,"errors":[{"source":"data","type":"personal_details","field_name":"first_name","data_hash":"hash","message":"Invalid first name"}]}`
- `{"action":"set_game_score","user_id":123,"score":42,"chat_id":"@gamechat","message_id":456}`
- `{"action":"get_game_high_scores","user_id":123,"inline_message_id":"inline-game"}`
- `{"action":"refund_star_payment","user_id":123,"telegram_payment_charge_id":"charge_123"}`
- `{"action":"send_game","conversation_id":"tg:123:0","game_short_name":"trivia_quest"}`
- `{"action":"send_location","conversation_id":"tg:123:0","latitude":41.3874,"longitude":2.1686}`
- `{"action":"send_venue","conversation_id":"tg:123:0","latitude":41.3874,"longitude":2.1686,"title":"HQ","address":"Barcelona"}`
- `{"action":"send_contact","conversation_id":"tg:123:0","phone_number":"+34123456789","first_name":"Example"}`
- `{"action":"send_dice","conversation_id":"tg:123:0","emoji":"🎲"}`
- `{"action":"send_chat_action","conversation_id":"tg:123:0","chat_action":"upload_photo"}`
- `{"action":"set_reaction","conversation_id":"tg:123:0","message_id":123,"reaction":"👍"}`
- `{"action":"send_rich_raw","conversation_id":"tg:123:0","rich_message":{"html":"<h3>...</h3>"}}`
- `{"action":"bind_session","slot":"telegram_agent_0","conversation_id":"tg:123:0"}`
- `{"action":"unbind_session","slot":"telegram_agent_0"}`
- `{"action":"slot_reply","slot":"telegram_agent_0","content":"..."}`
- `{"action":"audit"}`

Configure `send_sources`, `progress_sources`, `typing_sources`, `batch_sources`,
and `slot_reply_sources` when non-ingress objects need to target Telegram
conversations directly.

Structured card usage is documented in [`docs/telegram-cards.md`](docs/telegram-cards.md).
Example sender payloads are available in [`examples/card_actions.exs`](examples/card_actions.exs).

## Testing

```sh
mix deps.get
mix format --check-formatted
mix compile --warnings-as-errors
mix test
```

Optional live Telegram smoke tests should use separate credentials and should
not be required in regular CI.

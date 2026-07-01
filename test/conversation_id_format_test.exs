defmodule Genswarms.Telegram.ConversationIdFormatTest do
  use ExUnit.Case, async: true

  alias Genswarms.Telegram.{BotRef, Buttons, CommandRouter.Basic, ConversationId, Format, RichMessage}

  test "package exposes a stable semantic version" do
    assert Genswarms.Telegram.version() == "0.1.7"
  end

  test "conversation ids parse and classify DMs fail-closed" do
    assert ConversationId.build(123, 0) == "tg:123:0"
    assert ConversationId.build(123, nil) == "tg:123:0"
    assert {:ok, %{chat_id: "123", thread_id: "0"}} = ConversationId.parse("tg:123:0")
    assert {:ok, %{chat_id: "123", thread_id: "0"}} = ConversationId.parse(~c"tg:123:0")
    assert ConversationId.parse("tg:123") == :error
    assert ConversationId.dm?("tg:123:0")
    refute ConversationId.dm?("tg:-100:7")
    refute ConversationId.dm?("wat")
    refute ConversationId.dm_chat?("12abc")
    assert ConversationId.chat_id("tg_123_0") == "123"
    assert ConversationId.chat_id("tg:bad") == "tg:bad"
    assert ConversationId.chat_id(:not_a_cid) == :not_a_cid
    assert ConversationId.thread_id("tg:-100:7") == "7"
    assert ConversationId.thread_id("tg_bad") == nil
    assert ConversationId.valid?("tg:123:0")
    refute ConversationId.valid?("tg:123abc:0")
    refute ConversationId.dm?("tg:123abc:0")
    assert ConversationId.chat_type("tg:-100:7") == :group
    assert ConversationId.chat_type("tg:123abc:0") == :unknown
    assert ConversationId.chat_type(:not_a_cid) == :unknown
    refute ConversationId.valid?("tg:-100:-1")
    assert ConversationId.chat_type("tg:-100:-1") == :unknown
    assert ConversationId.thread_integer("tg:-100:7") == 7
    assert ConversationId.thread_integer("tg:-100:0") == nil
    assert ConversationId.thread_integer("tg:-100:bad") == nil
    assert ConversationId.encode_for_path(:atom_id) == "YXRvbV9pZA"
  end

  test "format emits safe Telegram HTML and plain fallback" do
    assert Format.to_html("hi **there** <x>") == "hi <b>there</b> &lt;x&gt;"
    assert Format.to_html("[ok](https://example.com)") == ~s(<a href="https://example.com">ok</a>)
    assert Format.to_html("[bad](javascript:alert(1))") == "bad"
    assert Format.plain("hi **there**") == "hi there"
    assert Format.escape_md("a*b[c]") == "a\\*b\\[c\\]"
  end

  test "format handles nested URL parentheses, escaped markers, and non-binary input" do
    assert Format.to_html("[docs](https://example.com/a_(b))") ==
             "<a href=\"https://example.com/a_(b)\">docs</a>"

    assert Format.to_html("\\*literal\\*") == "*literal*"
    assert Format.to_html("*italic* _also_") == "<i>italic</i> <i>also</i>"
    assert Format.to_html("**unterminated") == "**unterminated"
    assert Format.to_html("`unterminated") == "`unterminated"
    assert Format.to_html("[broken](https://example.com/a b)") == "[broken](https://example.com/a b)"
    assert Format.to_html("[quote](https://example.com/?q=\"x\")") ==
             "<a href=\"https://example.com/?q=&quot;x&quot;\">quote</a>"

    assert Format.to_html(<<96, ?x, 96>>) == "<code>x</code>"

    assert Format.plain("[same](https://example.com)") == "same (https://example.com)"
    assert Format.plain("[https://example.com](https://example.com)") == "https://example.com"
    assert Format.plain(nil) == ""
    assert Format.plain(123) == "123"
    assert Format.to_html(nil) == ""
    assert Format.to_html(123) == "123"
    assert Format.escape_md(nil) == ""
    assert Format.escape_md(:atom) == "atom"
    assert Format.safe_url?("tg://resolve?domain=telegram") == true
    assert Format.safe_url?("mailto:team@example.com") == true
    refute Format.safe_url?("ftp://example.com")
  end

  test "tolerant button normalization drops unsafe shapes while preserving supported controls" do
    buttons = [
      [%{"text" => "Open", "url" => "https://example.com"}],
      [%{"text" => "Bad", "url" => "javascript:alert(1)"}],
      [%{"text" => "Callback", "action" => "go"}],
      [%{"text" => "App", "web_app" => "https://example.com/app"}],
      [%{"text" => "Search", "switch_inline_query" => "wingston"}],
      [%{"text" => "Chosen", "switch_inline_query_chosen_chat" => %{"allow_user_chats" => "true"}}],
      [%{"text" => "Copy", "copy_text" => %{"text" => "copied"}}],
      [%{"text" => "Pay", "pay" => "1"}],
      [%{"text" => ""}]
    ]

    assert Buttons.normalize(buttons) == [
             [%{text: "Open", url: "https://example.com"}],
             [%{text: "Callback", callback_data: "go"}],
             [%{text: "App", web_app: %{url: "https://example.com/app"}}],
             [%{text: "Search", switch_inline_query: "wingston"}],
             [
               %{
                 text: "Chosen",
                 switch_inline_query_chosen_chat: %{allow_user_chats: true, query: ""}
               }
             ],
             [%{text: "Copy", copy_text: %{text: "copied"}}],
             [%{text: "Pay", pay: true}]
           ]

    assert Buttons.normalize(:bad) == nil
    assert Buttons.normalize([]) == nil
    assert Buttons.reply_markup(nil) == nil
    assert Buttons.normalize_reply_markup([]) == nil
    assert Buttons.normalize_reply_markup(:bad) == nil
    assert Buttons.normalize_reply_markup(%{"inline_keyboard" => [[%{"text" => ""}]]}) == nil
    assert Buttons.normalize_reply_markup(%{"keyboard" => "bad"}) == nil
    assert Buttons.normalize_reply_markup(%{"keyboard" => [[123]]}) == nil
    assert Buttons.normalize([%{"text" => "single", "callback_data" => "ok"}]) == [
             [%{text: "single", callback_data: "ok"}]
           ]

    assert Buttons.normalize([
             [%{"text" => "Bad app", "web_app" => 123}],
             [%{"text" => "Bad switch", "switch_inline_query" => 123}],
             [%{"text" => "Bad chosen", "switch_inline_query_chosen_chat" => 123}],
             [%{"text" => "Bad copy", "copy_text" => 123}],
             [123]
           ]) == nil

    assert Buttons.reply_markup(%{
             "keyboard" => [
               [
                 %{
                   "text" => "Poll",
                   "request_poll" => %{"type" => "quiz"},
                   "style" => "primary",
                   "icon_custom_emoji_id" => "emoji-1"
                 }
               ],
               [%{"text" => "Bad", "web_app" => "javascript:alert(1)"}]
             ],
             "resize_keyboard" => "true",
             "input_field_placeholder" => "  Pick one  "
           }) == %{
             keyboard: [
               [
                 %{
                   text: "Poll",
                   request_poll: %{type: "quiz"},
                   style: "primary",
                   icon_custom_emoji_id: "emoji-1"
                 }
               ]
             ],
             resize_keyboard: true,
             input_field_placeholder: "Pick one"
           }

    assert Buttons.reply_markup(%{"type" => "remove_keyboard", "selective" => 1}) ==
             %{remove_keyboard: true, selective: true}

    assert Buttons.reply_markup(%{"type" => "force_reply", "input_field_placeholder" => "Reply"}) ==
             %{force_reply: true, input_field_placeholder: "Reply"}

    assert Buttons.reply_markup(%{
             "keyboard" => [
               [%{"text" => "Quiz", "request_poll" => "quiz"}],
               [%{"text" => "Any poll", "request_poll" => %{}}],
               [%{"text" => "Plain app", "web_app" => "https://example.com/app"}],
               [%{"text" => "Bad combo", "request_contact" => true, "request_location" => true}]
             ]
           }) == %{
             keyboard: [
               [%{text: "Quiz", request_poll: %{type: "quiz"}}],
               [%{text: "Any poll", request_poll: %{}}],
               [%{text: "Plain app", web_app: %{url: "https://example.com/app"}}]
             ]
           }
  end

  test "rich message helper accepts exactly one non-empty format" do
    assert RichMessage.html("<b>ok</b>") == %{html: "<b>ok</b>"}
    assert RichMessage.markdown("**ok**") == %{markdown: "**ok**"}
    assert RichMessage.validate(%{markdown: "**ok**"}) == :ok
    assert RichMessage.validate(%{"markdown" => "**ok**"}) == :ok

    assert {:error, %{reason: "must contain exactly one of html or markdown"}} =
             RichMessage.validate(%{markdown: "**ok**", html: "<b>ok</b>"})

    assert {:error, %{reason: "must contain exactly one of html or markdown"}} =
             RichMessage.validate(%{"markdown" => "**ok**", "html" => "<b>ok</b>"})
  end

  test "basic command router strips bot names and fails closed on non-command input" do
    assert Basic.handle_command(%{text: "/start@WingstonBot hello"}, %{}) == {:reply, "Started."}
    assert Basic.handle_command(%{text: "   /help"}, %{}) == {:reply, "Send a message and I will route it to the swarm."}
    assert Basic.handle_command(%{text: "hello"}, %{}) == {:reply, "Unknown command."}
    assert Basic.handle_command(%{text: nil}, %{}) == {:reply, "Unknown command."}
    assert Basic.handle_callback(%{}, %{}) == :ok
    assert Basic.command_menu(:dm, %{}) == [
             %{command: "start", description: "Start"},
             %{command: "help", description: "Help"}
           ]

    assert Basic.command_menu(:group, %{}) == [%{command: "help", description: "Help"}]
  end

  test "bot refs never expose raw tokens or unsafe path segments" do
    ref = BotRef.from_token("123:SECRET")

    assert byte_size(ref) == 16
    refute ref =~ "SECRET"
    assert BotRef.from_token(nil) == "unknown_bot"
    assert BotRef.path_key("../bad bot") == ".._bad_bot"
    assert BotRef.path_key("") == "unknown_bot"
    assert BotRef.path_key(".") == "unknown_bot"
    assert BotRef.path_key("..") == "unknown_bot"
  end
end

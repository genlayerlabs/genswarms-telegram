defmodule Genswarms.Telegram.ConversationIdFormatTest do
  use ExUnit.Case, async: true

  alias Genswarms.Telegram.{ConversationId, Format}

  test "conversation ids parse and classify DMs fail-closed" do
    assert ConversationId.build(123, 0) == "tg:123:0"
    assert {:ok, %{chat_id: "123", thread_id: "0"}} = ConversationId.parse("tg:123:0")
    assert ConversationId.dm?("tg:123:0")
    refute ConversationId.dm?("tg:-100:7")
    refute ConversationId.dm?("wat")
    assert ConversationId.chat_id("tg_123_0") == "123"
    assert ConversationId.thread_id("tg:-100:7") == "7"
    assert ConversationId.valid?("tg:123:0")
    refute ConversationId.valid?("tg:123abc:0")
    refute ConversationId.dm?("tg:123abc:0")
    assert ConversationId.chat_type("tg:123abc:0") == :unknown
    refute ConversationId.valid?("tg:-100:-1")
    assert ConversationId.chat_type("tg:-100:-1") == :unknown
  end

  test "format emits safe Telegram HTML and plain fallback" do
    assert Format.to_html("hi **there** <x>") == "hi <b>there</b> &lt;x&gt;"
    assert Format.to_html("[ok](https://example.com)") == ~s(<a href="https://example.com">ok</a>)
    assert Format.to_html("[bad](javascript:alert(1))") == "bad"
    assert Format.plain("hi **there**") == "hi there"
    assert Format.escape_md("a*b[c]") == "a\\*b\\[c\\]"
  end
end

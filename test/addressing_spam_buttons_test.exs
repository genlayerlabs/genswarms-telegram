defmodule Genswarms.Telegram.AddressingSpamButtonsTest do
  use ExUnit.Case, async: true

  alias Genswarms.Telegram.{Addressing, Buttons, OffsetFile, SpamGuard}

  test "addressing handles slash command targets and group mentions" do
    assert Addressing.command_addressed?("/mode quiet", "ExampleBot")
    assert Addressing.command_addressed?("  /mode quiet", "ExampleBot")
    assert Addressing.command_addressed?("/mode@examplebot quiet", "ExampleBot")
    refute Addressing.command_addressed?("/mode@OtherBot quiet", "ExampleBot")
    refute Addressing.command_addressed?("  /mode@OtherBot quiet", "ExampleBot")
    refute Addressing.command_addressed?("hello /mode", "ExampleBot")

    event = %{
      conversation_id: "tg:-1001:0",
      text: "hey @ExampleBot",
      reply_to_bot_username: nil
    }

    assert Addressing.addressed?(event, "examplebot")
    refute Addressing.addressed?(%{event | text: "hey all"}, "examplebot")

    assert Addressing.addressed?(
             %{event | text: "hey all", reply_to_bot_username: "ExampleBot"},
             "examplebot"
           )

    refute Addressing.addressed?(%{event | text: "hey all"}, nil)

    assert Addressing.addressed?(%{event | text: "hey all"}, nil,
             fail_open_without_username?: true
           )

    assert Addressing.addressed?(%{conversation_id: "tg:123:0", text: "hello"}, nil)
  end

  test "spam guard enforces length, rate, repeat, disable, and bucket cap" do
    cfg = %{enabled: true, window: 60, max_per_min: 3, max_repeat: 2, max_chars: 12}

    {:pass, sm} = SpamGuard.eval(%{}, "k", "a", 1_000, cfg)
    {:pass, sm} = SpamGuard.eval(sm, "k", "b", 1_001, cfg)
    {:pass, sm} = SpamGuard.eval(sm, "k", "c", 1_002, cfg)
    assert {:skip, "per_minute", _} = SpamGuard.eval(sm, "k", "d", 1_003, cfg)
    assert {:pass, _} = SpamGuard.eval(sm, "k", "d", 1_063, cfg)

    {:pass, rm} = SpamGuard.eval(%{}, "r", "hi", 1, cfg)
    {:pass, rm} = SpamGuard.eval(rm, "r", "hi", 2, cfg)
    assert {:skip, "repeat", _} = SpamGuard.eval(rm, "r", "hi", 3, cfg)
    assert {:skip, "text_too_long", %{}} = SpamGuard.eval(%{}, "x", "this is too long", 1, cfg)
    assert {:pass, %{}} = SpamGuard.eval(%{}, "x", "this is too long", 1, %{cfg | enabled: false})

    big =
      1..10_001
      |> Map.new(fn i -> {"k#{i}", [{i, "x"}]} end)

    assert {:pass, capped} = SpamGuard.eval(big, "fresh", "hello", 99_999, cfg)
    assert map_size(capped) <= 5_001
    assert Map.has_key?(capped, "fresh")
  end

  test "buttons normalize JSON and atom-keyed buttons without raising" do
    rows =
      Buttons.normalize([
        [%{"text" => "Open", "url" => "https://example.com"}],
        [%{"text" => "Quiet", "action" => "mode quiet"}],
        [%{text: "Callback", callback_data: "cb"}],
        [%{"text" => ""}, %{"text" => "Bad", "url" => "javascript:alert(1)"}],
        [%{"text" => "Long", "action" => String.duplicate("a", 65)}]
      ])

    assert rows == [
             [%{text: "Open", url: "https://example.com"}],
             [%{text: "Quiet", callback_data: "mode quiet"}],
             [%{text: "Callback", callback_data: "cb"}]
           ]

    assert Buttons.reply_markup(rows) == %{
             inline_keyboard: [
               [%{text: "Open", url: "https://example.com"}],
               [%{text: "Quiet", callback_data: "mode quiet"}],
               [%{text: "Callback", callback_data: "cb"}]
             ]
           }

    assert Buttons.normalize([[%{"text" => "", "url" => "https://example.com"}]]) == nil
  end

  test "offset file helper hashes tokens and reads malformed files as zero" do
    dir = Path.join(System.tmp_dir!(), "gst-offset-#{System.unique_integer([:positive])}")
    on_exit(fn -> File.rm_rf(dir) end)

    base = Path.join(dir, "updates.offset")
    path = OffsetFile.path(base, "SECRET_TOKEN")

    refute path =~ "SECRET_TOKEN"
    assert String.starts_with?(path, base <> ".")
    assert OffsetFile.read(path) == 0

    assert :ok = OffsetFile.write(path, 42)
    assert OffsetFile.read(path) == 42

    File.write!(path, "not-int")
    assert OffsetFile.read(path) == 0
  end
end

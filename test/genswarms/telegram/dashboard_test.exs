defmodule Genswarms.Telegram.DashboardTest do
  use ExUnit.Case, async: true

  alias Genswarms.Telegram.Dashboard

  test "session_label: @handle beats name beats chat id; junk fails to the cid" do
    assert Dashboard.session_label(%{"handle" => "fia"}, "tg:1:0") == "@fia"
    assert Dashboard.session_label(%{"name" => "Fia"}, "tg:1:0") == "Fia"
    assert Dashboard.session_label(%{handle: "fia"}, "tg:1:0") == "@fia"
    assert Dashboard.session_label(nil, "tg:903:0") == "903"
    assert Dashboard.session_label(%{"handle" => "  "}, "tg:903:0") == "903"
    assert Dashboard.session_label(nil, "not-a-cid") == "not-a-cid"
  end

  test "session_row shapes the generic dashboard row with telegram knowledge" do
    row = Dashboard.session_row("tg:-100:7", user: %{"name" => "Ops"})
    assert row.label == "Ops"
    assert row.transport == "telegram"
    assert row.transport_ref == %{"chat_id" => "-100", "thread_id" => "7"}
    assert row.metadata["chat_type"] == "group"
    assert Dashboard.session_row("tg:5:0").metadata["chat_type"] == "dm"
  end

  test "dashboard_extension speaks contract schema 1 with capped rows" do
    sessions =
      for n <- 1..120 do
        %{session_id: "tg:#{n}:0", label: "u#{n}"}
      end ++ [%{session_id: "tg:-9:0"}]

    ext = Dashboard.dashboard_extension(sessions: sessions)

    assert ext["telegram"] == %{"conversations" => 121, "dms" => 120, "groups" => 1}
    [page] = ext["dashboard_pages"]
    assert page["schema"] == 1
    assert page["id"] == "telegram"
    [metrics, table] = page["sections"]
    assert metrics["type"] == "metrics"
    assert table["type"] == "table"
    assert length(table["rows"]) == 100
    assert hd(table["rows"])["label"] == "u1"
    assert hd(table["rows"])["kind"] == "dm"
  end

  test "string-keyed session maps work too (wire-shaped input)" do
    ext = Dashboard.dashboard_extension(sessions: [%{"session_id" => "tg:7:0", "label" => "x"}])
    assert ext["telegram"]["dms"] == 1
  end

  test "poller_health_block: nil health (no poller / disabled) yields no block" do
    assert Dashboard.poller_health_block(nil) == %{}
  end

  test "poller_health_block: exact wire shape + both health_rules, byte-exact (wire contract)" do
    health = %{last_poll_ok_ms: 1_700_000_000_000, conflict_count: 2, poll_failures: 0}

    assert Dashboard.poller_health_block(health) == %{
             "telegram_poller" => %{
               "v" => 1,
               "last_poll_ok_ms" => 1_700_000_000_000,
               "conflict_count" => 2,
               "poll_failures" => 0,
               "health_rules" => [
                 %{
                   "id" => "poller_deaf",
                   "severity" => "warn",
                   "card" =>
                     "telegram poller has not completed a successful getUpdates in over 2 minutes",
                   "where" => %{
                     "op" => "neq",
                     "lhs" => %{"path" => "last_poll_ok_ms"},
                     "rhs" => %{"lit" => nil}
                   },
                   "when" => %{
                     "op" => "gt",
                     "lhs" => %{"sub" => ["now", %{"path" => "last_poll_ok_ms"}]},
                     "rhs" => 120_000
                   }
                 },
                 %{
                   "id" => "poll_conflict",
                   "severity" => "warn",
                   "card" =>
                     "getUpdates 409 conflict — two pollers are fighting over this bot token",
                   "when" => %{
                     "op" => "gt",
                     "lhs" => %{"delta" => "conflict_count"},
                     "rhs" => 0
                   }
                 }
               ]
             }
           }

    ids = get_in(Dashboard.poller_health_block(health), ["telegram_poller", "health_rules"])
    assert Enum.map(ids, & &1["id"]) == ["poller_deaf", "poll_conflict"]
  end

  test "poller_health_block with nil last_poll_ok_ms" do
    health = %{last_poll_ok_ms: nil, conflict_count: 0, poll_failures: 3}
    block = Dashboard.poller_health_block(health)
    assert block["telegram_poller"]["last_poll_ok_ms"] == nil
    assert block["telegram_poller"]["poll_failures"] == 3
  end

  test "poller_health_block does not change dashboard_extension/1's output" do
    sessions = [%{session_id: "tg:1:0", label: "u1"}]
    ext_before = Dashboard.dashboard_extension(sessions: sessions)
    _ = Dashboard.poller_health_block(%{last_poll_ok_ms: 1, conflict_count: 0, poll_failures: 0})
    ext_after = Dashboard.dashboard_extension(sessions: sessions)
    assert ext_before == ext_after
    refute Map.has_key?(ext_after, "telegram_poller")
  end
end

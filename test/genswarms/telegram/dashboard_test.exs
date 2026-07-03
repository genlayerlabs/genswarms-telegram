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
end

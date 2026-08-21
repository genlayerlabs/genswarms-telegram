defmodule Genswarms.Telegram.OffsetFileWriteFailureTest do
  @moduledoc """
  A failed offset write must be VISIBLE.

  If /data goes full or read-only, `File.write` fails on every poll; the old
  code swallowed the result, so the offset froze silently: Telegram re-served
  the same ≤100-update window forever, every update deduped as already-seen,
  and no new message could ever enter the window — total ingestion silence
  with every health gauge green (genmochi 2026-08-21 investigation). The
  best-effort contract stays (`:ok`, callers never crash), but the failure
  must log.
  """
  use ExUnit.Case

  import ExUnit.CaptureLog

  alias Genswarms.Telegram.OffsetFile

  test "a failed write logs a warning but keeps the best-effort contract" do
    # parent path is a FILE, so mkdir_p/write must fail
    blocker =
      Path.join(System.tmp_dir!(), "gst-offset-blocker-#{System.unique_integer([:positive])}")

    File.write!(blocker, "not a directory")
    on_exit(fn -> File.rm(blocker) end)

    path = Path.join([blocker, "nested", "offset"])

    log =
      capture_log(fn ->
        assert :ok = OffsetFile.write(path, 42)
      end)

    assert log =~ "offset"
  end

  test "a successful write stays silent" do
    dir = Path.join(System.tmp_dir!(), "gst-offset-ok-#{System.unique_integer([:positive])}")
    on_exit(fn -> File.rm_rf(dir) end)
    path = Path.join(dir, "offset")

    log =
      capture_log(fn ->
        assert :ok = OffsetFile.write(path, 42)
      end)

    assert OffsetFile.read(path) == 42
    assert log == ""
  end
end

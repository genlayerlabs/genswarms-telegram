defmodule Genswarms.Telegram.Client.CurlTest do
  use ExUnit.Case, async: false

  alias Genswarms.Telegram.Client.Curl

  setup do
    root = Path.join(System.tmp_dir!(), "genswarms-telegram-curl-test-#{unique_id()}")
    fake_curl = Path.join(root, "fake-curl")
    previous_tmpdir = System.get_env("TMPDIR")

    File.mkdir_p!(root)

    File.write!(
      fake_curl,
      "#!/usr/bin/env sh\nprintf '%s\\n' '{\"ok\":true,\"result\":{}}' '200'\n"
    )

    File.chmod!(fake_curl, 0o700)
    System.put_env("TMPDIR", root)

    on_exit(fn ->
      restore_env("TMPDIR", previous_tmpdir)
      File.rm_rf!(root)
    end)

    {:ok, root: root, fake_curl: fake_curl}
  end

  test "request removes its private temporary directory", %{root: root, fake_curl: fake_curl} do
    assert {:ok, %{}} =
             Curl.request(:get_me, %{}, token: "test-token", curl_bin: fake_curl)

    assert Path.wildcard(Path.join(root, "genswarms-telegram-*")) == []
  end

  defp unique_id, do: System.unique_integer([:positive, :monotonic])

  defp restore_env(name, nil), do: System.delete_env(name)
  defp restore_env(name, value), do: System.put_env(name, value)
end

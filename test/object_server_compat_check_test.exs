defmodule Genswarms.Telegram.ObjectServerCompatCheckTest do
  use ExUnit.Case, async: false

  test "real ObjectServer compatibility check passes" do
    {output, status} =
      System.cmd("mix", ["run", "checks/object_server_compat_check.exs"],
        env: [{"MIX_ENV", "dev"}],
        stderr_to_stdout: true
      )

    assert status == 0, output
  end
end

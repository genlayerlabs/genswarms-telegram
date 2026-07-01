defmodule Genswarms.Telegram.ReplyHelperTest do
  use ExUnit.Case

  test "reply helper builds escaped JSON for the configured sender" do
    if is_nil(System.find_executable("jq")) do
      flunk("jq is required by priv/reply.sh and should be present in CI/runtime images")
    end

    dir = Path.join(System.tmp_dir!(), "gst-reply-#{System.unique_integer([:positive])}")
    on_exit(fn -> File.rm_rf(dir) end)

    bin = Path.join(dir, "bin")
    File.mkdir_p!(bin)

    args_path = Path.join(dir, "args.txt")
    payload_path = Path.join(dir, "payload.json")
    input_path = Path.join(dir, "input.txt")
    swarm_msg = Path.join(bin, "swarm-msg")

    File.write!(swarm_msg, """
    #!/bin/sh
    printf '%s\\n' "$@" > "$SWARM_MSG_ARGS"
    while [ "$1" != "-f" ]; do shift; done
    cat "$2" > "$SWARM_MSG_PAYLOAD"
    """)

    File.chmod!(swarm_msg, 0o700)
    File.write!(input_path, "hello\n\"there\"")

    env = [
      {"PATH", bin <> ":" <> System.get_env("PATH", "")},
      {"SWARM_MSG_ARGS", args_path},
      {"SWARM_MSG_PAYLOAD", payload_path},
      {"REPLY_INPUT", input_path},
      {"GENSWARMS_TELEGRAM_CONVERSATION_ID", "tg:1:0"},
      {"GENSWARMS_TELEGRAM_SENDER_OBJECT", "telegram_sender"}
    ]

    assert {_out, 0} =
             System.cmd("sh", ["-c", "sh priv/reply.sh --to 123 -f - < \"$REPLY_INPUT\""],
               cd: File.cwd!(),
               env: env
             )

    assert File.read!(args_path) =~ "telegram_sender"

    payload = payload_path |> File.read!() |> Jason.decode!()
    assert payload["action"] == "reply"
    refute Map.has_key?(payload, "conversation_id")
    assert payload["reply_to_message_id"] == 123
    assert payload["text"] == "hello\n\"there\""

    temp_payload =
      args_path
      |> File.read!()
      |> String.split("\n", trim: true)
      |> Enum.reverse()
      |> hd()

    refute File.exists?(temp_payload)
  end
end

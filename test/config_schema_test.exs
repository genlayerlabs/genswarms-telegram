defmodule Genswarms.Telegram.ConfigSchemaTest do
  use ExUnit.Case, async: true

  alias Genswarms.Telegram.BotRef

  # every config key Ingress.new/1 reads (plus bot_token_env, read via
  # BotRef.resolve_token) — keep in sync; the conformance below catches drift
  @ingress_keys ~w(bot_token bot_token_env bot_ref bot_username
                   fail_open_without_username? inbound_effects client
                   client_opts store context_store identity_sink
                   command_router session_runtime session_opts sender
                   binding_authority binding_sinks memory_policy poll_enabled
                   poll_interval_ms poll_timeout_s allowed_updates)

  defp schema do
    Path.join(__DIR__, "../swarm-object.json")
    |> File.read!()
    |> Jason.decode!()
    |> Map.fetch!("config_schema")
  end

  test "schema properties and Ingress config keys match exactly" do
    schema_keys = schema()["properties"] |> Map.keys() |> Enum.sort()
    assert schema_keys == Enum.sort(@ingress_keys)
  end

  test "token fields are the only x-secret fields" do
    props = schema()["properties"]
    secrets = for {k, v} <- props, v["x-secret"] == true, do: k
    assert Enum.sort(secrets) == ["bot_token", "bot_token_env"]
  end

  test "trust surface is not hot-mutable" do
    props = schema()["properties"]
    mutable = for {k, v} <- props, v["x-mutable"] == true, do: k

    for trust_key <- ~w(binding_authority binding_sinks session_opts session_runtime store) do
      refute trust_key in mutable, "#{trust_key} must not be x-mutable"
    end
  end

  test "resolve_token precedence: literal > named env > default env" do
    var = "TG_TEST_TOKEN_#{System.unique_integer([:positive])}"
    System.put_env(var, "from-named-env")

    assert BotRef.resolve_token(%{bot_token: "literal", bot_token_env: var}) == "literal"
    assert BotRef.resolve_token(%{bot_token_env: var}) == "from-named-env"

    # empty or absent named var falls through to the default env var
    default = System.get_env("GENSWARMS_TELEGRAM_BOT_TOKEN")
    assert BotRef.resolve_token(%{bot_token_env: ""}) == default
    assert BotRef.resolve_token(%{}) == default
  end
end

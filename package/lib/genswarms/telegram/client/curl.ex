defmodule Genswarms.Telegram.Client.Curl do
  @moduledoc """
  Secure curl-backed Telegram Bot API adapter.

  The bot token is written only to a short-lived curl config file, never to argv.
  Payloads are sent from a short-lived JSON file. Both files are removed after
  the request completes.
  """

  @behaviour Genswarms.Telegram.Client

  alias Genswarms.Telegram.Client

  @impl true
  def request(method, payload, opts) do
    token = Keyword.fetch!(opts, :token)
    timeout = Keyword.get(opts, :timeout, default_timeout(method))

    with {:ok, curl} <- curl_bin(opts),
         {:ok, config_path, body_path} <- write_temp_files(method, token, payload) do
      args = argv(config_path, body_path, timeout)

      try do
        case System.cmd(curl, args, stderr_to_stdout: true) do
          {out, 0} -> classify_curl_output(out)
          {out, code} -> {:error, {:curl, code, redact(out, token)}}
        end
      after
        cleanup_temp_files(config_path, body_path)
      end
    end
  end

  @doc false
  def argv(config_path, body_path, timeout) do
    [
      "-sS",
      "--max-time",
      to_string(timeout),
      "--config",
      config_path,
      "-w",
      "\n%{http_code}",
      "-X",
      "POST",
      "-H",
      "Content-Type: application/json",
      "--data-binary",
      "@#{body_path}"
    ]
  end

  defp write_temp_files(method, token, payload) do
    dir =
      Path.join([
        System.tmp_dir!(),
        "genswarms-telegram-#{System.unique_integer([:positive, :monotonic])}-#{random_suffix()}"
      ])

    config_path = Path.join(dir, "request.curl")
    body_path = Path.join(dir, "body.json")
    url = "https://api.telegram.org/bot#{token}/#{Client.method_name(method)}"

    config = ~s(url = "#{escape_config(url)}"\n)

    with :ok <- File.mkdir(dir),
         :ok <- File.chmod(dir, 0o700),
         :ok <- File.write(config_path, config, [:exclusive]),
         :ok <- File.write(body_path, Jason.encode!(payload), [:exclusive]) do
      File.chmod(config_path, 0o600)
      File.chmod(body_path, 0o600)
      {:ok, config_path, body_path}
    else
      error ->
        File.rm_rf(dir)
        error
    end
  end

  defp cleanup_temp_files(config_path, body_path) do
    File.rm(config_path)
    File.rm(body_path)
    File.rm(Path.dirname(config_path))
    :ok
  end

  defp classify_curl_output(out) do
    case String.split(String.trim_trailing(out), "\n") do
      [only] ->
        case Integer.parse(only) do
          {status, _} -> Client.classify_response(status, "")
          :error -> {:error, :bad_curl_response}
        end

      parts ->
        status = List.last(parts)
        body = parts |> Enum.drop(-1) |> Enum.join("\n")

        case Integer.parse(status) do
          {status, _} -> Client.classify_response(status, body)
          :error -> {:error, :bad_curl_response}
        end
    end
  end

  defp curl_bin(opts) do
    cond do
      bin = Keyword.get(opts, :curl_bin) -> {:ok, bin}
      bin = System.find_executable("curl") -> {:ok, bin}
      true -> {:error, :no_curl}
    end
  end

  defp default_timeout(:get_updates), do: 35
  defp default_timeout(_), do: 10

  defp escape_config(value), do: String.replace(value, "\"", "\\\"")
  defp random_suffix, do: 6 |> :crypto.strong_rand_bytes() |> Base.url_encode64(padding: false)
  defp redact(out, token), do: String.replace(to_string(out), token, "[REDACTED]")
end

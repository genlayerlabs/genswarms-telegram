defmodule Genswarms.Telegram.SpamGuard do
  @moduledoc """
  Pure sliding-window spam guard for Telegram ingress adapters.

  The guard is keyed by the caller, usually `{chat_id, user_id}` or a string
  containing both. It is intentionally stateless: callers own the returned bucket
  map and can keep it in object state.
  """

  @max_buckets 10_000

  @doc """
  Build a guard config from options.
  """
  def config(opts \\ %{}) do
    %{
      enabled: option(opts, :enabled, option(opts, :spam_enabled, true)),
      window: option(opts, :window, option(opts, :spam_window_seconds, 60)),
      max_per_min: option(opts, :max_per_min, option(opts, :spam_max_per_min, 6)),
      max_repeat: option(opts, :max_repeat, option(opts, :spam_max_repeat, 3)),
      max_chars: option(opts, :max_chars, option(opts, :spam_max_chars, 3_000))
    }
  end

  @doc """
  Decide whether to drop `text` for `key` at timestamp `ts`.

  Returns `{:pass, bucket_map}` or `{:skip, reason, bucket_map}`.
  """
  def eval(map, key, text, ts, cfg) when is_map(map) do
    cfg = config(cfg)
    norm = normalize_text(text)

    cond do
      not cfg.enabled ->
        {:pass, map}

      cfg.max_chars > 0 and String.length(norm) > cfg.max_chars ->
        {:skip, "text_too_long", map}

      true ->
        bucket = map |> Map.get(key, []) |> trim_window(ts - cfg.window)

        cond do
          cfg.max_per_min > 0 and length(bucket) >= cfg.max_per_min ->
            {:skip, "per_minute", Map.put(map, key, bucket)}

          cfg.max_repeat > 0 and norm != "" and
              Enum.count(bucket, fn {_t, t} -> t == norm end) >= cfg.max_repeat ->
            {:skip, "repeat", Map.put(map, key, bucket)}

          true ->
            {:pass, cap_buckets(Map.put(map, key, bucket ++ [{ts, norm}]))}
        end
    end
  end

  def eval(_map, key, text, ts, cfg), do: eval(%{}, key, text, ts, cfg)

  def normalize_text(text),
    do: text |> to_string() |> String.downcase() |> String.split() |> Enum.join(" ")

  defp trim_window(bucket, cutoff), do: Enum.filter(bucket, fn {t, _} -> t >= cutoff end)

  defp cap_buckets(map) when map_size(map) > @max_buckets do
    keep = div(map_size(map), 2)

    map
    |> Enum.sort_by(fn {_key, bucket} -> bucket_recency(bucket) end, :desc)
    |> Enum.take(keep)
    |> Map.new()
  end

  defp cap_buckets(map), do: map

  defp bucket_recency([]), do: 0
  defp bucket_recency(bucket), do: bucket |> Enum.map(fn {t, _} -> t end) |> Enum.max()

  defp option(opts, key, default) when is_map(opts) do
    cond do
      Map.has_key?(opts, key) -> Map.get(opts, key)
      Map.has_key?(opts, to_string(key)) -> Map.get(opts, to_string(key))
      true -> default
    end
  end

  defp option(opts, key, default) when is_list(opts), do: Keyword.get(opts, key, default)
  defp option(_opts, _key, default), do: default
end

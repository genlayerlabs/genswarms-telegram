defmodule Genswarms.Telegram.RichMessage do
  @moduledoc """
  Small helpers for Telegram `InputRichMessage` values.

  Telegram requires exactly one of `html` or `markdown`. This module keeps that
  rule at the package boundary so agents and host apps get deterministic errors
  before Telegram rejects a request.
  """

  def html(html, opts \\ []) when is_binary(html) do
    %{html: html}
    |> maybe_put(:is_rtl, Keyword.get(opts, :is_rtl))
    |> maybe_put(:skip_entity_detection, Keyword.get(opts, :skip_entity_detection))
  end

  def markdown(markdown, opts \\ []) when is_binary(markdown) do
    %{markdown: markdown}
    |> maybe_put(:is_rtl, Keyword.get(opts, :is_rtl))
    |> maybe_put(:skip_entity_detection, Keyword.get(opts, :skip_entity_detection))
  end

  def validate(%{html: html} = rich) when is_binary(html) and html != "" do
    if Map.has_key?(rich, :markdown) or Map.has_key?(rich, "markdown") do
      {:error, error("rich_message", "must contain exactly one of html or markdown")}
    else
      :ok
    end
  end

  def validate(%{"html" => html} = rich) when is_binary(html) and html != "" do
    if Map.has_key?(rich, :markdown) or Map.has_key?(rich, "markdown") do
      {:error, error("rich_message", "must contain exactly one of html or markdown")}
    else
      :ok
    end
  end

  def validate(%{markdown: markdown} = rich) when is_binary(markdown) and markdown != "" do
    if Map.has_key?(rich, :html) or Map.has_key?(rich, "html") do
      {:error, error("rich_message", "must contain exactly one of html or markdown")}
    else
      :ok
    end
  end

  def validate(%{"markdown" => markdown} = rich) when is_binary(markdown) and markdown != "" do
    if Map.has_key?(rich, :html) or Map.has_key?(rich, "html") do
      {:error, error("rich_message", "must contain exactly one of html or markdown")}
    else
      :ok
    end
  end

  def validate(_rich),
    do: {:error, error("rich_message", "must contain non-empty html or markdown")}

  defp error(path, reason), do: %{path: path, reason: reason}

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end

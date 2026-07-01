defmodule Genswarms.Telegram.Buttons do
  @moduledoc """
  Safe inline-keyboard normalization helpers.

  `Genswarms.Telegram.Delivery.reply_markup/1` is strict and raises on invalid
  button data. This module is the tolerant boundary for user or application JSON:
  it drops malformed buttons and normalizes common callback aliases.
  """

  alias Genswarms.Telegram.{Delivery, Format}

  @doc """
  Normalize a button list into Delivery-compatible rows.

  Supports URL buttons and callback buttons. The callback key may be either
  `callback_data` or `action`; `action` is normalized to `callback_data`.
  Invalid rows/buttons are dropped. Returns nil when no valid buttons remain.
  """
  def normalize(nil), do: nil
  def normalize([]), do: nil

  def normalize(buttons) when is_list(buttons) do
    rows =
      buttons
      |> Enum.map(&normalize_row/1)
      |> Enum.reject(&(&1 == []))

    if rows == [], do: nil, else: rows
  end

  def normalize(_buttons), do: nil

  @doc "Build reply markup after tolerant normalization."
  def reply_markup(buttons) do
    case normalize(buttons) do
      nil -> nil
      rows -> Delivery.reply_markup(rows)
    end
  end

  defp normalize_row(row) when is_list(row),
    do: row |> Enum.map(&normalize_button/1) |> Enum.reject(&is_nil/1)

  defp normalize_row(single), do: [normalize_button(single)] |> Enum.reject(&is_nil/1)

  defp normalize_button(button) when is_map(button) do
    text = get(button, :text)

    cond do
      not valid_text?(text) ->
        nil

      url = get(button, :url) ->
        if is_binary(url) and Format.safe_url?(url), do: %{text: text, url: url}

      data = get(button, :callback_data) || get(button, :action) ->
        if is_binary(data) and data != "" and byte_size(data) <= 64,
          do: %{text: text, callback_data: data}

      true ->
        nil
    end
  end

  defp normalize_button(_button), do: nil

  defp valid_text?(text), do: is_binary(text) and String.trim(text) != ""

  defp get(map, key), do: Map.get(map, key) || Map.get(map, to_string(key))
end

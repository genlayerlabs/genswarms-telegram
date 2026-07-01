defmodule Genswarms.Telegram.Format do
  @moduledoc """
  Safe Telegram HTML formatting.

  Authors write a small markdown subset. The formatter emits Telegram `HTML` and
  can also produce readable plain text for parse-error fallback.
  """

  @markers ["\\", "*", "_", "`", "[", "]"]

  def to_html(md) when is_binary(md),
    do: md |> tokens([]) |> Enum.map(&html/1) |> IO.iodata_to_binary()

  def to_html(nil), do: ""
  def to_html(other), do: other |> to_string() |> to_html()

  def plain(md) when is_binary(md),
    do: md |> tokens([]) |> Enum.map(&plain_tok/1) |> IO.iodata_to_binary()

  def plain(nil), do: ""
  def plain(other), do: other |> to_string() |> plain()

  def escape_md(t) when is_binary(t),
    do: String.replace(t, ~r/[\\*_`\[\]]/, fn c -> "\\" <> c end)

  def escape_md(nil), do: ""
  def escape_md(other), do: other |> to_string() |> escape_md()

  defp tokens("", acc), do: Enum.reverse(acc)

  defp tokens(s, acc) do
    case entity(s) do
      {tok, rest} ->
        tokens(rest, [tok | acc])

      :none ->
        {lit, rest} = literal(s)
        tokens(rest, [{:text, lit} | acc])
    end
  end

  defp entity(<<"\\", c::utf8, rest::binary>>) do
    s = <<c::utf8>>
    if s in @markers, do: {{:text, s}, rest}, else: :none
  end

  defp entity("**" <> rest) do
    case close(rest, "**") do
      {inner, after_} when inner != "" -> {{:bold, inner}, after_}
      _ -> :none
    end
  end

  defp entity("`" <> rest) do
    case String.split(rest, "`", parts: 2) do
      [inner, after_] when inner != "" -> {{:code, inner}, after_}
      _ -> :none
    end
  end

  defp entity("[" <> rest) do
    case String.split(rest, "](", parts: 2) do
      [text, after_text] when text != "" ->
        case take_url(after_text, 0, "") do
          {url, after_url} when url != "" ->
            {{:link, text, url}, after_url}

          :none ->
            :none
        end

      _ ->
        :none
    end
  end

  defp entity("*" <> rest), do: italic(rest, "*")
  defp entity("_" <> rest), do: italic(rest, "_")
  defp entity(_), do: :none

  defp italic(rest, mark) do
    case close(rest, mark) do
      {inner, after_} when inner != "" -> {{:italic, inner}, after_}
      _ -> :none
    end
  end

  defp close(str, marker), do: close(str, marker, "")
  defp close("", _marker, _acc), do: :none

  defp close(<<"\\", c::utf8, rest::binary>>, marker, acc),
    do: close(rest, marker, acc <> "\\" <> <<c::utf8>>)

  defp close(str, marker, acc) do
    if String.starts_with?(str, marker) do
      {acc, String.replace_prefix(str, marker, "")}
    else
      <<c::utf8, rest::binary>> = str
      close(rest, marker, acc <> <<c::utf8>>)
    end
  end

  defp literal(s) do
    case Regex.run(~r/^[^\\*_`\[\]]+/u, s) do
      [run] -> {run, String.replace_prefix(s, run, "")}
      nil -> {String.slice(s, 0, 1), String.slice(s, 1..-1//1)}
    end
  end

  defp take_url("", _depth, _acc), do: :none

  defp take_url(<<")", rest::binary>>, 0, acc), do: {acc, rest}
  defp take_url(<<")", rest::binary>>, depth, acc), do: take_url(rest, depth - 1, acc <> ")")
  defp take_url(<<"(", rest::binary>>, depth, acc), do: take_url(rest, depth + 1, acc <> "(")

  defp take_url(<<c::utf8, _rest::binary>>, _depth, _acc) when c in [?\s, ?\n, ?\r, ?\t],
    do: :none

  defp take_url(<<c::utf8, rest::binary>>, depth, acc),
    do: take_url(rest, depth, acc <> <<c::utf8>>)

  defp html({:text, t}), do: esc_text(t)
  defp html({:bold, t}), do: ["<b>", esc_text(t), "</b>"]
  defp html({:italic, t}), do: ["<i>", esc_text(t), "</i>"]
  defp html({:code, t}), do: ["<code>", esc(t), "</code>"]

  defp html({:link, text, url}) do
    if safe_url?(url),
      do: ["<a href=\"", esc_attr(url), "\">", esc_text(text), "</a>"],
      else: esc_text(text)
  end

  defp plain_tok({:text, t}), do: deescape(t)
  defp plain_tok({:bold, t}), do: deescape(t)
  defp plain_tok({:italic, t}), do: deescape(t)
  defp plain_tok({:code, t}), do: t

  defp plain_tok({:link, text, url}) do
    text = deescape(text)
    if text == url or text == "", do: url, else: [text, " (", url, ")"]
  end

  defp esc_text(t), do: t |> deescape() |> esc()
  defp deescape(t), do: String.replace(t, ~r/\\([\\*_`\[\]])/, "\\1")

  defp esc(t) do
    t
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
  end

  defp esc_attr(url), do: url |> esc() |> String.replace("\"", "&quot;")

  def safe_url?(url), do: String.match?(to_string(url), ~r{^(https?|tg|mailto):}i)
end

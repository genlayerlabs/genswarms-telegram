defmodule Genswarms.Telegram.CardExamplesCoverageTest do
  use ExUnit.Case, async: true

  alias Genswarms.Telegram.Card

  test "examples cover every block kind" do
    covered =
      Card.examples()
      |> Enum.flat_map(fn ex -> block_kinds(ex[:card]) end)
      |> MapSet.new()

    all = MapSet.new(Card.schema_info().blocks)
    # `math` is an alias of `mathematical_expression`; either counts.
    missing =
      all
      |> MapSet.difference(covered)
      |> MapSet.delete("math")

    assert MapSet.size(missing) == 0,
           "block kinds with no example: #{inspect(MapSet.to_list(missing))}"
  end

  defp block_kinds(nil), do: []

  defp block_kinds(card) do
    (card["blocks"] || [])
    |> Enum.flat_map(fn block ->
      [block["kind"]] ++ block_kinds(%{"blocks" => block["blocks"] || []})
    end)
    |> Enum.reject(&is_nil/1)
  end
end

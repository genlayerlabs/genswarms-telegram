defmodule Genswarms.Telegram.AdapterTest do
  use ExUnit.Case

  alias Genswarms.Telegram.Adapter

  defmodule BareAdapter do
    def ping(value), do: {:bare, value}
  end

  defmodule TupleAdapter do
    def ping(value, opts), do: {:tuple, value, opts}
  end

  test "bare adapters call the requested arity" do
    assert Adapter.call(BareAdapter, :ping, [:ok]) == {:bare, :ok}
    assert Adapter.exported?(BareAdapter, :ping, 1)
  end

  test "tuple adapters receive their opts even when the opts map is empty" do
    assert Adapter.call({TupleAdapter, %{}}, :ping, [:ok]) == {:tuple, :ok, %{}}
    assert Adapter.exported?({TupleAdapter, %{}}, :ping, 1)
  end

  test "tuple adapters normalize keyword opts" do
    assert Adapter.call({TupleAdapter, [mode: :test]}, :ping, [:ok]) ==
             {:tuple, :ok, %{mode: :test}}
  end
end

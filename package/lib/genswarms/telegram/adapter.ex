defmodule Genswarms.Telegram.Adapter do
  @moduledoc false

  def module({module, _opts}) when is_atom(module), do: module
  def module(module) when is_atom(module), do: module

  def opts({_module, opts}) when is_map(opts), do: opts
  def opts({_module, opts}) when is_list(opts), do: Map.new(opts)
  def opts(_module), do: %{}

  def call(adapter, fun, args) when is_atom(fun) and is_list(args) do
    module = module(adapter)
    opts = opts(adapter)
    arity = length(args)
    _ = Code.ensure_loaded(module)

    cond do
      tuple_adapter?(adapter) and function_exported?(module, fun, arity + 1) ->
        apply(module, fun, args ++ [opts])

      function_exported?(module, fun, arity) ->
        apply(module, fun, args)

      true ->
        raise UndefinedFunctionError, module: module, function: fun, arity: arity
    end
  end

  def exported?(adapter, fun, arity) do
    module = module(adapter)
    _ = Code.ensure_loaded(module)

    function_exported?(module, fun, arity) or
      (tuple_adapter?(adapter) and function_exported?(module, fun, arity + 1))
  end

  defp tuple_adapter?({module, _opts}) when is_atom(module), do: true
  defp tuple_adapter?(_adapter), do: false
end

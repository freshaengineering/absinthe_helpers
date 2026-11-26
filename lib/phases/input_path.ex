defmodule AbsintheHelpers.Phases.InputPath do
  @moduledoc false

  alias Absinthe.Blueprint
  alias Absinthe.Blueprint.Input

  @doc """
  Calls `fun` with every argument and input field node of every field in the document, children
  first, along with the node's path from its argument (`["input", "items", 0, "quantity"]`),
  and puts back the node `fun` returns.
  """
  def map(blueprint, fun) do
    Blueprint.prewalk(blueprint, fn
      field = %Blueprint.Document.Field{arguments: arguments} ->
        %{field | arguments: Enum.map(arguments, &walk(&1, [&1.name], fun))}

      node ->
        node
    end)
  end

  defp walk(node = %{input_value: value = %Input.Value{normalized: normalized}}, path, fun) do
    fun.(%{node | input_value: %{value | normalized: walk_value(normalized, path, fun)}}, path)
  end

  defp walk(node, _path, _fun), do: node

  defp walk_value(object = %Input.Object{fields: fields}, path, fun) do
    %{object | fields: Enum.map(fields, &walk(&1, path ++ [&1.name], fun))}
  end

  defp walk_value(list = %Input.List{items: items}, path, fun) do
    items =
      items
      |> Enum.with_index()
      |> Enum.map(fn {item = %{normalized: normalized}, index} ->
        %{item | normalized: walk_value(normalized, path ++ [index], fun)}
      end)

    %{list | items: items}
  end

  defp walk_value(value, _path, _fun), do: value
end

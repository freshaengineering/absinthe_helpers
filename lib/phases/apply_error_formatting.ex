defmodule AbsintheHelpers.Phases.ApplyErrorFormatting do
  @moduledoc false

  alias Absinthe.{Blueprint, Phase}
  use Absinthe.Phase

  def add_to_pipeline(pipeline, opts) do
    Absinthe.Pipeline.insert_after(
      pipeline,
      Phase.Document.Result,
      {__MODULE__, opts}
    )
  end

  @spec run(Blueprint.t() | Phase.Error.t(), Keyword.t()) :: {:ok, Blueprint.t()}
  def run(blueprint = %Blueprint{}, _options) do
    {:ok, %{blueprint | result: format_errors(blueprint.result)}}
  end

  defp format_errors(%{errors: errors} = result) when is_list(errors) do
    %{result | errors: format_error_list(errors)}
  end

  defp format_errors(result), do: result

  defp format_error_list(errors) do
    errors
    |> Enum.group_by(&get_error_code/1)
    |> Enum.flat_map(&format_error_group/1)
  end

  defp get_error_code(%{group_code: group_code}), do: group_code
  defp get_error_code(_), do: nil

  defp format_error_group({nil, errors}), do: errors

  defp format_error_group({group_code, errors}) do
    [
      %{
        message: "Invalid input",
        locations: [],
        extensions: %{
          code: group_code,
          details: %{
            fields: Enum.map(errors, &format_field/1)
          }
        }
      }
    ]
  end

  defp format_field(%{
         message: message,
         locations: locations,
         path: path,
         code: code,
         details: details
       }) do
    %{
      message: message,
      path: path,
      reason: code |> to_string() |> String.upcase(),
      custom_error_code: code,
      details: details,
      locations: locations
    }
  end

  defp format_field(error), do: error
end

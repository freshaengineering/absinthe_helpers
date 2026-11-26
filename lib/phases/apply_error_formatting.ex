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
  def run(blueprint = %Blueprint{}, options) do
    field_paths = Keyword.get(options, :field_paths, :leaf)
    {:ok, %{blueprint | result: format_errors(blueprint.result, field_paths)}}
  end

  defp format_errors(%{errors: errors} = result, field_paths) when is_list(errors) do
    %{result | errors: format_error_list(errors, field_paths)}
  end

  defp format_errors(result, _field_paths), do: result

  defp format_error_list(errors, field_paths) do
    errors
    |> Enum.group_by(&get_error_code/1)
    |> Enum.flat_map(&format_error_group(&1, field_paths))
  end

  defp get_error_code(%{group_code: group_code}), do: group_code
  defp get_error_code(_), do: nil

  defp format_error_group({nil, errors}, _field_paths), do: errors

  defp format_error_group({group_code, errors}, field_paths) do
    [
      %{
        message: "Invalid input",
        locations: [],
        extensions: %{
          code: group_code,
          details: %{
            fields: Enum.map(errors, &format_field(&1, field_paths))
          }
        }
      }
    ]
  end

  defp format_field(
         error = %{
           message: message,
           locations: locations,
           path: path,
           code: code,
           details: details
         },
         field_paths
       ) do
    %{
      message: message,
      path: if(field_paths == :full, do: Map.get(error, :input_path, path), else: path),
      reason: code |> to_string() |> String.upcase(),
      custom_error_code: code,
      details: details,
      locations: locations
    }
  end

  defp format_field(error, _field_paths), do: error
end

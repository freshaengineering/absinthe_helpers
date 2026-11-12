defmodule AbsintheHelpers.Directives do
  @moduledoc """
  A prototype schema with every directive of this package: `:constraints` and
  `:timeout`. A schema takes one `@prototype_schema`, so use this module when it
  needs both.

      defmodule MyApp.Schema do
        use Absinthe.Schema
        @prototype_schema AbsintheHelpers.Directives

        import_directives AbsintheHelpers.Directives, only: [:constraints, :timeout]
      end

  `import_directives` puts the directive definitions into the SDL of the schema.

  `:constraints` works as in `AbsintheHelpers.Directives.Constraints`.

  `:timeout` declares how many milliseconds a gateway waits for a root query or
  mutation field. The schema does not enforce it. On other fields it has no
  effect.

      field :report, :report, directives: [timeout: [ms: 30_000]]
  """

  use Absinthe.Schema.Prototype

  alias AbsintheHelpers.Directives.Constraints

  directive :constraints do
    on([:argument_definition, :field_definition, :input_field_definition])

    arg(:min, :integer, description: "Minimum value allowed")
    arg(:max, :integer, description: "Maximum value allowed")

    arg(:min_items, :integer, description: "Minimum number of items allowed in a list")
    arg(:max_items, :integer, description: "Maximum number of items allowed in a list")

    arg(:regex, :string, description: "Pattern to match for a string")

    expand(&Constraints.expand_constraints/2)
  end

  directive :timeout do
    on([:field_definition])

    arg(:ms, non_null(:integer), description: "Milliseconds that a gateway waits for the field")

    expand(&__MODULE__.expand_timeout/2)
  end

  def expand_timeout(%{ms: ms}, node) when is_integer(ms) and ms > 0, do: node

  def expand_timeout(%{ms: ms}, %{name: name, __reference__: reference}) do
    raise Absinthe.Schema.Error,
      phase_errors: [
        %Absinthe.Phase.Error{
          phase: __MODULE__,
          message:
            "Invalid timeout for field `#{name}`: ms must be a positive integer, got #{inspect(ms)}",
          locations: [%{line: get_in(reference, [:location, :line]), column: 0}]
        }
      ]
  end
end

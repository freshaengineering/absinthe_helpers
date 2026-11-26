# Absinthe Helpers

This package provides three key features:

1. **constraints**: enforce validation rules (like `min`, `max`, etc.) on fields and arguments in your schema
2. **transforms**: apply custom transformations (like `Trim`, `ToInteger`, etc.) to input fields and arguments
3. **error formatting**: GraphQL specification compliant error formatting for validation and transform failures

## Installation

Add `absinthe_helpers` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:absinthe_helpers, "~> 0.3"}
  ]
end
```

Then, run:

```bash
mix deps.get
```

### Setup: adding constraints, transforms, and error formatting to your Absinthe pipeline

Follow these steps:

1. Add constraints, transforms, and error formatting to your Absinthe pipeline:

```elixir
forward "/graphql",
    to: Absinthe.Plug,
    init_opts: [
      schema: MyProject.Schema,
      pipeline: {__MODULE__, :absinthe_pipeline},
    ]

def absinthe_pipeline(config, opts) do
  config
  |> Absinthe.Plug.default_pipeline(opts)
  |> AbsintheHelpers.Phases.ApplyConstraints.add_to_pipeline(opts)
  |> AbsintheHelpers.Phases.ApplyTransforms.add_to_pipeline(opts)
  |> AbsintheHelpers.Phases.ApplyErrorFormatting.add_to_pipeline(opts)
end
```

2. Add constraints to your schema:

```elixir
defmodule MyApp.Schema do
  use Absinthe.Schema
  @prototype_schema AbsintheHelpers.Directives.Constraints

  directive :constraints do
    on([:argument_definition, :field_definition, :input_field_definition])

    arg(:min, :integer, description: "Minimum value allowed")
    arg(:max, :integer, description: "Maximum value allowed")
    arg(:min_items, :integer, description: "Minimum number of items allowed in a list")
    arg(:max_items, :integer, description: "Maximum number of items allowed in a list")
    arg(:regex, :string, description: "Pattern to match for a string")
  end

  query do
  end

  mutation do
  end

  # ...
end
```

---

## Constraints

The `constraints` directive allows you to enforce validation rules on fields and arguments in your GraphQL schema. Constraints are applied at the schema level and are visible in the GraphQL schema, making them accessible to the frontend.

### Example: graphql schema with constraints

```graphql
"Overrides for location-specific service pricing."
input LocationOverrideInput {
  duration: Int @constraints(min: 300, max: 43200)
  price: Decimal @constraints(min: 0, max: 100000000)
  priceType: ServicePriceType
  locationId: ID!
}
```

### How to use constraints

1. Apply constraints to a field or argument:

```elixir
field :my_list, list_of(:integer) do
  directive(:constraints, [min_items: 2, max_items: 5, min: 1, max: 100])

  resolve(&MyResolver.resolve/3)
end

field :my_field, :integer do
  arg :my_arg, non_null(:string), directives: [constraints: [min: 10, regex: "^[a-zA-Z]+$"]]

  resolve(&MyResolver.resolve/3)
end
```

---

## Transforms

Transforms allow you to modify or coerce input values at runtime. You can apply these transformations to individual fields, lists, or arguments in your Absinthe schema.

### Example: applying transforms in your schema

1. Apply transforms directly to a field:

```elixir
alias AbsintheHelpers.Transforms.ToInteger
alias AbsintheHelpers.Transforms.Trim
alias AbsintheHelpers.Transforms.Increment

field :employee_id, :id do
  meta transforms: [Trim, ToInteger, {Increment, 3}]
end
```

2. Apply transforms to a list of values:

```elixir
field :employee_ids, non_null(list_of(non_null(:id))) do
  meta transforms: [Trim, ToInteger, {Increment, 3}]
end
```

3. Apply transforms to an argument:

```elixir
field(:create_booking, :string) do
  arg(:employee_id, non_null(:id),
    __private__: [meta: [transforms: [Trim, ToInteger, {Increment, 3}]]]
  )

  resolve(&TestResolver.run/3)
end
```

## Error Formatting

The package includes GraphQL specification compliant error formatting. When enabled, validation errors from constraints or transform failures are formatted consistently.

For multiple related errors, they are grouped under a single error with BAD_USER_INPUT code. Each field's `path` starts from the argument name and includes list indexes, and `reason` is the failure in SCREAMING_SNAKE_CASE:

```json
{
  "errors": [
    {
      "message": "Invalid input",
      "extensions": {
        "code": "BAD_USER_INPUT",
        "details": {
          "fields": [
            {
              "message": "min_not_met",
              "path": ["input", "description"],
              "reason": "MIN_NOT_MET",
              "details": {
                "min": 5
              },
              "locations": [
                {
                  "line": 6,
                  "column": 7
                }
              ],
              "custom_error_code": "min_not_met"
            },
            {
              "message": "max_exceeded",
              "path": ["input", "lineItems", 1, "quantity"],
              "reason": "MAX_EXCEEDED",
              "details": {
                "max": 10
              },
              "locations": [
                {
                  "line": 7,
                  "column": 7
                }
              ],
              "custom_error_code": "max_exceeded"
            }
          ]
        }
      },
      "locations": []
    }
  ]
}
```

`custom_error_code` is deprecated in favour of `reason` and will be removed in a later release.

Without `ApplyErrorFormatting` in the pipeline, constraint and transform failures reach the client with `code`, `group_code` and `path` on the error itself and no `extensions`, which no GraphQL client expects. Add it whenever you add `ApplyConstraints` or `ApplyTransforms`.

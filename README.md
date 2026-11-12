# Absinthe Helpers

This package provides four key features:

1. **constraints**: enforce validation rules (like `min`, `max`, etc.) on fields and arguments in your schema
2. **transforms**: apply custom transformations (like `Trim`, `ToInteger`, etc.) to input fields and arguments
3. **error formatting**: GraphQL specification compliant error formatting for validation and transform failures
4. **timeout**: declare in the schema how long a gateway waits for a root query or mutation field

## Installation

Add `absinthe_helpers` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:absinthe_helpers, "~> 0.1.0"}
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

2. Add the directives to your schema:

```elixir
defmodule MyApp.Schema do
  use Absinthe.Schema
  @prototype_schema AbsintheHelpers.Directives

  import_directives AbsintheHelpers.Directives, only: [:constraints, :timeout]

  query do
  end

  mutation do
  end

  # ...
end
```

`@prototype_schema` lets fields and arguments use the directives. `import_directives` puts their definitions into the SDL of the schema. A schema takes one `@prototype_schema`, so `AbsintheHelpers.Directives` holds both directives. `AbsintheHelpers.Directives.Constraints` still works for a schema that uses only `constraints`.

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

## Timeout

The `timeout` directive declares how many milliseconds a gateway waits for a root query or mutation field. The schema does not enforce it: the gateway reads it from the SDL. On other fields it has no effect.

```elixir
query do
  field :report, :report do
    directive(:timeout, ms: 30_000)

    resolve(&MyResolver.resolve/3)
  end
end
```

The SDL shows it on the field:

```graphql
type RootQueryType {
  report: Report @timeout(ms: 30000)
}
```

`ms` must be a positive integer. Any other value fails at compile time.

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

For multiple related errors, they are grouped under a single error with BAD_USER_INPUT code:

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
              "path": ["description"],
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
              "path": ["title"],
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

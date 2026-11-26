defmodule AbsintheHelpers.Phases.ApplyConstraintsTest do
  use ExUnit.Case, async: true

  alias AbsintheHelpers.Phases.ApplyConstraints
  alias AbsintheHelpers.Phases.ApplyErrorFormatting
  alias AbsintheHelpers.TestResolver

  describe "apply constraints phase with min/max on integers, decimals, and strings" do
    defmodule TestSchema do
      use Absinthe.Schema

      import_types(Absinthe.Type.Custom)

      @prototype_schema AbsintheHelpers.Directives.Constraints

      directive :limit do
        on([:field])
        arg(:count, :integer, directives: [constraints: [min: 1]])
      end

      query do
        field :get_booking, non_null(:string) do
          resolve(&TestResolver.run/3)
        end

        field :ratings, :string do
          arg(:scores, list_of(:integer), directives: [constraints: [max: 10]])
          resolve(fn _, _, _ -> {:ok, "ok"} end)
        end
      end

      mutation do
        field(:create_booking, :string) do
          arg(:customer_id, non_null(:integer), directives: [constraints: [min: 1, max: 1000]])
          arg(:service, non_null(:service_input))
          arg(:lines, list_of(non_null(:line_input)))

          resolve(&TestResolver.run/3)
        end
      end

      input_object :line_input do
        field(:quantity, :integer, directives: [constraints: [min: 1]])
      end

      input_object :service_input do
        field(:cost, :decimal, directives: [constraints: [min: 10, max: 1000]])

        field(:description, :string) do
          directive(:constraints, regex: "^[a-zA-Z\s]+$", min: 5, max: 50)
        end

        field(:override_ids, non_null(list_of(non_null(:integer)))) do
          directive(:constraints, min_items: 3, min: 5, max: 50)
        end

        field(:location_ids, non_null(list_of(non_null(:integer)))) do
          directive(:constraints, min_items: 2, min: 5, max: 50)
        end

        field(:commission_ids, non_null(list_of(non_null(:integer)))) do
          directive(:constraints, max_items: 2)
        end
      end

      def run_query(query) do
        Absinthe.run(
          query,
          __MODULE__,
          pipeline_modifier: &ApplyConstraints.add_to_pipeline/2
        )
      end

      def run_formatted_query(query, formatting_opts \\ []) do
        Absinthe.run(
          query,
          __MODULE__,
          pipeline_modifier: fn pipeline, opts ->
            pipeline
            |> ApplyConstraints.add_to_pipeline(opts)
            |> ApplyErrorFormatting.add_to_pipeline(opts ++ formatting_opts)
          end
        )
      end
    end

    @valid_service """
    service: {
      cost: "150.75",
      description: "Valid description",
      override_ids: [6, 7, 8],
      location_ids: [8, 9, 10],
      commission_ids: []
    }
    """

    test "applies constraints to directive arguments" do
      assert {:ok, %{errors: [%{code: :min_not_met, path: ["count"]}]}} =
               TestSchema.run_query("{ getBooking @limit(count: 0) }")
    end

    test "leaves null list items to the list's own nullability" do
      assert {:ok, %{data: %{"ratings" => "ok"}}} =
               TestSchema.run_query("{ ratings(scores: [1, null, 10]) }")
    end

    test "reports a field inside a list of input objects with its full path as input_path" do
      query = """
      mutation {
        create_booking(customer_id: 1, #{@valid_service}, lines: [{quantity: 2}, {quantity: 0}])
      }
      """

      assert {:ok,
              %{
                errors: [
                  %{code: :min_not_met, path: ["quantity"], input_path: ["lines", 1, "quantity"]}
                ]
              }} =
               TestSchema.run_query(query)
    end

    test "formats field errors with the leaf name as the path by default" do
      query = """
      mutation {
        create_booking(customer_id: 0, #{@valid_service}, lines: [{quantity: 0}])
      }
      """

      assert {:ok, %{errors: [%{extensions: %{code: :BAD_USER_INPUT, details: %{fields: fields}}}]}} =
               TestSchema.run_formatted_query(query)

      assert [
               %{path: ["customer_id"], reason: "MIN_NOT_MET"},
               %{path: ["quantity"], reason: "MIN_NOT_MET"}
             ] = fields

      refute Enum.any?(fields, &Map.has_key?(&1, :input_path))
    end

    test "formats field errors with the path from the argument with field_paths: :full" do
      query = """
      mutation {
        create_booking(customer_id: 0, #{@valid_service}, lines: [{quantity: 0}])
      }
      """

      assert {:ok, %{errors: [%{extensions: %{details: %{fields: fields}}}]}} =
               TestSchema.run_formatted_query(query, field_paths: :full)

      assert [%{path: ["customer_id"]}, %{path: ["lines", 0, "quantity"]}] = fields
    end

    @short_description """
    mutation {
      create_booking(
        customer_id: 1,
        service: {
          cost: "150.75",
          description: "bad",
          override_ids: [6, 7, 8],
          location_ids: [8, 9, 10],
          commission_ids: []
        }
      )
    }
    """

    test "a form mapping errors by path.join(\".\") still finds description in unformatted errors" do
      assert {:ok, %{errors: [%{path: path}]}} = TestSchema.run_query(@short_description)

      assert Enum.join(path, ".") == "description"
    end

    test "a form mapping errors by path.join(\".\") still finds description in formatted errors" do
      assert {:ok, %{errors: [%{extensions: %{details: %{fields: [%{path: path}]}}}]}} =
               TestSchema.run_formatted_query(@short_description)

      assert Enum.join(path, ".") == "description"
    end

    test "field_paths: :full moves description to service.description, so a form has to opt in" do
      assert {:ok, %{errors: [%{extensions: %{details: %{fields: [%{path: path}]}}}]}} =
               TestSchema.run_formatted_query(@short_description, field_paths: :full)

      assert Enum.join(path, ".") == "service.description"
    end

    test "validates mutation arguments including decimal and string constraints and returns success" do
      query = """
      mutation {
        create_booking(
          customer_id: 1,
          service: {
            cost: "150.75",
            description: "Valid description",
            override_ids: [6, 7, 8],
            location_ids: [8, 9, 10],
            commission_ids: []
          }
        )
      }
      """

      assert TestSchema.run_query(query) == {:ok, %{data: %{"create_booking" => ""}}}
    end

    test "returns errors for invalid decimal and string arguments" do
      query = """
      mutation {
        create_booking(
          customer_id: 1001,
          service: {
            cost: "5.00",
            description: "bad",
            override_ids: [6, 1, 7],
            location_ids: [1],
            commission_ids: [1, 2, 3]
          }
        )
      }
      """

      assert {
               :ok,
               %{
                 errors: [
                   %{
                     details: %{max: 1000},
                     message: :max_exceeded,
                     code: :max_exceeded,
                     group_code: :BAD_USER_INPUT,
                     locations: [%{line: 3, column: 5}],
                     path: ["customer_id"]
                   },
                   %{
                     details: %{min: 10},
                     message: :min_not_met,
                     code: :min_not_met,
                     group_code: :BAD_USER_INPUT,
                     locations: [%{line: 5, column: 7}],
                     path: ["cost"],
                     input_path: ["service", "cost"]
                   },
                   %{
                     details: %{min: 5},
                     message: :min_not_met,
                     code: :min_not_met,
                     group_code: :BAD_USER_INPUT,
                     locations: [%{line: 6, column: 7}],
                     path: ["description"],
                     input_path: ["service", "description"]
                   },
                   %{
                     details: %{min: 5},
                     message: :min_not_met,
                     code: :min_not_met,
                     group_code: :BAD_USER_INPUT,
                     locations: [%{line: 7, column: 7}],
                     path: ["override_ids"],
                     input_path: ["service", "override_ids", 1]
                   },
                   %{
                     details: %{min_items: 2},
                     message: :min_items_not_met,
                     code: :min_items_not_met,
                     group_code: :BAD_USER_INPUT,
                     locations: [%{line: 8, column: 7}],
                     path: ["location_ids"],
                     input_path: ["service", "location_ids"]
                   },
                   %{
                     details: %{max_items: 2},
                     message: :max_items_exceeded,
                     code: :max_items_exceeded,
                     group_code: :BAD_USER_INPUT,
                     locations: [%{line: 9, column: 7}],
                     path: ["commission_ids"],
                     input_path: ["service", "commission_ids"]
                   }
                 ]
               }
             } = TestSchema.run_query(query)
    end

    test "returns invalid_format on strings that do not match regex pattern" do
      query = """
      mutation {
        create_booking(
          customer_id: 1,
          service: {
            cost: "150.75",
            description: "invalid-description",
            override_ids: [6, 7, 8],
            location_ids: [8, 9, 10],
            commission_ids: []
          }
        )
      }
      """

      assert {:ok,
              %{
                errors: [
                  %{
                    details: %{regex: "^[a-zA-Z ]+$"},
                    message: :invalid_format,
                    code: :invalid_format,
                    group_code: :BAD_USER_INPUT,
                    locations: [%{line: 6, column: 7}],
                    path: ["description"],
                    input_path: ["service", "description"]
                  }
                ]
              }} = TestSchema.run_query(query)
    end
  end
end

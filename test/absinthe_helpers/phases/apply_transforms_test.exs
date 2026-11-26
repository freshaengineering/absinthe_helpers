defmodule AbsintheHelpers.Phases.ApplyTransformsTest do
  use ExUnit.Case, async: true
  use Mimic

  alias AbsintheHelpers.Phases.ApplyTransforms
  alias AbsintheHelpers.TestResolver
  alias AbsintheHelpers.Transforms.Increment
  alias AbsintheHelpers.Transforms.ToInteger
  alias AbsintheHelpers.Transforms.Trim

  describe "apply transforms phase" do
    defmodule TestSchema do
      use Absinthe.Schema

      query do
        field :get_booking, non_null(:string) do
          resolve(&TestResolver.run/3)
        end
      end

      mutation do
        field(:create_booking, :string) do
          arg(:customer_id, non_null(:id), __private__: [meta: [transforms: [Trim, ToInteger]]])

          arg(:service, non_null(:service_input))

          resolve(&TestResolver.run/3)
        end
      end

      input_object :service_input do
        field(:employee_id, :id, meta: [transforms: [ToInteger]])

        field(:override_ids, non_null(list_of(non_null(:id)))) do
          meta(transforms: [Trim, ToInteger])
        end

        field(:accumulator, :string) do
          meta(transforms: [ToInteger, {Increment, 3}])
        end
      end

      def run_query(query) do
        Absinthe.run(
          query,
          __MODULE__,
          pipeline_modifier: &ApplyTransforms.add_to_pipeline/2
        )
      end
    end

    test "applies transforms to graphql document" do
      expect(
        TestResolver,
        :run,
        fn _, input, _ ->
          assert input == %{
                   customer_id: 1,
                   service: %{
                     employee_id: 456,
                     override_ids: [1, 2, 3],
                     accumulator: 4
                   }
                 }

          {:ok, ""}
        end
      )

      query = """
      mutation {
        create_booking(
          customer_id: "  1 ",
          service: {
            employee_id: "456",
            override_ids: ["1", "  2", "3"]
            accumulator: "1"
          }
        )
      }
      """

      assert TestSchema.run_query(query) == {:ok, %{data: %{"create_booking" => ""}}}
    end

    test "reports a failure in the middle of a chain of transforms" do
      query = """
      mutation {
        create_booking(
          customer_id: "1",
          service: {employee_id: "456", override_ids: ["1"], accumulator: "abc"}
        )
      }
      """

      assert {:ok, %{errors: [%{code: :invalid_integer, path: ["service", "accumulator"]}]}} =
               TestSchema.run_query(query)
    end

    test "propagates errors from transforms" do
      query = """
      mutation {
        create_booking(
          customer_id: "bad",
          service: {
            employee_id: "456",
            override_ids: ["1", "abc123", "3"],
            accumulator: "1"
          }
        )
      }
      """

      assert TestSchema.run_query(query) ==
               {:ok,
                %{
                  errors: [
                    %{
                      details: %{},
                      message: :invalid_integer,
                      code: :invalid_integer,
                      group_code: :BAD_USER_INPUT,
                      locations: [%{line: 3, column: 5}],
                      path: ["customer_id"]
                    },
                    %{
                      details: %{},
                      message: :invalid_integer,
                      code: :invalid_integer,
                      group_code: :BAD_USER_INPUT,
                      locations: [%{line: 6, column: 7}],
                      path: ["service", "override_ids", 1]
                    }
                  ]
                }}
    end
  end
end

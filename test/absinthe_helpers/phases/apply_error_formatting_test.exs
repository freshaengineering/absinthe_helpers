defmodule AbsintheHelpers.Phases.ApplyErrorFormattingTest do
  use ExUnit.Case, async: true

  alias Absinthe.Blueprint
  alias AbsintheHelpers.Phases.ApplyErrorFormatting

  describe "apply error formatting phase" do
    test "formats single error without group code" do
      blueprint = %Blueprint{
        result: %{
          errors: [
            %{
              message: :min_not_met,
              code: :min_not_met,
              details: %{min: 5},
              path: ["description"],
              locations: [%{line: 6, column: 7}]
            }
          ]
        }
      }

      assert {
               :ok,
               %Blueprint{
                 result: %{
                   errors: [
                     %{
                       code: :min_not_met,
                       message: :min_not_met,
                       path: ["description"],
                       details: %{min: 5},
                       locations: [%{line: 6, column: 7}]
                     }
                   ]
                 }
               }
             } == ApplyErrorFormatting.run(blueprint, [])
    end

    test "groups errors by group_code and formats them" do
      blueprint = %Blueprint{
        result: %{
          errors: [
            %{
              message: :min_not_met,
              code: :min_not_met,
              group_code: :BAD_USER_INPUT,
              details: %{min: 5},
              path: ["description"],
              locations: [%{line: 6, column: 7}]
            },
            %{
              message: :max_exceeded,
              code: :max_exceeded,
              group_code: :BAD_USER_INPUT,
              details: %{max: 10},
              path: ["title"],
              locations: [%{line: 7, column: 7}]
            }
          ]
        }
      }

      assert {
               :ok,
               %Blueprint{
                 result: %{
                   errors: [
                     %{
                       message: "Invalid input",
                       extensions: %{
                         code: :BAD_USER_INPUT,
                         details: %{
                           fields: [
                             %{
                               message: :min_not_met,
                               path: ["description"],
                               details: %{min: 5},
                               locations: [%{line: 6, column: 7}],
                               reason: "MIN_NOT_MET",
                               custom_error_code: :min_not_met
                             },
                             %{
                               message: :max_exceeded,
                               path: ["title"],
                               details: %{max: 10},
                               locations: [%{line: 7, column: 7}],
                               reason: "MAX_EXCEEDED",
                               custom_error_code: :max_exceeded
                             }
                           ]
                         }
                       },
                       locations: []
                     }
                   ]
                 }
               }
             } = ApplyErrorFormatting.run(blueprint, [])
    end

    test "handles empty error list" do
      blueprint = %Blueprint{result: %{errors: []}}

      assert {:ok, %Blueprint{result: %{errors: []}}} =
               ApplyErrorFormatting.run(blueprint, [])
    end

    test "handles result without errors" do
      blueprint = %Blueprint{result: %{data: %{some: "data"}}}

      assert {:ok, %Blueprint{result: %{data: %{some: "data"}}}} =
               ApplyErrorFormatting.run(blueprint, [])
    end
  end
end

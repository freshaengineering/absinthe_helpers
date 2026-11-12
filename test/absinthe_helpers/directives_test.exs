defmodule AbsintheHelpers.DirectivesTest do
  use ExUnit.Case, async: true

  alias AbsintheHelpers.Phases.ApplyConstraints
  alias AbsintheHelpers.TestResolver

  defmodule TestSchema do
    use Absinthe.Schema

    @prototype_schema AbsintheHelpers.Directives

    import_directives(AbsintheHelpers.Directives, only: [:constraints, :timeout])

    query do
      field :report, :string do
        directive(:timeout, ms: 30_000)
        arg(:name, :string, directives: [constraints: [min: 2]])

        resolve(&TestResolver.run/3)
      end
    end

    mutation do
      field :create_report, :string, directives: [timeout: [ms: 2_000]] do
        arg(:input, non_null(:report_input))

        resolve(&TestResolver.run/3)
      end
    end

    input_object :report_input do
      field(:title, :string, directives: [constraints: [max: 5]])
    end
  end

  defp run(query) do
    Absinthe.run(query, TestSchema, pipeline_modifier: &ApplyConstraints.add_to_pipeline/2)
  end

  describe "timeout" do
    test "prints the definition and each applied directive in the SDL" do
      sdl = Absinthe.Schema.to_sdl(TestSchema)

      assert sdl =~ ~r/directive @timeout\([^)]*ms: Int!\s*\) on FIELD_DEFINITION/
      assert sdl =~ ~r/report\(.*\): String @timeout\(ms: 30000\)/
      assert sdl =~ ~r/createReport\(.*\): String @timeout\(ms: 2000\)/
    end

    for ms <- [0, -1] do
      test "rejects ms: #{ms} at compile time" do
        assert_raise Absinthe.Schema.Error, ~r/Invalid timeout for field `report`/, fn ->
          Code.compile_string("""
          defmodule AbsintheHelpers.DirectivesTest.InvalidTimeout#{abs(unquote(ms))} do
            use Absinthe.Schema
            @prototype_schema AbsintheHelpers.Directives

            query do
              field :report, :string, directives: [timeout: [ms: #{unquote(ms)}]]
            end
          end
          """)
        end
      end
    end
  end

  describe "constraints" do
    test "prints the definition and each applied directive in the SDL" do
      sdl = Absinthe.Schema.to_sdl(TestSchema)

      assert sdl =~ "directive @constraints("
      assert sdl =~ "name: String @constraints(min: 2)"
      assert sdl =~ "title: String @constraints(max: 5)"
    end

    test "enforces a constraint on an argument" do
      assert {:ok, %{errors: [%{code: :min_not_met, path: ["name"]}]}} =
               run(~s|{ report(name: "a") }|)

      assert {:ok, %{data: %{"report" => ""}}} = run(~s|{ report(name: "ab") }|)
    end

    test "enforces a constraint on an input field" do
      assert {:ok, %{errors: [%{code: :max_exceeded}]}} =
               run(~s|mutation { createReport(input: {title: "too long"}) }|)
    end
  end
end

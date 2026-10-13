defmodule AbsintheHelpers.MixProject do
  use Mix.Project

  def project do
    [
      app: :absinthe_helpers,
      version: "0.2.11",
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      elixirc_paths: elixirc_paths(Mix.env()),
      docs: [
        main: "readme",
        extras: ["README.md"]
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:junit_formatter, "~> 3.3", only: [:test]},
      {:credo, "~> 1.0", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0", only: :dev, runtime: false},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:absinthe, "~> 1.0"},
      {:mimic, "~> 1.10", only: :test},
      {:decimal, "~> 1.9 or ~> 2.0 or ~> 3.0"}
    ]
  end

  defp package do
    [
      files: ["lib", "mix.exs", "README*"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/freshaengineering/absinthe_helpers"}
    ]
  end

  defp description do
    """
    Adds support for schema constraints, type coercions, and other custom transformations.
    """
  end
end

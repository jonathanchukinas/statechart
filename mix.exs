defmodule Statechart.MixProject do
  use Mix.Project

  def project do
    [
      app: :statechart,
      version: "0.1.0",
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:dialyxir, "~>1.1", only: [:dev], runtime: false},
      {:stream_data, "~>0.5", only: [:dev, :test]},
      {:typed_struct, "~> 0.2.1"}
    ]
  end
end

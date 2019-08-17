defmodule JobsTest.MixProject do
  use Mix.Project

  def project do
    [
      app: :jobs_test,
      version: "0.1.0",
      elixir: "~> 1.7",
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
      {:jobs, "~> 0.9.0"},
      # {:jobs, path: "../jobs"},
    ]
  end
end

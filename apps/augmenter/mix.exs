defmodule Augmenter.MixProject do
  use Mix.Project

  @name :augmenter
  @version "0.1.0"
  @deps [
    {:database, in_umbrella: true},
    {:shared, in_umbrella: true},
    {:levenshtein, "~> 0.3.0"}
  ]

  def project do
    [
      app: @name,
      version: @version,
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      deps: @deps
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end
end

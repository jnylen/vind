defmodule Shared.MixProject do
  use Mix.Project

  @name :shared
  @version "0.1.0"
  @deps [
    {:database, in_umbrella: true},
    {:telemetry, "~> 0.4.0"},
    {:jsonrs, github: "nash-io/Jsonrs"},
    {:tesla, "~> 1.4.0"},
    {:cookie_jar, "~> 1.0"},
    {:calendar, "~> 1.0.0"},
    {:mime, "~> 1.2"},
    {:hackney, "~> 1.10"}
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
      mod: {Shared.Application, []},
      extra_applications: [:logger]
    ]
  end
end

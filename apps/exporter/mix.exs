defmodule Exporter.MixProject do
  use Mix.Project

  @name :exporter
  @version "0.1.0"
  @deps [
    {:exprintf, "~> 0.2.1"},
    {:shared, in_umbrella: true},
    {:database, in_umbrella: true},
    {:timex, "~> 3.4"},
    {:xmltv, github: "jnylen/xmltv_elixir"}
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

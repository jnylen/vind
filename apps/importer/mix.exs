defmodule Importer.MixProject do
  use Mix.Project

  @name :importer
  @version "0.1.0"
  @deps [
    {:augmenter, in_umbrella: true},
    {:database, in_umbrella: true},
    {:shared, in_umbrella: true},
    {:briefly, github: "CargoSense/briefly", override: true},
    {:timex, "~> 3.4"},
    {:exprintf, "~> 0.2.1"},
    {:meeseeks, "~> 0.16.0"},
    {:ok, "~> 2.0"},
    {:maybe, "~> 1.0"},
    {:country_data, "~> 0.2.0"},
    {:sweet_xml, "~> 0.7.0"},
    {:paasaa, "~> 0.5.0"},
    {:roman, "~> 0.2"},
    {:nimble_csv, "~> 1.1"},
    {:string_matcher, "~> 0.1.2"},
    {:recase, "~> 0.5"},
    {:saxy, "~> 1.4.0"},
    {:date_time_parser, "1.1.2"}
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

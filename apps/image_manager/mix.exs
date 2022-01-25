defmodule ImageManager.MixProject do
  use Mix.Project

  @name :image_manager
  @version "0.1.0"
  @deps [
    {:trunk, "~> 1.1.0"},
    {:fastimage, "~> 1.0.0-rc4"},
    {:database, in_umbrella: true},
    {:briefly, github: "CargoSense/briefly", override: true}
  ]

  def project do
    [
      app: @name,
      version: @version,
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.9",
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

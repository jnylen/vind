defmodule Worker.MixProject do
  use Mix.Project

  @name :worker
  @version "0.1.0"
  @deps [
    # RabbitMQ
    {:database, in_umbrella: true}
  ]

  def project do
    [
      app: @name,
      version: @version,
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: @deps
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Worker.Application, []}
    ]
  end
end

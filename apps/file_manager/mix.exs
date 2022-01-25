defmodule FileManager.MixProject do
  use Mix.Project

  @name :file_manager
  @version "0.1.0"
  @deps [
    {:phoenix, "~> 1.5.7"},
    {:phoenix_pubsub, "~> 2.0"},
    {:gettext, "~> 0.11"},
    {:jsonrs, github: "nash-io/Jsonrs"},
    {:plug_cowboy, "~> 2.0"},
    {:file_system, "~> 0.2.7"},
    {:database, in_umbrella: true},
    {:shared, in_umbrella: true},
    {:worker, in_umbrella: true},
    {:trunk, "~> 1.1.0"},
    {:briefly, github: "CargoSense/briefly", override: true},
    {:sentry, "~> 8.0"},

    # Scheduler
    {:sched_ex, "~> 1.1"}
  ]

  def project do
    [
      app: @name,
      version: @version,
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.5",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [:phoenix, :gettext] ++ Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      deps: @deps
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {FileManager.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end

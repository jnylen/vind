defmodule Main.MixProject do
  use Mix.Project

  @name :main
  @version "0.1.0"
  @deps [
    {:phoenix, "~> 1.5.7"},
    {:phoenix_pubsub, "~> 2.0"},
    {:phoenix_ecto, "~> 4.4.0"},
    {:phoenix_html, "~> 2.11"},
    {:phoenix_live_view, "~> 0.15.7"},
    {:phoenix_live_reload, "~> 1.2", only: :dev},
    {:gettext, "~> 0.11"},
    {:jsonrs, github: "nash-io/Jsonrs"},
    {:plug_cowboy, "~> 2.0"},
    {:crontab, "~> 1.1"},
    {:sentry, "~> 8.0"},

    # Admin
    {:phoenix_active_link, "~> 0.3.0"},
    {:database, in_umbrella: true},
    {:vex, "~> 0.9.0", override: true},
    {:augmenter, in_umbrella: true},
    {:exporter, in_umbrella: true},
    {:importer, in_umbrella: true},
    {:image_manager, in_umbrella: true},
    {:shared, in_umbrella: true},

    # Pagination
    {:filterable, "~> 0.7.3"},
    {:scrivener, "~> 2.0"},
    {:scrivener_html, github: "andypho/scrivener_html"},

    # Dashboard
    {:telemetry_poller, "~> 0.4"},
    {:telemetry_metrics, "~> 0.4"},
    {:phoenix_live_dashboard, "~> 0.4"},

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
      aliases: aliases(),
      deps: @deps
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Main.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, we extend the test task to create and migrate the database.
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [test: ["ecto.create --quiet", "ecto.migrate", "test"]]
  end
end

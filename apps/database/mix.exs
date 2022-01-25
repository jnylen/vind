defmodule Database.MixProject do
  use Mix.Project

  @name :database
  @version "0.1.0"
  @deps [
    {:jsonrs, github: "nash-io/Jsonrs"},
    {:ecto_sql, "~> 3.0"},
    {:postgrex, ">= 0.0.0"},
    {:ecto_enum, "~> 1.2"},
    {:countries, github: "jnylen/countries"},
    {:filtrex, "~> 0.4.3"},
    {:scrivener_ecto, "~> 2.0"},

    # Uploader
    {:trunk, "~> 1.1.0"},
    {:ex_aws_s3, github: "factsfinder/ex_aws_s3", override: true},
    {:ex_aws, github: "jnylen/ex_aws", override: true},
    {:briefly, github: "CargoSense/briefly", override: true},
    {:hackney, "~> 1.7"},
    {:poison, "~> 3.1"},
    {:sweet_xml, "~> 0.6"},
    {:formex, "~> 0.6.7"},
    {:formex_ecto, "~> 0.2.3"},
    {:formex_vex, "~> 0.1.1"},
    {:vex, "~> 0.9.0", override: true},

    # Worker stuff
    {:ecto_observable, "~> 0.4"},
    {:task_bunny, "~> 0.3.4", github: "jnylen/task_bunny", branch: "add_uniques"},
    {:cowboy, "~> 2.1", override: true},
    {:iso639_elixir, "~> 0.2.0"}
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
      extra_applications: [:logger],
      mod: {Database.Application, []}
    ]
  end
end

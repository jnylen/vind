defmodule Vind.MixProject do
  use Mix.Project

  @deps [
    {:jsonrs, github: "nash-io/Jsonrs"},
    {:vex, "~> 0.9.0", override: true}
  ]

  def project do
    [
      apps_path: "apps",
      start_permanent: Mix.env() == :prod,
      deps: @deps,
      version: File.read!("VERSION") |> String.trim(),
      aliases: [sentry_recompile: ["deps.compile sentry --force", "compile"]],
      releases: [
        vind: [
          include_executables_for: [:unix],
          applications: [
            runtime_tools: :permanent,
            database: :permanent,
            image_manager: :permanent,
            main: :permanent,
            worker: :permanent
          ],
          steps: [:assemble]
        ],
        file_manager: [
          include_executables_for: [:unix],
          applications: [
            runtime_tools: :permanent,
            file_manager: :permanent,
            image_manager: :permanent,
            database: :permanent,
            worker: :permanent
          ],
          steps: [:assemble]
        ]
      ]
    ]
  end
end

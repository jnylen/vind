import Config

config :briefly,
  directory: "/tmp/",
  default_prefix: "briefly",
  default_extname: ""

config :database, ecto_repos: [Database.Repo]

config :main,
  generators: [context_app: false],
  environment: Mix.env()

# Configures the endpoint
config :main, Main.Endpoint,
  url: [host: "localhost"],
  render_errors: [view: Main.ErrorView, accepts: ~w(html json)],
  pubsub_server: Main.PubSub,
  live_view: [signing_salt: "fe1cff3f9f9bc9085a956e2a406f884f"]

config :file_manager, FileManagerWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [view: FileManagerWeb.ErrorView, accepts: ~w(json)],
  pubsub_server: FileManager.PubSub

config :logger, :console,
  level: :debug,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jsonrs for JSON parsing in Phoenix
config :sentry, :json_library, Jsonrs
config :postgrex, :json_library, Jsonrs
config :phoenix, :json_library, Jsonrs
# config :iso639_elixir, :json_library, Jsonrs

config :elixir, :time_zone_database, Tzdata.TimeZoneDatabase

config :exporter,
  list: ["Xmltv", "PremiumXmltv", "NewHoneybee"]

config :formex,
  validator: Formex.Validator.Vex,
  template: Main.Forms.TemplateHorizontal,
  repo: Database.Repo

import_config "#{Mix.env()}.exs"

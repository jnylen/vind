import Config

config :database, Database.Repo,
  database: "vind",
  username: "postgres",
  password: "password",
  hostname: "localhost",
  port: 5332

config :main, Main.Endpoint,
  secret_key_base: "y3NGeScLTLWpugYwfaofmlxkD3VKL9LZJCFAOamAgSq1y5sRjGAAG9O4c5IcQ+aW",
  http: [port: 4000],
  debug_errors: true,
  code_reloader: true,
  check_origin: false,
  watchers: [
    node: [
      "node_modules/webpack/bin/webpack.js",
      "--mode",
      "development",
      "--watch",
      "--watch-options-stdin",
      cd: Path.expand("../apps/main/assets", __DIR__)
    ]
  ],
  live_view: [signing_salt: "y3NGeScLTLWpugYwfaofmlxkD3VKL9LZJCFAOamAgSq1y5sRjGAAG9O4c5IcQ+aW"]

config :file_manager, FileManagerWeb.Endpoint,
  secret_key_base: "vZLt/eONAD48cXAmGWMotUKSovjzS4SqcORNyck9q/M63xG3DsTyc0cJThnYHPdQ",
  http: [port: 4001],
  debug_errors: true,
  code_reloader: true,
  check_origin: false,
  watchers: []

config :task_bunny,
  hosts: [
    default: [connect_options: "amqp://localhost?heartbeat=30"]
  ]

config :task_bunny,
  disable_auto_start: false,
  file_manager_queue: [
    namespace: "vind.",
    queues: []
  ],
  worker_queue: [
    namespace: "vind.",
    queues: []
  ]

config :image_manager,
  bucket_name: "vind-images-dev"

config :file_manager,
  content_cache: "/Users/joakimnylen/Work/Pixelmonster/vind_conf/cc",
  file_store: "/Users/joakimnylen/Work/Pixelmonster/vind_conf/fs",
  ftp_store: "/Users/joakimnylen/Work/Pixelmonster/vind_conf/ftp"

config :exporter,
  config_path: "/Users/joakimnylen/Work/Pixelmonster/vind_conf/conf/exporters.json"

config :importer,
  config_path: "/Users/joakimnylen/Work/Pixelmonster/vind_conf/conf/importers.json"

config :main, Main.Endpoint,
  live_reload: [
    patterns: [
      ~r"priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"priv/gettext/.*(po)$",
      ~r"lib/main/{live,views]/.*(ex)$",
      ~r"lib/main/templates/.*(eex)$"
    ]
  ]

##########

import_config "dev.secret.exs"

######

# config :trunk,
#  storage: Trunk.Storage.Filesystem,
#  storage_opts: [path: "/tmp"]

config :database, file_manager_otp_app: :file_manager

config :exporter, :new_honeybee,
  ext: "json",
  path: "/Users/joakimnylen/Work/Pixelmonster/vind_conf/exports/new_honeybee"

config :exporter, :premium_xmltv,
  ext: "xml",
  path: "/Users/joakimnylen/Work/Pixelmonster/vind_conf/exports/premium_xmltv"

config :exporter, :xmltv,
  ext: "xml",
  path: "/Users/joakimnylen/Work/Pixelmonster/vind_conf/exports/xmltv"

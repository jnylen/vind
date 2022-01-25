import Config

secret_key_base =
  System.get_env("SECRET_KEY_BASE") ||
    raise """
    environment variable SECRET_KEY_BASE is missing.
    You can generate one by calling: mix phx.gen.secret
    """

config :logger,
  level: :info

config :task_bunny,
  hosts: [
    default: [connect_options: "amqp://localhost?heartbeat=30"]
  ]

config :exporter,
  config_path: "/etc/vind/exporters.json"

config :importer,
  config_path: "/etc/vind/importers.json"

config :image_manager, :trunk,
  storage: Trunk.Storage.S3,
  storage_opts: [bucket: "vind-images"]

config :trunk,
  storage: Trunk.Storage.S3,
  timeout: 10000

#############################################

database_url =
  System.get_env("DATABASE_URL") ||
    raise """
    environment variable DATABASE_URL is missing.
    For example: ecto://USER:PASS@HOST/DATABASE
    """

config :database, Database.Repo,
  # ssl: true,
  url: database_url,
  pool_size: String.to_integer(System.get_env("POOL_SIZE", "100"))

# Only enable if we have this environment variable set
if System.get_env("SENTRY_DSN") do
  config :sentry,
    dsn: System.get_env("SENTRY_DSN"),
    environment_name: :prod,
    enable_source_code_context: true,
    root_source_code_path: File.cwd!(),
    tags: %{
      env: "production"
    },
    included_environments: [:prod]
end

config :ex_aws,
  debug_requests: true,
  json_codec: Jsonrs,
  access_key_id: System.get_env("AWS_ACCESS_KEY"),
  secret_access_key: System.get_env("AWS_SECRET_KEY"),
  region: "eu-central-003"

config :ex_aws, :s3,
  debug_requests: true,
  region: "eu-central-003",
  scheme: "https://",
  host: "s3.eu-central-003.backblazeb2.com"

if System.get_env("ELIXIR_RELEASE_NAME", "file_manager") == "file_manager" do
  config :file_manager, :trunk,
    storage: Trunk.Storage.S3,
    storage_opts: [bucket: "vind-incoming"]

  config :database, file_manager_otp_app: :file_manager

  config :file_manager, FileManagerWeb.Endpoint,
    url: [host: System.get_env("APP_HOST", "localhost")],
    http: [
      ip: {0, 0, 0, 0},
      port: {:system, "DOKKU_PROXY_PORT"},
      compress: true
    ],
    server: true,
    secret_key_base: secret_key_base,
    check_origin: false

  config :file_manager,
    mailgun_key: System.get_env("MAILGUN_API_KEY"),
    content_cache: "/content/import/contentcache/",
    file_store: "/content/import/filestore/",
    ftp_store: "/content/import/ftp/"

  config :task_bunny,
    hosts: [
      default: [
        connect_options: System.get_env("RABBITMQ_URL")
      ]
    ],
    file_manager_queue: [
      namespace: "vind.",
      queues: [
        [name: "filestore", jobs: "FileManager.*", worker: [concurrency: 10]]
      ]
    ]
else
  config :importer, :trunk,
    storage: Trunk.Storage.S3,
    storage_opts: [bucket: "vind-incoming"]

  config :database, file_manager_otp_app: :importer

  config :exporter, :new_honeybee,
    ext: "json",
    path: "/content/export/new_honeybee"

  config :exporter, :premium_xmltv,
    ext: "xml",
    path: "/content/export/premium_xmltv"

  config :exporter, :xmltv,
    ext: "xml",
    path: "/content/export/xmltv"

  config :main, Main.Endpoint,
    url: [host: System.get_env("APP_HOST", "localhost")],
    http: [
      ip: {0, 0, 0, 0},
      port: {:system, "DOKKU_PROXY_PORT"},
      compress: true
    ],
    server: true,
    cache_static_manifest: "priv/static/cache_manifest.json",
    secret_key_base: secret_key_base,
    check_origin: false,
    live_view: [signing_salt: secret_key_base]

  config :importer,
    mailgun_key: System.get_env("MAILGUN_API_KEY"),
    content_cache: "/content/import/contentcache/",
    file_store: "/content/import/filestore/",
    ftp_store: "/content/import/ftp/"

  config :task_bunny,
    hosts: [
      default: [
        connect_options: System.get_env("RABBITMQ_URL")
      ]
    ],
    worker_queue: [
      namespace: "vind.",
      queues: [
        [name: "augmenter", jobs: [Worker.Augmenter], worker: [concurrency: 20]],
        [name: "exporter", jobs: [Worker.Exporter], worker: [concurrency: 30]],
        [name: "importer", jobs: [Worker.Importer], worker: [concurrency: 20]],
        [name: "images", jobs: [Worker.Imager], worker: [concurrency: 20000]],
        [name: "recurring", jobs: "Worker.Recurring.*", worker: [concurrency: 10]]
      ]
    ]

  config :exporter,
    list: ["Xmltv", "PremiumXmltv", "NewHoneybee"]
end

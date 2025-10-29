# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :f1_grid_watcher,
  generators: [timestamp_type: :utc_datetime]

# Configures the endpoint
config :f1_grid_watcher, F1GridWatcherWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: F1GridWatcherWeb.ErrorHTML, json: F1GridWatcherWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: F1GridWatcher.PubSub,
  live_view: [signing_salt: "MLHrnqsT"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :f1_grid_watcher, F1GridWatcher.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  f1_grid_watcher: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.4.3",
  f1_grid_watcher: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :f1_grid_watcher, :req_default_options,
  # reasonable defaults; tune to your needs
  receive_timeout: 15_000,
  connect_options: [timeout: 5_000],
  # simple retry policy on transient errors
  retry: true,
  max_retries: 3,
  # log request/response at info in dev only (see runtime.exs)
  attach_logger: false

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"

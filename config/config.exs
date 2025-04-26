# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :piratex,
  generators: [timestamp_type: :utc_datetime]

config :piratex,
  # time for each player to flip a letter
  turn_timeout_ms: 60_000,
  # time for players to vote on a challenge
  challenge_timeout_ms: 120_000,

  # time for the first player to join
  new_game_timeout_ms: 60_000,
  # games timeout after inactivity
  game_timeout_ms: 3_600_000,
  # ms at the end of game for claims
  end_game_time_ms: 30_000,

  # min and max player name length
  min_player_name: 3,
  max_player_name: 15,

  # min word length
  min_word_length: 3,

  # max number of players
  max_players: 6,

  # size of the letter pool
  letter_pool_size: 144,

  # name of the dictionary file
  dictionary_file_name: "dictionary.txt"

# Configures the endpoint
config :piratex, PiratexWeb.Endpoint,
  url: [host: "localhost"],
  server: true,
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: PiratexWeb.ErrorHTML, json: PiratexWeb.ErrorJSON],
    layout: {PiratexWeb.Layouts, :app}
  ],
  pubsub_server: Piratex.PubSub,
  live_view: [signing_salt: "s7SEvfsE"]

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  piratex: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.4.3",
  piratex: [
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

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"

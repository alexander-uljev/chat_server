use Mix.Config

config :chat_server,
  room_adapter: Chat.DbRoom

config :chat_server, ChatServerWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "LoEPDdsFEpVmp7XaYJVgbnmBuRX1+P4hku7r4egOixGhs/Z86hGuYeKWZ8w/6pec",
  pubsub: [name: ChatServer.PubSub, adapter: Phoenix.PubSub.PG2]

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :phoenix, :json_library, Jason

import_config "#{Mix.env()}.exs"
File.exists?("config/routes.exs") and import_config "routes.exs"

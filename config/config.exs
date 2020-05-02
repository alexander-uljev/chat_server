use Mix.Config

config :chat_server,
  mode: :mixed,
  local_node: :'server0@127.0.0.1',
  nodes: %{
    chat_base:   [:'base0@127.0.0.1'],
    chat_router: [:'router0@127.0.0.1'],
    chat_room:   [:'room0@127.0.0.1']
  },
  room_adapter: Chat.DbRoom

config :chat_server, ChatServerWeb.Endpoint,
  http: [port: 4000],
  https: [
    port: 4040,
    cipher_suite: :strong,
    certfile: "priv/cert/selfsigned.pem",
    keyfile: "priv/cert/selfsigned_key.pem"
  ],
  url: [host: "localhost"],
  secret_key_base: "LoEPDdsFEpVmp7XaYJVgbnmBuRX1+P4hku7r4egOixGhs/Z86hGuYeKWZ8w/6pec",
  pubsub: [name: ChatServer.PubSub, adapter: Phoenix.PubSub.PG2]

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :logger, level: :info

config :phoenix, :json_library, Jason

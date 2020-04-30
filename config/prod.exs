use Mix.Config

config :chat_server, ChatServerWeb.Endpoint,
http: [port: 4000],
https: [
  port: 4040,
  cipher_suite: :strong,
  certfile: "priv/cert/selfsigned.pem",
  keyfile: "priv/cert/selfsigned_key.pem"
],
  cache_static_manifest: "priv/static/cache_manifest.json"

config :logger, level: :info
import_config "prod.secret.exs"

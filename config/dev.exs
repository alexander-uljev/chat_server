use Mix.Config

config :chat_server, ChatServerWeb.Endpoint,
  http: [port: 4000],
  https: [
    port: 4040,
    cipher_suite: :strong,
    certfile: "priv/cert/selfsigned.pem",
    keyfile: "priv/cert/selfsigned_key.pem"
  ],
  debug_errors: true,
  code_reloader: true,
  check_origin: false,
  watchers: []

config :logger, :console, format: "[$level] $message\n"

config :phoenix, :stacktrace_depth, 20

config :phoenix, :plug_init_mode, :runtime

config :chat_server, :filter_parameters, {:keep, [:password]}

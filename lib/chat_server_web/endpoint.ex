defmodule ChatServerWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :chat_server

  # socket "/socket", ChatServerWeb.UserSocket,
  #   websocket: true,
  #   longpoll: false

  if code_reloading? do
    plug Phoenix.CodeReloader
  end

  plug Plug.SSL,
    host: "0.0.0.0:4040"

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Plug.Parsers,
    parsers: [:json],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head
  plug ChatServerWeb.Router

end

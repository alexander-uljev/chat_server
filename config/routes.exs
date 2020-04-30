import Config

config :chat_server,
  mode:  :mixed,
  local_node: :'server0@127.0.0.1',
  nodes: %{
    chat_base:   [:'base0@127.0.0.1'],
    chat_router: [:'router0@127.0.0.1'],
    chat_room:   [:'room0@127.0.0.1']
  }

env_file = "#{Mix.env()}_routes.exs"
File.exists?(env_file) and import_config env_file

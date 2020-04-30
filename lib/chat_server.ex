defmodule ChatServer do
  @moduledoc """
  ChatServerWeb defines JSON API for ChatServer application interaction.

  Only HTTPS protocol is supported for all paths.

  You must be a member of ChatServer system to start a session with it.

  ### Running

  Configurated mode can be overridden by *CHAT_SERVER_MODE* environment variable
  and passing of the *--mode* switch. Priority of the override is env > opts >
  config_file.

  ### Configuration

  ChatServer requires a **:room_adapter** value defined under **:chat_server** key
  in it's configuration. The value must be a `Chat.Room` specification releasing
  application's interface module name. `Chat.DbRoom` is shipped together with
  `Chat.Room`, so it can be used.

  For *distributed* and *mixed* modes to work, *routes.exs* must be present in
  *config* folder, decaring a map o be used for dispatching calls. A sample
  configuration is shon below. All keys and value data types are mandatory. The
  last two lines import routes configuration in simmilar fashion as config.exs
  does.

  ```elixir
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
  ```

  ### Pre-authentication features

  In order to register make a POST request to
  https://server.url:4040/:member/register.
  The :member can be a "user", an "admin" or a "spectrator". This type will
  stick to your account for all further use, so be sure to remember it. Pass a
  JSON map as a payload which includes **login** and **password** keys. Password
  must meet certain requirements, find them in `Chat.Base` documentation. Try:

  `curl -H 'Content-Type: application/json' \
   -kX POST https://server.url:4040/user/register \
    -d '{"login": "alex", "password": "N11Ce!P4sswOrd"}' `

  After you get an "ok" response, you can go ahead and authenticate in the system
  using your credentials. Send a POST request to
  https://server.url:4040/:member/auth
  Attach a JSON payload to the request which includes **login** and **password**
  keys that you used for registration. If your authentication attempt succeeds
  you will receive a **session id**. From now on every request you make must
  include a **session_id** key. Try:

  `curl -H 'Content-Type: application/json' \
   -kX POST https://server.url:4040/user/auth \
    -d '{"login": "alex", "password": "N11Ce!P4sswOrd"}' `

  In order to finish your session, send a DELETE request with your **session id** to
  https://server.url:4040/:member/leave
  Try:

  `curl -H 'Content-Type: application/json' \
   -kX DELETE https://server.url:4040/user/leave \
    -d '{"session_id": "your encrypted session id"}' `

  ### Post-authentication features

  Once you are logged in, you can create a room by sending a PUT request to
  https://server.url:4040/room/create
  Payload must include your **session id** and a room **name** keys. You will
  become an administrator of that room, hence a member of it. Try:

  `curl -H 'Content-Type: application/json' \
   -kX PUT https://server.url:4040/room/create \
   -d '{"session_id": "your encrypted session id", "name": "new room"}'`

  To list all the rooms you are a member of, send a POST request to
  https://server.url:4040/room/list
  The payload must include **session id**. Response will include **rooms** key
  with a list of room names that you are a member of. Try:

  `curl -H 'Content-Type: application/json' \
   -kX POST https://server.url:4040/room/list \
   -d '{"session_id": "your encrypted session id"}'`

  You can enter a room by sending a POST request to
  https://server.url:4040/room/enter
  Payload must include your **session id** and a room **name** keys. You will
  become a regular member of that room if you are authenticated and the room
  exists. Try:

  `curl -H 'Content-Type: application/json' \
   -kX POST https://server.url:4040/room/enter \
   -d '{"session_id": "your encrypted session id", "name": "new room"}'`

  Once you are a member of the room, you can start sending messages to it. In
  order to do so, send a PUT request to
  https://server.url:4040/room/send_message
  Payload must include your **session id**, room **name**and a **message**
  keys. The message must be a string. Your message will be added to all the
  messages of the room. Try:

  `curl -H 'Content-Type: application/json' \
   -kX POST https://server.url:4040/room/send_message \
   -d '{"session_id": "your encrypted session id", "name": "new room", "message": "Hello"}'`

  Once you are a member of the room, you can query for all the messages by
  sending a POST request to
  https://server.url:4040/room/messages
  Payload must include your **session id** and the room **name** keys. Try:

  `curl -H 'Content-Type: application/json' \
   -kX POST https://server.url:4040/room/messages \
   -d '{"session_id": "your encrypted session id", "name": "new room"}'`

  Once you are a member of the room, you can list all room members by sending
  a POST request to
  https://server.url:4040/room/list_members
  Payload must include your **session id** and the room **name** keys. Try:

  `curl -H 'Content-Type: application/json' \
   -kX POST https://server.url:4040/room/messages \
   -d '{"session_id": "your encrypted session id", "name": "new room"}'`

  You can exit the room by sending a DELETE request to
  https://server.url:4040/room/exit
  Payload must include your **session id** and the room **name** keys. Try:

  `curl -H 'Content-Type: application/json' \
   -kX DELETE https://server.url:4040/room/messages \
   -d '{"session_id": "your encrypted session id", "name": "new room"}'`

   ### Administrator preveligies

  Once you are a member of the room and if you are the room administrator, you
  can invite a member to a room by sending a POST request to
  https://server.url:4040/room/invite_member
  Payload must include your **session id**, **member_login** and the room **name**
  keys. Try:

  `curl -H 'Content-Type: application/json' \
   -kX POST https://server.url:4040/room/messages \
   -d '{"session_id": "your encrypted session id", "name": "new room"}'`

  """

  @typedoc """
  A tuple holding module, function, arguments for a remote procedure call.
  """
  @type request :: {module(), atom(), list()}

  use Agent
  require Logger

  @app_name :chat_server

  @doc """
  Verifies if `value` matches node format of "name@domain_or_ip".
  """
  @spec is_node(value :: term()) :: boolean()

  defmacro is_node(value) do
    quote do
      unquote(value)
      |> to_string()
      |> String.downcase()
      |> String.match?(~r/\w+@\w+/)
    end
  end

  @doc """
  Initialises `args` and starts the ChatServer.

  Returns {:ok | pid} or {:error, reason}.
  """
  @spec start_link(args :: keyword()) :: {:ok, pid()} | {:error, term()}

  def start_link(args) do
    Agent.start_link(__MODULE__, :init, [args], name: __MODULE__)
  end

  @doc """
  Stops ChatServer and returns :ok.
  """
  @spec stop() :: :ok

  def stop() do
    Agent.stop(ChatServer)
  end

  @doc """
  Dispatches request according to the current `mode` value.

  In case `mode` is set to *local_mono* or *local_multi*, dispatch will make a
  local function call. If the `mode` is *distributed* or *mixed* remote call can
  be made and one should expect rpc return values.
  """
  @spec dispatch(app     :: Application.app(),
                 request :: request())
                         :: list()

  def dispatch(app, {module, function, arguments} = request)
  when is_atom(app) and is_atom(module)
  and is_atom(function) and is_list(arguments) do
    request = put_elem(request, 0, chat_module(module))
    Logger.info("Processing request: #{inspect(request)}")
    {mode, dests} = Agent.get(ChatServer, & &1)
    dispatch(mode, dests, app, request)
  end

  @doc """
  Agent's callback.
  """
  @spec init(keyword()) :: {atom(), list()}

  def init(args) do
    mode = args[:mode]
    destinations = Keyword.get(args, :destinations, %{})
    if mode != :local_mono and destinations == %{} do
      nodes = Application.get_env(@app_name, :nodes)
      if nodes == nil or Enum.empty?(nodes) do
        no_node!()
      else
        nodes
        |> Map.values()
        |> List.flatten()
        |> Enum.each(& Node.connect(&1))
        {mode, nodes}
      end
    else
      verify_destinations!(destinations)
      {mode, destinations}
    end
  end

  @doc """
  Returns a ChatServer's state.
  """
  @spec state() :: {atom(), list()}

  def state(), do: Agent.get(__MODULE__, & &1)


  @doc """
  A function to change ChatServer's configuration live.

  Accepts a map of new parameters and updates internal stte of the application.
  """
  @spec configure(params :: map()) :: :ok

  def configure(params) when is_map(params) do
    {mode, destinations} = {params[:mode], params[:destinations]}
    cond do
      mode && length(params) == 1 ->
        # mode in supported_modes
        Agent.update(ChatServer, & put_elem(&1, 0, mode))
      destinations && length(params) == 1 ->
        # verify destinations
        Agent.update(ChatServer, & put_elem(&1, 1, destinations))
      mode && destinations && length(params) == 2 ->
        # verify all
        Agent.update(ChatServer, fn(_state) -> {mode, destinations} end)
    end
  end

  @spec dispatch(:local_mono | :local_multi | :distributed | :mixed,
                  [node()], Application.app(), request()) :: list()
  defp dispatch(:local_mono, _nodes, _app, {module, function, arguments}) do
    [apply(module, function, arguments)]
  end

  defp dispatch(:local_multi, destinations, app, {module, function, arguments}) do
    dests = destinations[app]
    for dest <- dests, do: apply(module, function, [dest | arguments])
  end

  defp dispatch(:distributed, nodes, app, {module, function, arguments}) do
    nodes = nodes[app]
    for node <- nodes, do: remote_call(node, module, function, arguments)
  end

  defp dispatch(:mixed, nodes, app, request) do
    nodes = nodes[app]
    for node <- nodes do
      cond do
        node == :localhost ->
          dispatch(:local, nil, nil, request)
        is_node(node) ->
          {module, function, arguments} = request
          remote_call(node, module, function, arguments)
        true ->
          undefined_node!(node)
      end
    end
  end

  @spec remote_call(node(), module(), atom(), list()) :: list()
  defp remote_call(node, module, function, arguments) do
    :rpc.call(node, module, function, arguments)
  end

  @spec verify_destinations!(Enumerable.t()) :: boolean()
  defp verify_destinations!(destinations) do
    try do
      destinations
      |> Enum.each(fn {app, nodes} ->
        nodes_valid? = Enum.all?(nodes, & is_node(&1) or is_pid(&1))
        chat_app?(app) and nodes_valid?
          or invalid_destination!(app, nodes)
        end)
    rescue
      ArgumentError -> dest_not_map!()
      exception -> reraise(exception, __STACKTRACE__)
    end
  end

  @spec chat_app?(Application.app()) :: boolean()
  defp chat_app?(app) do
    app |> to_string() |> String.starts_with?("chat_")
  end

  @spec chat_module(module()) :: module()
  defp chat_module(module) do
    Module.concat(Chat, module)
  end

  @spec no_node!() :: none()
  defp no_node!() do
    raise RuntimeError, """
      Can't run chat server in distributed mode without specifying node list.
      Please provide node list in your configuration under :chat_server, :nodes
      key
    """
  end

  @spec undefined_node!(node()) :: none()
  defp undefined_node!(node) do
    raise RuntimeError, """
      Wrong node argument: #{inspect(node)}. Node must be a Node.t() type or a
      :localhost atom.
    """
  end

  @spec invalid_destination!(Application.app(), [node()]) :: none()
  defp invalid_destination!(app, nodes) do
    nodes = for node <- nodes, do: to_string(node)
    raise RuntimeError, """
      Wrong destinations argument passed. Destinations must be chat_application
      keys pointing to a list of valid nodenames. Error occured while checking
      key: #{app}, value #{nodes}
    """
  end

  @spec dest_not_map!() :: none()
  defp dest_not_map!() do
    raise RuntimeError, "destinations must be a map"
  end

end

defmodule ChatServer.Application do
  @moduledoc false

  use Application

  @supported_modes [:local_mono, :local_multi, :distributed, :mixed]

  def start(_type, args \\ []) do
    mode = get_mode!()
    mode in @supported_modes or unsupported_mode_error!(mode)
    maybe_start_node(mode)
    start_sessions_table()
    start_ip_table()

    children = [
      {ChatServer, [{:mode, mode} | args]},
      ChatServerWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: ChatServer.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def config_change(changed, _new, removed) do
    ChatServerWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp start_sessions_table() do
    :ets.new(:sessions, [:named_table, :public, read_concurrency: true])
  end

  defp start_ip_table() do
    :ets.new(:ips, [:named_table, :public, read_concurrency: true])
  end

  defp maybe_start_node(mode) do
    if Node.alive?() do
      :noop
    else
      if mode in [:distributed, :mixed], do: start_node(), else: :noop
    end
  end

  defp start_node() do
    name = fetch_node_name()
    Node.start(name)
    :ok
  end

  defp fetch_node_name() do
    case Application.fetch_env(:chat_server, :local_node) do
      {:ok, name} -> name
      :error      -> undefined_local_node!()
    end
  end

  defp get_mode!() do
    sys_env_mode() || options_mode() || config_mode() || undefined_mode!()
  end

  defp sys_env_mode() do
    if mode = System.get_env("CHAT_SERVER_MODE"),
    do: String.to_atom(mode), else: false
  end

  defp options_mode(key_present \\ "--mode" in System.argv())
  defp options_mode(false), do: false
  defp options_mode(true) do
    opts_i =
      System.argv()
      |> Enum.find_index(& &1 == "--mode")
    opts =
      System.argv()
      |> Enum.slice(opts_i..-1)
      |> OptionParser.parse(strict: [mode: :string])
      |> elem(0)
    if opts[:mode] == nil do
      false
    else
      opts[:mode] |> String.to_atom()
    end
  end

  defp config_mode() do
    try do
      config = Config.Reader.read!("config/routes.exs")
      mode = config[:chat_server][:mode]
      mode != nil and mode || mode_key_missing!()
    rescue
      Code.LoadError -> false
    end
  end

  defp undefined_mode!() do
    raise RuntimeError, """
      Mode for chat server is not defined. Please specify CHAT_SERVER_MODE envi-
      ronment variable, pass a --mode switch or put a :mode key in config/routes.
      exs.
    """
  end

  defp mode_key_missing!() do
    raise RuntimeError, """
      :mode key missing in config/routes.exs. Refer to documentation for more in-
      formation.
    """
  end

  defp undefined_local_node!() do
    raise RuntimeError, """
      Chat server mode set to distributed or mixed but local node name is not
      specified not in routes.exs nor via command line. Refer to documentation
      for more information.
    """
  end

  defp unsupported_mode_error!(mode) do
    modes = Enum.map(@supported_modes, &(to_string(&1)))
    raise RuntimeError, """
      Unsupported CHAT_SERVER_MODE environment variable or it was not set.
      Supported modes are #{modes}, given mode was #{mode}
    """
  end
end

defmodule ChatServerTest do
  use ExUnit.Case
  @app_name :chat_server

  setup_all :proper_shutdown
  setup :stop_server

  describe "dispatches" do

    test "to local single processes" do
      set_env_mode("local_mono")
      start_router_locally()
      assert test_link() == :ok
    end

    test "to local multiple processes" do
      assert true # implement after registry
    end

    test "to distributed application" do
      set_env_mode("distributed")
      Node.start(:'server@127.0.0.1')
      assert test_link() == :ok
    end

    test "to mixed local-distributed application" do
      set_env_mode("mixed")
      assert test_link() == :ok
    end

  end

  defp proper_shutdown(_) do
    on_exit(fn ->
      Node.stop() && stop_server(nil)
    end)
  end

  defp test_link() do
    start_server()
    request = {Router, :up?, []}
    [result] = ChatServer.dispatch(:chat_router, request)
    if result, do: :ok, else: :error
  end

  defp start_router_locally() do
    add_router_path()
    Application.start(:chat_router)
  end

  defp start_node() do
    # spawn(fn -> System.cmd("elixir", ~w(--name test@127.0.0.1 )))
  end

  defp add_router_path() do
    ["../../_build/test/lib/chat_router/ebin",
     "../../_build/test/lib/chat_router/consolidated"]
    |> Enum.each(fn(path) ->
        path |> Path.expand() |> Code.prepend_path()
      end)
  end

  defp start_server(), do: Application.start(@app_name)
  defp stop_server(_), do: Application.stop(@app_name)
  defp set_env_mode(mode), do: System.put_env("CHAT_SERVER_MODE", mode)

  defp proper_shutdown() do
    on_exit(fn -> Node.stop() end)
  end



end
# ["../../_build/test/lib/chat_config/ebin",
#  "../../_build/test/lib/chat_config/consolidated"] \
# |> Enum.each(fn(path) ->
#     path |> Path.expand() |> Code.prepend_path()
#   end)

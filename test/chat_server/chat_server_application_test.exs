defmodule ChatServer.ApplicationTest do
  use ExUnit.Case
  @app_name :chat_server

  setup_all %{} do
    on_exit(fn ->
      Node.stop()
      stop_server()
   end)
  end

  setup %{} do
    stop_server()
    :ok
  end

  describe "starts consuming" do

    @tag :env
    test "environment variable" do
      System.put_env("CHAT_SERVER_MODE", "local_multi")
      start_server()
      assert ChatServer.state() == {:local_multi,
        %{chat_base: [:'n0@127.0.0.1'],
          chat_room: [:'n1@127.0.0.1']}}
      System.delete_env("CHAT_SERVER_MODE")
    end

    @tag :conf
    test "configuration file" do
      assert true
    end

    @tag :cli
    test "command line mode option" do
      System.argv() ++ ~w(--mode local_mono)
      |> System.argv()
      start_server()
      assert ChatServer.state() == {:local_mono, %{}}
    end

    @tag :destinations
    test "destinations map argument" do
      destinations = %{chat_base: [:'n0@127.0.0.1']}
      Application.start(@app_name, destinations: destinations)
    end

    @tag :node
    test "starts a node with a name from config" do
      assert Node.alive?
    end

  end

  defp start_server(), do: Application.start(@app_name)
  defp stop_server(),  do: Application.stop(@app_name)
end

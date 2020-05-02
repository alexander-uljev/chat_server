  defmodule ChatServer.MixProject do
  use Mix.Project

  def project do
    [
      app: :chat_server,
      version: "0.1.0",
      elixir: "~> 1.5",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [:phoenix] ++ Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      description: description(),
      aliases: aliases(),
      deps: deps()
    ]
  end

  def application do
    [
      mod: {ChatServer.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end
  
  defp aliases() do
    [
      setup: ["deps.compile", "compile"]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:phoenix, "~> 1.4.12"},
      {:phoenix_pubsub, "~> 1.1"},
      {:jason, "~> 1.0"},
      {:plug_cowboy, "~> 2.0"}
    ]
  end

  defp description() do
    "A server for Chat applications."
  end
  
end

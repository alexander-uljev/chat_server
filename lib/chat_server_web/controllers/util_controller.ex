defmodule ChatServerWeb.UtilController do
  @moduledoc false
  use ChatServerWeb, :controller

  @doc false
  def status(conn, _) do
    json(conn, %{status: "all good"})
  end
end

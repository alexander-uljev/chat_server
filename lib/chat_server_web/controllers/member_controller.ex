defmodule ChatServerWeb.MemberController do
  use ChatServerWeb, :controller
  require Logger

  Module.put_attribute(__MODULE__, :secret,
    Application.get_env(:chat_server, ChatServerWeb.Endpoint)[:secret_key_base])
  Module.put_attribute(__MODULE__, :key_base,
   "hands_open_doors_but_legs_burst_them_out")
   @server_app :chat_base

  plug :put_member_module

  def auth(conn, params) do
    if login_pass_absent?(params) do
      conn
      |> put_status(400)
      |> json(%{status: :error, reason: :bad_request, action: "authenticate",
      message: "Bad url or no login/password attributes passed"})
    else
      case get_member(params) do
        {:ok, schema} ->
          conn =
            conn
            |> put_session("session_id",  create_session(conn, params, schema))
            |> put_status(200)
          json(conn, %{status: :ok, action: "authenticate",
            session_id:  get_session(conn, "session_id")})
        {:error, :not_memb, _details} ->
          conn
          |> put_status(406)
          |> json(%{status: :error, action: "authenticate", reason: :not_a_member,
          message: "Wrong login or password"})
      end
    end
  end

  def leave(conn, params) do
    delete_session(params)
    conn
    |> configure_session(drop: true)
    |> json(%{status: :ok, message: "Logged out"})
  end

  def register(conn, params) do
    if member?(params) do
      conn
      |> put_status(406)
      |> json(%{status: :error, reason: :login_taken,
        action: "register",
        message: "login #{params["login"]} is already taken"})
    else
      action = action(conn)
      case try_register(params) do
        {:ok, _member} ->
          json(conn, %{status: :ok, action: action,
          message: "Registered: #{params["member"]}, login: #{params["login"]}"})
        {:error, :inval_attrs, {_member, errors}} ->
          invalid_attributes_response(conn, action, errors)
        {:error, :miss_log_pass, message} ->
          conn
          |> put_status(400)
          |> json(%{status: :error, reason: :login_password_missing,
            action: action, message: message})
      end
    end
  end

  def update_password(conn, params) do
    new_params = take_and_convert(params, ["new_password"])
    action = action(conn)
    case try_update(params, new_params) do
      {:ok, _member} ->
        json(conn, %{status: :ok, action: action,
         message: "Updated password for #{params["login"]}"})
      {:error, reason, {_member, message}} ->
        json(conn, %{status: :error, action: action,
        reason: reason, message: message})
      {:error, :inval_attrs, {_member, errors}} ->
        invalid_attributes_response(conn, action, errors)
    end
  end

  defp put_member_module(conn, _opts) do
    member = conn.path_params["member"]
    mod = Module.concat(Chat.Base,
      String.capitalize(member))
    put_in(conn.params["member_module"], mod)
  end

  defp login_pass_absent?(params) do
    param_keys = Map.keys(params)
    not Enum.all?(~w(login password member), &(&1 in param_keys))
  end

  defp action(conn), do: conn.path_info |> List.last()

  defp get_member(params) do
    module = params["member_module"]
    params =
      params
      |> take_keys(["login", "password"])
      |> convert_params()
    request = {Base, :read, [module, params]}
    [response] = dispatch(request)
    response
  end

  defp member?(params) do
    module = params["member_module"]
    params =
      params
      |> take_keys(["login", "password"])
      |> convert_params()
    request = {Base, :member?, [module, params]}
    [response] = dispatch(request)
    response
  end

  defp create_session(conn, params, schema) do
    %{"login" => login, "password" => password} = params
    ip = conn.remote_ip
    type = params["member"]
    data = %{
      login: login, password: password, ip: ip,
      type: type}
    data = Map.merge(schema, data)
    Plug.Session.ETS.put(nil, nil, data, :sessions)
  end

  defp delete_session(params) do
    %{"session_id" => session_id} = params
    Plug.Session.ETS.delete(nil, session_id, :sessions)
  end

  defp try_register(params) do
    module = params["member_module"]
    params = take_and_convert(params, ~w(login password))
    request = {Base, :create, [module, params]}
    [response] = dispatch(request)
    response
  end

  defp try_update(params, new_params) do
    module = params["member_module"]
    params = take_and_convert(params, ~w(login password))
    password = new_params[:new_password]
    new_params = %{params | password: password}
    request = {Base, :update, [module, params, new_params]}
    [response] = dispatch(request)
    response
  end

  defp dispatch(request) do
    ChatServer.dispatch(@server_app, request)
  end

  defp take_and_convert(params, keys) do
    params
    |> take_keys(keys)
    |> convert_params()
  end

  defp invalid_attributes_response(conn, action, errors) do
    errors = Enum.join(errors, "\n")
    conn
    |> put_status(400)
    |> json(%{status: :error, reason: :invalid_attributes,
      action: action,
      message: "Invalid attributes: #{errors}"})
  end

  defp take_keys(params, list), do: Map.take(params, list)

  defp convert_params(params) do
    for {param, value} <- params, into: %{} do
      {String.to_atom(param), value}
    end
  end

end

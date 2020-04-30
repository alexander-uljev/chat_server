defmodule ChatServerWeb.Router do
  use ChatServerWeb, :router

  @session_options [
    store: :ets,
    key: "session_id",
    table: :sessions
  ]

  pipeline :accept do
    plug :accepts, ["json"]
    # plug :block_multi_request
  end

  pipeline :session do
    plug Plug.Session, @session_options
    plug :fetch_session
  end

  pipeline :ensure_auth do
    plug :verify_session, table: @session_options[:table]
  end

  pipeline :ensure_is_room_member do
    plug :verify_is_room_member
  end

  pipeline :ensure_is_admin do
    plug :verify_is_admin
  end

  scope "/status", ChatServerWeb do
    get "/", UtilController, :status
  end

  scope "/:member", ChatServerWeb do
    pipe_through :accept

    post  "/register", MemberController, :register
    patch "/update_password",  MemberController, :update_password
  end

  scope "/:member/auth", ChatServerWeb do
    pipe_through :accept
    pipe_through :session

    post "/", MemberController, :auth
  end

  scope "/:member/leave", ChatServerWeb do
    pipe_through :accept
    pipe_through :ensure_auth
    pipe_through :session

    delete "/", MemberController, :leave
  end

  scope "/room", ChatServerWeb do
    pipe_through :accept
    pipe_through :ensure_auth
    pipe_through :session

    post "/list",   RoomController, :list_rooms
    post "/enter",  RoomController, :enter_room
    put  "/create", RoomController, :create_room
  end

  scope "/room", ChatServerWeb do
    pipe_through :accept
    pipe_through :ensure_auth
    pipe_through :session
    # pipe_through :ensure_is_room_member

    put    "/send_message",  RoomController, :send_mess
    post   "/messages",      RoomController, :messages
    delete "/exit",          RoomController, :leave_room
    post   "/list_members",  RoomController, :list_members
  end

  scope "/room", ChatServerWeb do
    pipe_through :accept
    pipe_through :ensure_auth
    pipe_through :session
    # pipe_through :ensure_is_room_member
    # pipe_through :ensure_is_admin

    post   "/invite_member", RoomController, :invite_member
    delete "/remove_member", RoomController, :remove_member
    # post   "/admin_check",   RoomController, :admin_check
    post   "/assign_admin",  RoomController, :assign_admin
    delete "/close",         RoomController, :close_room
  end

  # defp block_multi_request(conn, _opts) do
  #   [timestamp] = :ets.match(:ips, {conn.remote_ip, "$1"})
  #   cond do
  #     timestamp == nil ->
  #       conn
  #     System.os_time() - timestamp < 300 ->
  #       conn
  #       |> halt()
  #       |> send_resp(418, "")
  #   end
  # end

  defp verify_session(conn, opts) do
    req_sid  = conn.params["session_id"]
    case Plug.Session.ETS.get(conn, req_sid, opts[:table]) do
      {nil, _} ->
        IO.inspect conn
        conn
        |> halt()
        |> put_status(401)
        |> json(%{status: :error, action: "request", reason: "unauth",
        message: "Unauthorised access. Please login first"})
      {_, data} ->
        conn
        |> put_private(:plug_session, data)
    end
  end

  defp verify_is_room_member(conn, _opts) do
    sess_room  = conn.private.plug_session.room
    req_room   = conn.params["name"]
    room_verified? = sess_room[:entered] != nil and sess_room == req_room
    message = "You are not a member of this room. Enter the room first"
    if room_verified?, do: conn, else: respond_error(conn, message)
  end

  defp verify_is_admin(conn, _opts) do
    admin? = conn.private.plug_session[:room][:admin] || false
    message = "You are not the administrator of this room"
    if admin?, do: conn, else: respond_error(conn, message)
  end

  defp respond_error(conn, message) do
    action = List.last(conn.path_info)
    conn
    |> halt()
    |> put_status(400)
    |> json(%{status: :error, action: action,
      reason: :not_a_member, message: message})
  end

end

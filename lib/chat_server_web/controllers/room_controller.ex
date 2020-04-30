defmodule ChatServerWeb.RoomController do
  use ChatServerWeb, :controller
  alias Plug.Session.ETS, as: Session
  require Logger

  @server_app :chat_room
  @registry Rooms

  def create_room(conn, params) do
    action = action(conn)
    case init_create_room(conn, params) do
      {:error, reason} ->
        message = "Error creating room: #{reason}"
        send_error_response(conn, 400, action, message)
      {:ok, args} ->
        request = {Room, :create, args}
        case dispatch(request) do
          [:ok] ->
            room = form_room_record(args, entered: true)
            add_room_to_session(params, room)
            add_room_to_registry(room)
            message = "Created room #{name(args)}"
            conn
            |> put_session("room", room)
            |> send_ok_response(200, action, message)
          [{:error, reason}] ->
            Process.exit(room(args), :kill)
            message = "Failed to create room: #{reason}"
            send_error_response(conn, 400, action, message)
        end
    end
  end

  def send_mess(conn, params) do
    action = action(conn)
    case init_send_mess(conn, params) do
      {:error, reason} ->
        message = "Error sending message: #{reason}"
        send_error_response(conn, 406, action, message)
      {:ok, args} ->
        request = {Room, :send_message, args}
        case dispatch(request) do
          [:ok] ->
            message = "Message sent"
            send_ok_response(conn, 202, action, message)
          [{:error, reason}] ->
            message = "Error sending message: #{reason}"
            send_error_response(conn, 402, action, reason, message)
        end
    end
  end

  def messages(conn, params) do
    action = action(conn)
    case init_messages(conn, params) do
      {:error, reason} ->
        message = "Error retrieving messages: #{reason}"
        send_error_response(conn, 406, action, message)
      {:ok, args} ->
        request = {Room, :messages, args}
        case dispatch(request) do
          [{:ok, messages}] ->
            message = "ok"
            send_ok_response(conn, 200, action, message, messages: messages)
          [{:error, reason}] ->
            message = "Error listing rooms #{reason}"
            send_error_response(conn, 406, action, reason, message)
        end
    end
  end

  def list_members(conn, params) do
    action = action(conn)
    case init_list_members(conn, params) do
      {:error, reason} ->
        message = "Error listing members: #{reason}"
        send_error_response(conn, 406, action, message)
      {:ok, args} ->
        request = {Room, :list_members, args}
        case dispatch(request) do
          [{:ok, messages}] ->
            message = "ok"
            send_ok_response(conn, 200, action, message, messages: messages)
          [{:error, reason}] ->
            message = "Error listing rooms #{reason}"
            send_error_response(conn, 406, action, reason, message)
        end
    end
  end


  def list_rooms(conn, _params) do
    action = action(conn)
    args = init_list_rooms(conn)
    request = {Room, :list, args}
    case dispatch(request) do
      [{:ok, rooms}] ->
        message = "ok"
        send_ok_response(conn, 200, action, message, rooms: rooms)
      [{:error, reason}] ->
        message = "Error listing rooms #{reason}"
        send_error_response(conn, 406, action, reason, message)
    end
  end

  def enter_room(conn, params) do
    action = action(conn)
    case init_enter_room(conn, params) do
      {:error, reason} ->
        message = "Error entering room: #{reason}"
        send_error_response(conn, 406, action, message)
      {:ok, args} ->
        request = {Room, :add_member, args}
        case dispatch(request) do
          [:ok] ->
            room = get_and_update_room_record(conn, entered: true)
            update_room_in_session(params, room)
            message = "Entered room #{name(args)}"
            conn
            |> put_session("room", room)
            |> send_ok_response(202, action, message)
          [{:error, reason}] ->
            message = "Error entering room: #{reason}"
            send_error_response(conn, 406, action, message)
        end
    end
  end

  def leave_room(conn, params) do
    action = action(conn)
    case init_leave_room(conn, params) do
      {:error, reason} ->
        message = "Error leaving room: #{reason}"
        send_error_response(conn, 406, action, message)
      {:ok, args} ->
        request = {Room, :remove_member, args}
        case dispatch(request) do
          [:ok] ->
            room = Enum.at(args, 0)
            remove_room_from_session(params, room)
            remove_room_from_registry(conn, params)
            message = "Left room #{params["name"]}"
            send_ok_response(conn, 202, action, message)
          [{:error, reason}] ->
            message = "Error leaving room: #{reason}"
            send_error_response(conn, 406, action, message)
          end
    end
  end

  def invite_member(conn, params) do
    action = action(conn)
    member_login = fetch_from_params(params, "member_login")
    room_name = fetch_from_params(params, "name")
    case init_invite_member(conn, params) do
      {:error, reason} ->
        message = "Error inviting member: #{reason}"
        send_error_response(conn, 406, action, message)
      {:ok, args} ->
        request = {Room, :invite_member, args}
        case dispatch(request) do
          [:ok] ->
            [room_pid, {i_member_id, _, _}] = args
            room = {i_member_id, room_pid, room_name, true}
            add_room_to_registry(room)
            message = "Invited member #{member_login}"
            send_ok_response(conn, 202, action, message)
          [{:error, reason}] ->
            message = "Error inviting member: #{reason}"
            send_error_response(conn, 406, action, message)
          end

    end
  end

  # def remove_member(conn, params) do
  #   user_id = params["user_id"]
    # room_id = conn.private.plug_session.room.id
    # room_pid = Chat.Room.fetch(room_id)
    # case Chat.Room.remove_member(room_pid, user_id) do
  #   case :ok do
  #     :ok -> # send_ok_response(conn, 200, "Removed member #{user_id}")
  #       conn
  #       |> put_status(200)
  #       |> json(%{status: :ok, action: "remove_member",
  #         message: "Removed member #{user_id}"})
  #     {:error, reason} ->
  #       conn
  #       |> put_status(406)
  #       |> json(%{status: :error,
  #         action: "remove_member", message: "#{reason}"})
  #   end
  # end

  # def assign_admin(conn, params) do
  #
  # end

  def close_room(conn, params) do
    action = action(conn)
    room_name = params["name"]
    case init_close_room(conn, params) do
      {:error, reason} ->
        message = "Error closing room: #{reason}"
        send_error_response(conn, 406, action, message)
      {:ok, args} ->
        IO.inspect args
        request = {Room, :close, args}
        case dispatch(request) do
          [:ok] ->
            room = Enum.at(args, 0)
            remove_room_from_session(params, room)
            remove_room_from_registry(conn, params)
            send_ok_response(conn, 200, action, "Closed room #{room_name}")
          [{:error, reason}] ->
            message = "Error closing room #{room_name}: #{reason}"
            send_error_response(conn, 406, action, message)
        end
    end
  end

  defp init_create_room(conn, params) do
    member_id = fetch_from_session(conn, :id)
    room_name = params["name"]
    request = {Room, :lookup, [@registry, member_id, room_name]}
    case dispatch(request) do
      [{_room_pid, _entered}] ->
        {:error, "name already taken"}
      [[]] ->
        adapter = Application.get_env(:chat_server, :room_adapter)
        request = {Room, :start_link, [adapter]}
        [{:ok, room}] = dispatch(request)
        {:ok, [room, member_id, room_name]}
    end
  end

  defp init_enter_room(conn, params) do
    req_room_name = fetch_from_params(params, "name")
    member_id = fetch_from_session(conn, :id)
    member_type = fetch_from_session(conn, :type)
    if room = fetch_room_record(conn, member_id) do # try session first
      {room_pid, serv_room_name, entered} = room
      args = [name: req_room_name, member_id: member_id]
      request = {Room, :search_room, [room_pid, args]}
      [response] = dispatch(request)
      IO.inspect response
      case response do
        [_response] ->
          {:error, "already entered"}
        [] ->
          if req_room_name == serv_room_name and entered != true do
            args = [room_pid, member_id, member_type, false]
            {:ok, args}
          else
            {:error, "already entered"}
          end
      end
    else
      {:error, "room not found"}
    end
  end

  defp init_invite_member(conn, params) do
    member_login = fetch_from_params(params, "member_login")
    member_type = fetch_from_session(conn, :type)
    member_module =
      conn
      |> fetch_from_session(:type)
      |> String.capitalize()
    member_module = Module.concat([Chat, Base, member_module])
    request = {Base, :get_id_by_login, [member_module, member_login]}
    case dispatch(request, :chat_base) do
      [{:error, reason}] ->
        "Error iniviting member #{member_login}: #{inspect(reason)}"
      [{:ok, member_id}] ->
        vars = [{member_id, member_login, member_type}]
        init_room_and_merge(conn, params, vars)
    end
  end

  defp init_leave_room(conn, params) do
    member_id  = fetch_from_session(conn, :id)
    init_room_and_merge(conn, params, [member_id])
  end

  defp init_close_room(conn, params) do
    member_id  = fetch_from_session(conn, :id)
    init_room_and_merge(conn, params, [member_id])
  end

  defp init_send_mess(conn, params) do
    message = params["message"]
    member_id  = fetch_from_session(conn, :id)
    init_room_and_merge(conn, params, [member_id, message])
  end

  defp init_list_rooms(conn) do
    member_id = fetch_from_session(conn, :id)
    adapter = Application.get_env(:chat_server, :room_adapter)
    [adapter, member_id]
  end

  defp init_messages(conn, params) do
    init_room(conn, params)
  end

  defp init_list_members(conn, params) do
    init_room(conn, params)
  end

  defp init_room(conn, params) do
    member_id = fetch_from_session(conn, :id)
    room_name = fetch_from_params(params, "name")
    request = {Room, :lookup, [@registry, member_id, room_name]}
    case dispatch(request) do
      [{room_pid, entered}] ->
        if entered do
          {:ok, [room_pid]}
        else
          {:error, "haven't entered this room"}
        end
      [[]] ->
        {:error, "room not found"}
    end
  end

  defp init_room_and_merge(conn, params, vars \\ []) do
    case init_room(conn, params) do
      {:ok, args} ->
        {:ok, args ++ vars}
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp add_room_to_session(params, room) do
    sid = params["session_id"]
    data =
      sid
      |> get_session_data()
      |> Map.update(:room, [room], &([room | &1]))
    Session.put(nil, sid, data, :sessions)
  end

  defp remove_room_from_session(params, room) do
    sid = params["session_id"]
    data =
      sid
      |> get_session_data()
      |> Map.update!(:room, &(List.delete(&1, room)))
    Session.put(nil, sid, data, :sessions)
  end

  defp update_room_in_session(params, room) do
    sid = params["session_id"]
    data = get_session_data(sid)
    rooms = data[:room]
    index = Enum.find_index(rooms, &(&1 == room))
    data = Map.update!(data, :room, &(List.replace_at(&1, index, room)))
    Session.put(nil, sid, data, :sessions)
  end

  defp get_session_data(sid), do: Session.get(nil, sid, :sessions) |> elem(1)
  defp room(args), do: Enum.at(args, 1)
  defp name(args), do: Enum.at(args, 2)

  defp action(conn), do: List.last(conn.path_info)

  defp dispatch(request, app \\ @server_app) do
    Logger.debug("Dispatching to #{app}")
    ChatServer.dispatch(app, request)
  end

  defp fetch_from_params(params, key), do: params[key]
  defp fetch_from_session(conn, key), do: conn.private.plug_session[key]

  defp add_room_to_registry(record) do
    request = {Room, :add, [@registry, record]}
    dispatch(request)
  end

  defp form_room_record(args, opts) do
    entered = Keyword.get(opts, :entered, false)
    [room_pid, member_id, room_name] = args
    {member_id, room_pid, room_name, entered}
  end

  defp fetch_room_record(_conn, member_id) do
    request = {Room, :lookup, [@registry, member_id]}
    [record] = dispatch(request)
    if record == [], do: nil, else: record |> List.first()
  end

  defp fetch_room_record(conn) do
    member_id = fetch_from_session(conn, :id)
    fetch_room_record(conn, member_id)
  end

  defp send_error_response(conn, status, action, reason \\ :undef, message) do
    conn
    |> halt()
    |> put_status(status)
    |> json(%{status: :error, action: action, reason: reason, message: message})
  end

  defp send_ok_response(conn, status, action, message, payload \\ []) do
    payload = Enum.into(payload, %{})
    response =
      %{status: :ok, action: action, message: message}
      |> Map.merge(payload)
    conn
    |> put_status(status)
    |> json(response)
  end

  defp get_and_update_room_record(conn, opts) do
    conn
    |> fetch_room_record()
    |> update_room_record(opts)
  end

  defp update_room_record(record, opts) do
    entered = Keyword.get(opts, :entered)
    if entered != nil, do: put_elem(record, 2, entered), else: record
  end

  defp remove_room_from_registry(conn, params) do
    member_id = fetch_from_session(conn, :id)
    room_name = params["name"]
    request = {Room, :remove, [@registry, member_id, room_name]}
    case dispatch(request) do
      [:ok] -> :ok
      [:error] ->
        message = """
          Failed to remove room #{room_name} for member id #{member_id}. The \
          system is
          inconsistent.
        """
        Logger.error(message)
        raise RuntimeError, message
    end
  end

end

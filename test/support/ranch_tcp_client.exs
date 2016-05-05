defmodule PhoenixTCP.RanchTCPClient do
  use GenServer
  require Logger
  alias Poison, as: JSON

  @doc """
  Starts the Ranch TCP server for the given path. Received Socket.Message's
  are forwarded to the sender pid
  """
  def start_link(sender, host, port, path, params \\ %{}) do
    :proc_lib.start_link(__MODULE__, :init, [sender, host, port, path, params])
  end

  def init(sender, host, port, path, params) do
    :ok = :proc_lib.init_ack({:ok, self})
    opts = [:binary, active: false]
    connect_msg = %{"path" => path, "params" => params}
    {:ok, tcp_socket} = :ranch_tcp.connect(String.to_char_list(host), port, opts)
    :ok = :ranch_tcp.setopts(tcp_socket, [packet: 4])
    :ok = :ranch_tcp.send(tcp_socket, json!(connect_msg))
    :ok = :ranch_tcp.controlling_process(tcp_socket, self)
    state = %{tcp_transport: :ranch_tcp, tcp_socket: tcp_socket, sender: sender, ref: 0}
    :gen_server.enter_loop(__MODULE__, [], state)
  end

  @doc"""
  Closes the socket
  """
  def close(socket) do
    send(socket, :close)
  end

  def handle_info({:tcp, _tcp_socket, msg}, %{tcp_transport: transport,
                                              tcp_socket: socket} = state) do
    send state.sender, Phoenix.Transports.WebSocketSerializer.decode!(msg, [])
    :ok = transport.setopts(socket, [active: :once])
    {:noreply, state}
  end

  def handle_info({:send, msg}, %{tcp_transport: transport,
                                  tcp_socket: socket} = state) do
    msg = Map.put(msg, :ref, to_string(state.ref + 1))
    :ok = transport.send(socket, json!(msg))
    transport.setopts(socket, [active: :once])
    {:noreply, put_in(state, [:ref], state.ref + 1)}
  end

  def handle_info({:tcp_closed, _tcp_socket}, state) do
    {:stop, :normal, state}
  end

  def handle_info(:close, state) do
    {:stop, :normal, state}
  end

  def terminate(_reason, _state) do
    :ok
  end

  @doc"""
  Sends an event to the TCP Server per the Message protocol
  """
  def send_event(server_pid, topic, event, msg) do
    send server_pid, {:send, %{topic: topic, event: event, payload: msg}}
  end

  @doc"""
  Sends a heartbeat event
  """
  def send_heartbeat(server_pid) do
    send_event(server_pid, "phoenix", "heartbeat", %{})
  end

  @doc"""
  Sends join event to the TCP server per the Message protocol
  """
  def join(server_pid, topic, msg) do
    send_event(server_pid, topic, "phx_join", msg)
  end

  @doc"""
  Sends leave event to the TCP server per the Message protocol
  """
  def leave(server_pid, topic, msg) do
    send_event(server_pid, topic, "phx_leave", msg)
  end

  defp json!(map), do: JSON.encode!(map)
end

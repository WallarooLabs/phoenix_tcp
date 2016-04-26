defmodule PhoenixTCP.Transports.TCP do
  require IEx
  require Logger
	@moduledoc """
  Socket transport for tcp clients.

  ## Configuration

  the tcp is configurable in your socket:
    transport :tcp, PhoenixTCP.Transports.TCP,
      timeout: :infinity,
      serializer: Phoenix.Transports.WebSocketSerializer,
      transport_log: false

    * `:timeout` - the timeout for keeping tcp connections
      open after it last received data, defaults to 60_000ms
    
    * `:transport_log` - if the transport layer itself should log, and, if so, the level

    * `:serializer` - the serializer for tcp messages

    * `:code_reloader` - optionally override the default `:code_reloader` value
      from the socket's endpoint

  ## Serializer

  By default, JSON encoding is used to broker messages to and from the clients.
  A custom serializer may be given as a module which implements the `encode!/1`
  and `decode!/2` functions defined by the `Phoenix.Transports.Serializer`
  behaviour.
  """

  @behaviour Phoenix.Socket.Transport

  def default_config() do
    [serializer: Phoenix.Transports.WebSocketSerializer,
    timeout: 60_000,
    transport_log: false]
  end

  ## Callbacks

  alias Phoenix.Socket.Broadcast
  alias Phoenix.Socket.Transport

  @doc false
  def init(params, {endpoint, handler, transport}) do
    {_, opts} = handler.__transport__(transport)
    serializer = Keyword.fetch!(opts, :serializer)

    case Transport.connect(endpoint, handler, transport, __MODULE__, serializer, params) do
      {:ok, socket} ->
        {:ok, transport_state, timeout} = tcp_init({socket, opts})
        {:ok, {__MODULE__, {transport_state, timeout}}}
      :error ->
        {:error, "error connecting to transport #{inspect __MODULE__}"}
    end
  end

  @doc false
  def tcp_init({socket, config}) do
    Process.flag(:trap_exit, true)
    serializer = Keyword.fetch!(config, :serializer)
    timeout    = Keyword.fetch!(config, :timeout)

    if socket.id, do: socket.endpoint.subscribe(self, socket.id, link: true)

    {:ok, %{socket: socket,
            channels: HashDict.new,
            channels_inverse: HashDict.new,
            serializer: serializer}, timeout}
  end

  def tcp_handle(payload, state) do
    msg = state.serializer.decode!(payload, [])

    case Transport.dispatch(msg, state.channels, state.socket) do
      :noreply ->
        {:ok, state}
      {:reply, reply_msg} ->
        encode_reply(reply_msg, state)
      {:joined, channel_pid, reply_msg} ->
        encode_reply(reply_msg, put(state, msg.topic, channel_pid))
      {:error, _reason, error_reply_msg} ->
        encode_reply(error_reply_msg, state)
    end
  end

  @doc false
  def tcp_info({:EXIT, channel_pid, reason}, state) do
    case HashDict.get(state.channels_inverse, channel_pid) do
      nil -> {:ok, state}
      topic ->
        new_state = delete(state, topic, channel_pid)
        encode_reply Transport.on_exit_message(topic, reason), new_state
    end
  end

  @doc false 
  def tcp_info(%Broadcast{event: "disconnect"}, state) do
    {:shutdown, state}
  end

  def tcp_info({:socket_push, _, _encoded_payload} = msg, state) do
    format_reply(msg, state)
  end

  @doc false
  def tcp_close(state) do
    for {pid, _} <- state.channels_inverse do
      Phoenix.Channel.Server.close(pid)
    end
  end

  defp encode_reply(reply, state) do
    format_reply(state.serializer.encode!(reply), state)
  end

  defp format_reply({:socket_push, encoding, encoded_payload}, state) do
    {:reply, {encoding, encoded_payload}, state}
  end

  defp put(state, topic, channel_pid) do
    %{state | channels: HashDict.put(state.channels, topic, channel_pid),
              channels_inverse: HashDict.put(state.channels_inverse, channel_pid, topic)}
  end

  defp delete(state, topic, channel_pid) do
    %{state | channels: HashDict.delete(state.channels, topic),
              channels_inverse: HashDict.delete(state.channels_inverse, channel_pid)}
  end
end
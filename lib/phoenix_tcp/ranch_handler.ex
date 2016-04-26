defmodule PhoenixTCP.RanchHandler do
	@behaviour Phoenix.Endpoint.Handler
	require Logger

	@doc """
	Generates a childspec to be used in the supervision tree.
	"""
	def child_spec(scheme, endpoint, config) do
		handlers =
			for {path, socket} <- endpoint.__sockets__,
      {transport, {module, config}} <- socket.__transports__,
      # allow handlers to be configured at the transport level
      transport == :tcp,
      handler = config[:tcp] || default_for(module),
      into: %{},
      do: {Path.join(path, Atom.to_string(transport)),
           # handler being the tcp protocol implementing module
           # module being the transport module
           # endpoint being the app specific endpoint
           # socket being the app specific socket
           {handler, module, {endpoint, socket, transport}}}
    config = Keyword.put_new(config, :handlers, handlers)

    {ref, mfa, type, timeout, kind, modules} =
      PhoenixTCP.Adapters.Ranch.child_spec(scheme, endpoint, [], config)

    # Rewrite MFA for proper error reporting
    mfa = {__MODULE__, :start_link, [scheme, endpoint, mfa]}
    {ref, mfa, type, timeout, kind, modules}
	end

  @doc """
  Callback to start the TCP endpoint
  """

  def start_link(scheme, endpoint, {m, f, [ref | _] = a}) do
    # ref is used by Ranch to identify its listeners
    case apply(m, f, a) do
      {:ok, pid} ->
        Logger.info info(scheme, endpoint, ref)
        {:ok, pid}
      {:error, {:shutdown, {_,_, {{_, {:error, :eaddrinuse}}, _}}}} = error ->
        Logger.error [info(scheme, endpoint, ref), " failed, port already in use"]
        error
      {:error, _} = error ->
        error
    end
  end

  def default_for(PhoenixTCP.Transports.TCP), do: PhoenixTCP.RanchServer

  defp info(scheme, endpoint, ref) do
    port = :ranch.get_port(ref)
    "Running #{inspect endpoint} with Ranch using #{scheme} on port #{port}"
  end
end
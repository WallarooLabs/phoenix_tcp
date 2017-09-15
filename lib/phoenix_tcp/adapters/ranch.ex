defmodule PhoenixTCP.Adapters.Ranch do

  def args(scheme, plug, _opts, ranch_options) do
    ranch_options
      |> Keyword.put_new(:ref, build_ref(plug, scheme))
      |> to_args()
  end

  @doc """
  Shutdowns the given reference.
  """
  def shutdown(ref) do
    :ranch.stop_listener(ref)
  end

  @doc """
  Returns a child spec to be supervised by your application.
  """
  def child_spec(scheme, plug, opts, ranch_options \\ []) do
    [ref, nb_acceptors, tcp_server, trans_opts, proto_opts] = args(scheme, plug, opts, ranch_options)
    ranch_module = case scheme do
      :tcp -> :ranch_tcp
      # add ssl later?
    end
    :ranch.child_spec(ref, nb_acceptors, ranch_module, trans_opts, tcp_server, proto_opts)
  end

  @tcp_ranch_options [port: 5001]
  @protocol_options []

  defp to_args(all_opts) do
    {initial_transport_options, opts} = Enum.partition(all_opts, &is_atom/1)
    opts = Keyword.delete(opts, :otp_app)
    {ref, opts} = Keyword.pop(opts, :ref)
    {handlers, opts} = Keyword.pop(opts, :handlers)
    {acceptors, opts} = Keyword.pop(opts, :acceptors, 100)
    {tcp_server, opts} = Keyword.pop(opts, :tcp_server, PhoenixTCP.RanchServer)
    {protocol_options, opts} = Keyword.pop(opts, :protocol_options, [])
    {extra_options, transport_options} = Keyword.split(opts, @protocol_options)
    protocol_options = [handlers: handlers] ++ protocol_options ++ extra_options
    [ref, acceptors, tcp_server, initial_transport_options ++ transport_options, protocol_options]
  end

  defp build_ref(plug, scheme) do
    Module.concat(plug, scheme |> to_string |> String.upcase)
  end
end

# PhoenixTCP

POC TCP Transport for the Phoenix Framework

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed as:

  1. Add phoenix_tcp to your list of dependencies in `mix.exs`:

        def deps do
          [{:phoenix_tcp, "~> 0.0.1"}]
  		  [{:phoenix_tcp, git: "git@github.com:sendence/phoenix_tcp.git", tag: "v0.0.1"}]
        end

## Setup

  1. In your application file add the following as a child after your `endpoint`:
    `supervisor(PhoenixTCP.Supervisor, [:app_name, Chat.Endpoint])`

  2. In your config.ex add to your endpoints config:
    ```
      tcp_handler: PhoenixTCP.RanchHandler,
      tcp: [port: System.get_env("PHX_TCP_PORT") || 5001]
    ```

  3. In your socket(s) add the following:
    `transport :tcp, PhoenixTCP.Transports.TCP`

## Usage

in order to send data to Phoenix over TCP using this transport, the data must be sent in binary format. The first 4 bytes will be used to determine the message size and the remaining bytes will be the message.
Ex. using Elixir:
```
iex> opts = [:binary, active: false]
[:binary, {:active, false}]
iex> {:ok, socket} = :gen_tcp.connect('localhost', 5001, opts)
{:ok, #Port<0.5652>}
iex> path = "{\"path\": \"/socket/tcp\", \"params\": {}}"
"{\"path\": \"/socket/tcp\", \"params\": {}}"
iex> path_msg = << byte_size(path) :: size(32) >> <> path
<<0, 0, 0, 37, 123, ... 125, 125>>
iex> :tcp_send(socket, path_msg)
...
```

The server initially expects to receive the following message in json:
`{"path": "/:path", "params": {}}`

once a connection is established, the standard Phoenix join event is expected (a ref must be passed):
`{"event": "phx_join", "topic": "topic-name", "payload": null, "ref": null}`

and subsequent messages are sent after the join is established in the same structure:
`{"event": ..., "topic": ..., "payload": ..., "ref": ...}`





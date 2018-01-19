defmodule PhoenixTCP.Mixfile do
  use Mix.Project

  def project do
    [app: :phoenix_tcp,
     version: "0.0.1",
     elixir: "~> 1.5.2",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps()]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [applications: [:logger, :ranch, :phoenix, :poison]]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [{:ranch, "~> 1.0", manager: :rebar},
     {:poison, "~> 3.1.0"},
     {:phoenix, "~> 1.3.0"}]
  end
end

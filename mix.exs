defmodule Ip2Asn.MixProject do
  use Mix.Project

  def project do
    [
      app: :ip2asn,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {Ip2Asn.Application, []},
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:rustler, "~> 0.37.3"},
      {:cachex, "~> 3.6"},
      {:req, "~> 0.5"}
    ]
  end
end

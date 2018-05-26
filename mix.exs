defmodule TypeGenerators.MixProject do
  use Mix.Project

  def project do
    [
      app: :type_generators,
      version: "0.1.0",
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps() do
    [{:stream_data, "~> 0.1", only: :test}]
  end
end

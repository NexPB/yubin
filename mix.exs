defmodule Yubin.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/NexPB/yubin"

  def project do
    [
      app: :yubin,
      version: @version,
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "Japanese postal code lookup with data bundled from Japan Post.",
      package: package(),
      docs: docs(),
      source_url: @source_url
    ]
  end

  def application do
    [mod: {Yubin.Application, []}, extra_applications: []]
  end

  # build/ holds `mix yubin.build` and is not part of the package. The task needs Req, a dev-only dep.
  defp elixirc_paths(:dev), do: ["lib", "build"]
  defp elixirc_paths(:test), do: ["lib", "build/yubin"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:nimble_csv, "~> 1.3", only: [:dev, :test], runtime: false},
      {:req, "~> 0.7.5", only: :dev, runtime: false},
      {:ex_doc, "~> 0.40", only: :dev, runtime: false},
      {:benchee, "~> 1.5", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url, "Japan Post" => "https://www.post.japanpost.jp/zipcode/"},
      files: ~w(lib priv/postal.etf mix.exs README.md LICENSE)
    ]
  end

  defp docs do
    [main: "Yubin", source_ref: "v#{@version}", extras: ["README.md"]]
  end
end

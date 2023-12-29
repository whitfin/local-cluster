defmodule LocalCluster.MixProject do
  use Mix.Project

  @version "1.2.1"
  @url_github "https://github.com/whitfin/local-cluster"

  def project do
    [
      app: :local_cluster,
      name: "LocalCluster",
      description: "Easy local cluster creation to aid in unit testing",
      package: %{
        files: [
          "lib",
          "mix.exs",
          "LICENSE"
        ],
        licenses: ["MIT"],
        links: %{
          "GitHub" => @url_github
        },
        maintainers: ["Isaac Whitfield"]
      },
      version: @version,
      elixir: "~> 1.5",
      deps: deps(),
      docs: [
        main: "LocalCluster",
        source_ref: "v#{@version}",
        source_url: @url_github
      ],
      aliases: [
        test: "test --no-start"
      ],
      preferred_cli_env: [
        docs: :docs,
        credo: :lint
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :global_flags]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # Production dependencies
      {:global_flags, "~> 1.0"},
      # Local dependencies, not shipped with the app
      {:credo, "~> 1.6", optional: true, only: [:lint]},
      {:ex_doc, "~> 0.24", optional: true, only: [:docs]}
    ]
  end
end

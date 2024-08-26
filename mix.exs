defmodule LocalCluster.MixProject do
  use Mix.Project

  @version "2.0.0"
  @url_docs "http://hexdocs.pm/local_cluster"
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
          "Docs" => @url_docs,
          "GitHub" => @url_github
        },
        maintainers: ["Isaac Whitfield"]
      },
      version: @version,
      elixir: "~> 1.7",
      deps: deps(),
      docs: [
        main: "LocalCluster",
        source_ref: "v#{@version}",
        source_url: @url_github
      ],
      aliases: [
        test: "test --no-start"
      ],
      test_coverage: [
        tool: ExCoveralls
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
      {:credo, "~> 1.7", optional: true, only: [:lint]},
      {:ex_doc, "~> 0.29", optional: true, only: [:docs]},
      {:excoveralls, "~> 0.15", optional: true, only: [:cover]}
    ]
  end
end

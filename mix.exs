defmodule LocalCluster.MixProject do
  use Mix.Project

  @version "1.0.0"
  @url_docs "http://hexdocs.pm/local_cluster"
  @url_github "https://github.com/whitfin/local_cluster"

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
        licenses: [ "MIT" ],
        links: %{
          "Docs" => @url_docs,
          "GitHub" => @url_github
        },
        maintainers: [ "Isaac Whitfield" ]
      },
      version: @version,
      elixir: "~> 1.2",
      deps: deps(),
      docs: [
        main: "LocalCluster",
        source_ref: "v#{@version}",
        source_url: @url_github,
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"},
    ]
  end
end

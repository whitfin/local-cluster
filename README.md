# LocalCluster
[![Coverage Status](https://img.shields.io/coveralls/whitfin/local-cluster.svg)](https://coveralls.io/github/whitfin/local-cluster) [![Unix Build Status](https://img.shields.io/travis/whitfin/local-cluster.svg?label=unix)](https://travis-ci.org/whitfin/local-cluster) [![Windows Build Status](https://img.shields.io/appveyor/ci/whitfin/local-cluster.svg?label=win)](https://ci.appveyor.com/project/whitfin/local-cluster) [![Hex.pm Version](https://img.shields.io/hexpm/v/local-cluster.svg)](https://hex.pm/packages/local-cluster) [![Documentation](https://img.shields.io/badge/docs-latest-blue.svg)](https://hexdocs.pm/local-cluster/)

This library is designed to assist in testing distributed states in Elixir
which require a number of local nodes.

The aim is to provide a small set of functions which hide the complexity of
spawning local nodes, as well as providing the ease of cleaning up the started
nodes. The entire library is simple shimming around the Erlang APIs for dealing
with distributed nodes, As some of it is non-obvious, and as I need this code
for several projects, I span it out as a smaller project.

To install it for your project, you can pull it directly from Hex. Rather
than use the version shown below, you can use the the latest version from
Hex (shown at the top of this README).

```elixir
def deps do
  [{:local-cluster, "~> 1.0", only: [:test]}]
end
```

Documentation and examples can be found on [Hexdocs](https://hexdocs.pm/local-cluster/)
as they're updated automatically alongside each release. Note that you should only
use the `:test` flag in your dependency if you're not using it for other environments.

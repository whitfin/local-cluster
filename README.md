# LocalCluster
[![Build Status](https://img.shields.io/travis/whitfin/local-cluster.svg?label=unix)](https://travis-ci.org/whitfin/local-cluster) [![Hex.pm Version](https://img.shields.io/hexpm/v/local_cluster.svg)](https://hex.pm/packages/local_cluster) [![Documentation](https://img.shields.io/badge/docs-latest-blue.svg)](https://hexdocs.pm/local_cluster/)

This library is designed to assist in testing distributed states in Elixir
which require a number of local nodes.

The aim is to provide a small set of functions which hide the complexity of
spawning local nodes, as well as providing the ease of cleaning up the started
nodes. The entire library is simple shimming around the Erlang APIs for dealing
with distributed nodes, As some of it is non-obvious, and as I need this code
for several projects, I span it out as a smaller project.

## Installation

To install it for your project, you can pull it directly from Hex. Rather
than use the version shown below, you can use the the latest version from
Hex (shown at the top of this README).

```elixir
def deps do
  [{:local_cluster, "~> 1.0", only: [:test]}]
end
```

Documentation and examples can be found on [Hexdocs](https://hexdocs.pm/local_cluster/)
as they're updated automatically alongside each release. Note that you should only
use the `:test` flag in your dependency if you're not using it for other environments.

## Usage

As mentioned above, the API is deliberately _tiny_ to make it easier to use this
library when testing. Below is an example of using this library to spawn a set of
child nodes for testing:

```elixir
defmodule MyTest do
  use ExUnit.Case

  test "something with a required cluster" do
    :ok = LocalCluster.start()

    nodes = LocalCluster.start_nodes("my-cluster", 3)

    [node1, node2, node3] = nodes

    assert Node.ping(node1) == :pong
    assert Node.ping(node2) == :pong
    assert Node.ping(node3) == :pong

    :ok = LocalCluster.stop_nodes([node1])

    assert Node.ping(node1) == :pang
    assert Node.ping(node2) == :pong
    assert Node.ping(node3) == :pong

    :ok = LocalCluster.stop()

    assert Node.ping(node1) == :pang
    assert Node.ping(node2) == :pang
    assert Node.ping(node3) == :pang
  end
end
```

After calling `start_nodes/2`, you will receive a list of node names you can then use
to communicate with via RPC or however you'd like. Although they're automatically cleaned
up when the calling process dies, you can manually stop nodes as well to test disconnection.

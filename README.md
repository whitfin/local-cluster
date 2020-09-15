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
  [{:local_cluster, "~> 1.1", only: [:test]}]
end
```

Documentation and examples can be found on [Hexdocs](https://hexdocs.pm/local_cluster/)
as they're updated automatically alongside each release. Note that you should only
use the `:test` flag in your dependency if you're not using it for other environments.

## Setup

To configure your test suites for cluster testing, you need to run through a one-time
setup to change some stuff in your `test_helper.exs`. This is required to avoid some
potential issues with your node name changing after your application tree has already
stated. This also reduces some bloat due to having `LocalCluster.start/0` in most test
cases. The snippet below can be used as a sample helper file. Make sure to change the
application name to match your application name.

```elixir
# start the current node as a manager
:ok = LocalCluster.start()

# start your application tree manually
Application.ensure_all_started(:my_app)

# run all tests!
ExUnit.start()
```

You will also need to pass the `--no-start` flag to `mix test`. Fortunately this is
easy enough, as you can add an alias in your `mix.exs` to do this automatically:

```elixir
def project do
  [
    # ...
    aliases: [
      test: "test --no-start"
    ]
    # ...
  ]
end
```

This library itself uses this setup, so you can copy/paste as needed or use as an
example when integrating into your own codebase.

## Usage

As mentioned above, the API is deliberately _tiny_ to make it easier to use this
library when testing. Below is an example of using this library to spawn a set of
child nodes for testing:

```elixir
defmodule MyTest do
  use ExUnit.Case

  test "something with a required cluster" do
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

`start_nodes/3` accepts list of options as an additional parameter.
Two options are currently supported: `:app_names` and `:files`, as described below.

Use option `:app_names` with an ordered list of application names for scenarios
where the order of applications starting is critical, or where only a subset of apps is desired. 
If the option is not present, all currently running applications will be started on each node, 
in the same order as reported by `Application.loaded_applications/0`.
Note that each application is started via `Application.ensure_all_started/2`, i.e. with all dependencies.

```elixir
    nodes = LocalCluster.start_nodes(:cluster, 16, [
      app_names: [
        :start_this_application, :and_then_this_one
      ]
    ])
```

If you need to load any additional files onto the remote nodes, you can make use of the
`:files` option at startup time by providing an absolute file path to compile on the
cluster. This is necessary if you wish to spawn tasks onto the cluster from inside your
test code, as your test code is not loaded into the cluster automatically:

```elixir
defmodule MyTest do
  use ExUnit.Case

  test "spawning tasks on a cluster" do
    nodes = LocalCluster.start_nodes(:spawn, 3, [
      files: [
        __ENV__.file
      ]
    ])

    [node1, node2, node3] = nodes

    assert Node.ping(node1) == :pong
    assert Node.ping(node2) == :pong
    assert Node.ping(node3) == :pong

    caller = self()

    Node.spawn(node1, fn ->
      send(caller, :from_node_1)
    end)

    Node.spawn(node2, fn ->
      send(caller, :from_node_2)
    end)

    Node.spawn(node3, fn ->
      send(caller, :from_node_3)
    end)

    assert_receive :from_node_1
    assert_receive :from_node_2
    assert_receive :from_node_3
  end
end
```

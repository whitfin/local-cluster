defmodule LocalClusterTest do
  use ExUnit.Case
  doctest LocalCluster

  test "creates and stops child nodes" do
    nodes = LocalCluster.start_nodes(:child, 3)

    [node1, node2, node3] = nodes

    assert Node.ping(node1) == :pong
    assert Node.ping(node2) == :pong
    assert Node.ping(node3) == :pong

    :ok = LocalCluster.stop_nodes([node1])

    assert Node.ping(node1) == :pang
    assert Node.ping(node2) == :pong
    assert Node.ping(node3) == :pong

    :ok = LocalCluster.stop_nodes([node2, node3])

    assert Node.ping(node1) == :pang
    assert Node.ping(node2) == :pang
    assert Node.ping(node3) == :pang
  end

  test "spawns tasks directly on child nodes" do
    nodes =
      LocalCluster.start_nodes(:spawn, 3,
        files: [
          __ENV__.file
        ]
      )

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

  test "copies configurations in child nodes" do
    n_children = 3
    key = :"#{__MODULE__}.#{:rand.uniform(1_000)}"
    value = :rand.uniform(1_000)

    Application.put_env(:local_cluster, key, value)

    on_exit(fn ->
      Application.delete_env(:local_cluster, key)
    end)

    nodes = LocalCluster.start_nodes(:child, n_children)

    assert :rpc.multicall(nodes, Application, :get_env, [:local_cluster, key]) ==
             {List.duplicate(value, n_children), []}
  end
end

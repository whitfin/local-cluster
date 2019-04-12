defmodule LocalClusterTest do
  use ExUnit.Case
  require LocalCluster
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

    :ok = LocalCluster.stop()

    assert Node.ping(node1) == :pang
    assert Node.ping(node2) == :pang
    assert Node.ping(node3) == :pang
  end

  test "can send anonymous function to child node" do
    [node] = LocalCluster.start_nodes(:spawn_child, 1)

    assert Node.ping(node) == :pong

    test_pid = self()
    spawn(fn -> send(test_pid, :hello_local) end)

    Node.spawn(node, fn -> send(test_pid, :hello_cluster) end)

    assert_receive :hello_local
    assert_receive :hello_cluster
  end
end

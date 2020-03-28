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

  test "slave environments can be overwritten" do
    env = "env_override_#{:random.uniform(999)}" |> String.to_atom()
    env_var_a = "override_a_#{:random.uniform(999)}" |> String.to_atom()
    env_var_b = "override_a_#{:random.uniform(999)}" |> String.to_atom()
    Application.put_env(:local_cluster, env, :none)

    [node_a] = LocalCluster.start_nodes(:env_override_a, 1, [
      env_override: [local_cluster: [{env, env_var_a}]]
    ])
    [node_b] = LocalCluster.start_nodes(:env_override_b, 1, [
      env_override: [local_cluster: [{env, env_var_b}]]
    ])
    [node_none] = LocalCluster.start_nodes(:env_override_no, 1)

    # Local environment remains unchanged.
    assert Application.get_env(:local_cluster, env) == :none

    # Modifying the environment doesn't affect the remote nodes.
    Application.delete_env(:local_cluster, env)

    assert env_var_a == :rpc.block_call(node_a, Application, :get_env, [:local_cluster, env])
    assert env_var_b == :rpc.block_call(node_b, Application, :get_env, [:local_cluster, env])
    assert :none == :rpc.block_call(node_none, Application, :get_env, [:local_cluster, env])
  end
end

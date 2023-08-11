defmodule LocalClusterTest do
  use ExUnit.Case
  doctest LocalCluster

  test "creates and stops child nodes" do
    nodes = LocalCluster.start_nodes(:child, 3)

    [{node1, n1pid}, {node2, n2pid}, {node3, n3pid}] = nodes

    assert Node.ping(node1) == :pong
    assert Node.ping(node2) == :pong
    assert Node.ping(node3) == :pong

    :ok = LocalCluster.stop_nodes([n1pid])

    assert Node.ping(node1) == :pang
    assert Node.ping(node2) == :pong
    assert Node.ping(node3) == :pong

    :ok = LocalCluster.stop_nodes([n2pid, n3pid])

    assert Node.ping(node1) == :pang
    assert Node.ping(node2) == :pang
    assert Node.ping(node3) == :pang
  end

  test "load selected applications" do
    nodes = LocalCluster.start_nodes(:child, 1, [
      applications: [
        :local_cluster,
        :ex_unit,
        :no_real_app
      ]
    ])

    [{node1, _}] = nodes

    node1_apps =
      node1
      |> :rpc.call(Application, :loaded_applications, [])
      |> Enum.map(fn {app_name, _, _} -> app_name end)

    assert :local_cluster in node1_apps
    assert :ex_unit in node1_apps
    assert (:no_real_app in node1_apps) == false

    peer_pids = Enum.map(nodes, &(elem(&1, 1)))

    :ok = LocalCluster.stop_nodes(peer_pids)
  end

  test "spawns tasks directly on child nodes" do
    nodes = LocalCluster.start_nodes(:spawn, 3, [
      files: [
        __ENV__.file
      ]
    ])

    [{node1, _}, {node2, _}, {node3, _}] = nodes

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

  test "overriding environment variables on child nodes" do
    [{node1, _}] = LocalCluster.start_nodes(:cluster_var_a, 1, [
      environment: [
        local_cluster: [override: "test1"]
      ]
    ])

    [{node2, _}] = LocalCluster.start_nodes(:cluster_var_b, 1, [
      environment: [
        local_cluster: [override: "test2"]
      ]
    ])

    [{node3, _}] = LocalCluster.start_nodes(:cluster_no_env, 1)

    node1_env = :rpc.call(node1, Application, :get_env, [:local_cluster, :override])
    node2_env = :rpc.call(node2, Application, :get_env, [:local_cluster, :override])
    node3_env = :rpc.call(node3, Application, :get_env, [:local_cluster, :override])

    assert node1_env == "test1"
    assert node2_env == "test2"
    assert node3_env == Application.get_env(:local_cluster, :override)
  end
end

defmodule LocalClusterTest do
  use ExUnit.Case
  import LocalCluster
  doctest LocalCluster

  test "creates and stops local clusters" do
    # create a new cluster of 3 nodes
    {:ok, cluster} = LocalCluster.start_link(3)

    # fetch the list of nodes contained in the cluster
    {:ok, [node1, node2, node3]} = LocalCluster.nodes(cluster)

    # check that all nodes respond
    assert Node.ping(node1) == :pong
    assert Node.ping(node2) == :pong
    assert Node.ping(node3) == :pong

    # stop a single node in our cluster
    :ok = LocalCluster.stop(cluster, node1)

    # check that node does not respond
    assert Node.ping(node1) == :pang
    assert Node.ping(node2) == :pong
    assert Node.ping(node3) == :pong

    # stop the entire cluster
    :ok = LocalCluster.stop(cluster)

    # check that no nodes respond
    assert Node.ping(node1) == :pang
    assert Node.ping(node2) == :pang
    assert Node.ping(node3) == :pang
  end

  test "adding members to an existing cluster" do
    # create a new cluster of 3 nodes
    {:ok, cluster} = LocalCluster.start_link(3)

    # fetch the list of nodes contained in the cluster
    {:ok, [node1, node2, node3]} = LocalCluster.nodes(cluster)

    # add another node to the existing cluster
    {:ok, [member(node: node4)]} = LocalCluster.start(cluster, 1)

    # verify it's reflected in the node listing alongside the others
    {:ok, [^node1, ^node2, ^node3, ^node4]} = LocalCluster.nodes(cluster)
  end

  test "fetching pids and nodes from members" do
    # create a new cluster of 3 nodes
    {:ok, cluster} = LocalCluster.start_link(3)

    # pull back the members as well as nodes and pids to compare
    {:ok, [member1, member2, member3]} = LocalCluster.members(cluster)
    {:ok, [node1, node2, node3]} = LocalCluster.nodes(cluster)
    {:ok, [pid1, pid2, pid3]} = LocalCluster.pids(cluster)

    # make sure they all match as we expect
    assert member1 == member(pid: pid1, node: node1)
    assert member2 == member(pid: pid2, node: node2)
    assert member3 == member(pid: pid3, node: node3)
  end

  test "stopping nodes using various types" do
    # create a new cluster of 3 nodes
    {:ok, cluster} = LocalCluster.start_link(3)

    # fetch the list of nodes contained in the cluster
    {:ok, [node1, node2, node3]} = LocalCluster.nodes(cluster)
    {:ok, [member1, _, _]} = LocalCluster.members(cluster)
    {:ok, [_, _, pid3]} = LocalCluster.pids(cluster)

    # check that all nodes respond
    assert Node.ping(node1) == :pong
    assert Node.ping(node2) == :pong
    assert Node.ping(node3) == :pong

    # stop using member, duplicate to check crash
    :ok = LocalCluster.stop(cluster, member1)
    :ok = LocalCluster.stop(cluster, member1)

    # check that node does not respond
    assert Node.ping(node1) == :pang
    assert Node.ping(node2) == :pong
    assert Node.ping(node3) == :pong

    # stop using node, duplicate to check crash
    :ok = LocalCluster.stop(cluster, node2)
    :ok = LocalCluster.stop(cluster, node2)

    # check that node does not respond
    assert Node.ping(node1) == :pang
    assert Node.ping(node2) == :pang
    assert Node.ping(node3) == :pong

    # stop using pid, duplicate to check crash
    :ok = LocalCluster.stop(cluster, pid3)
    :ok = LocalCluster.stop(cluster, pid3)

    # check that node does not respond
    assert Node.ping(node1) == :pang
    assert Node.ping(node2) == :pang
    assert Node.ping(node3) == :pang
  end

  test "loads selected applications in a local cluster" do
    # create a cluster
    {:ok, cluster} =
      LocalCluster.start_link(1,
        prefix: "child",
        applications: [
          :local_cluster,
          :ex_unit,
          :no_real_app
        ]
      )

    # greb the node back from the cluster
    {:ok, [node1]} = LocalCluster.nodes(cluster)

    # list the apps
    node1_apps =
      node1
      |> :rpc.call(Application, :loaded_applications, [])
      |> Enum.map(fn {app_name, _, _} -> app_name end)

    # check the apps we know of
    assert :local_cluster in node1_apps
    assert :ex_unit in node1_apps
    assert :no_real_app in node1_apps == false
  end

  test "spawns tasks directly in a local cluster" do
    # create a cluster
    {:ok, cluster} =
      LocalCluster.start_link(3,
        prefix: "spawn",
        files: [
          __ENV__.file
        ]
      )

    # fetch back the nodes from our newly created cluster
    {:ok, [node1, node2, node3]} = LocalCluster.nodes(cluster)

    # check all nodes respond
    assert Node.ping(node1) == :pong
    assert Node.ping(node2) == :pong
    assert Node.ping(node3) == :pong

    # store our pid
    caller = self()

    # send back from node1
    Node.spawn(node1, fn ->
      send(caller, :from_node_1)
    end)

    # send back from node2
    Node.spawn(node2, fn ->
      send(caller, :from_node_2)
    end)

    # send back from node3
    Node.spawn(node3, fn ->
      send(caller, :from_node_3)
    end)

    # make sure we got all
    assert_receive :from_node_1
    assert_receive :from_node_2
    assert_receive :from_node_3
  end

  test "overriding environment in a local cluster" do
    # override a value in the local environment for the test
    Application.put_env(:local_cluster, :foo, "bar")

    # create a cluster
    {:ok, cluster1} =
      LocalCluster.start_link(1,
        environment: [
          local_cluster: [foo: "bar1"]
        ]
      )

    # create another cluster
    {:ok, cluster2} =
      LocalCluster.start_link(1,
        environment: [
          local_cluster: [foo: "bar2"]
        ]
      )

    # create a final cluster using defaults
    {:ok, cluster3} = LocalCluster.start_link(1)

    # fetch the nodes from each cluster we made
    {:ok, [node1]} = LocalCluster.nodes(cluster1)
    {:ok, [node2]} = LocalCluster.nodes(cluster2)
    {:ok, [node3]} = LocalCluster.nodes(cluster3)

    # grab the environment for the :local_cluster app from each node
    node1_env = :rpc.call(node1, Application, :get_env, [:local_cluster, :foo])
    node2_env = :rpc.call(node2, Application, :get_env, [:local_cluster, :foo])
    node3_env = :rpc.call(node3, Application, :get_env, [:local_cluster, :foo])

    # double check them all
    assert node1_env == "bar1"
    assert node2_env == "bar2"
    assert node3_env == Application.get_env(:local_cluster, :foo)
  end

  test "resilience to being started multiple times" do
    LocalCluster.start()
    LocalCluster.start()
  end

  test "being spawned underneath a supervisor" do
    children = [
      {LocalCluster, {3, [name: :supervised_cluster]}}
    ]

    {:ok, _} = Supervisor.start_link(children, strategy: :one_for_one)
    {:ok, [_, _, _]} = LocalCluster.nodes(:supervised_cluster)
  end
end

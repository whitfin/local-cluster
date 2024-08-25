defmodule LocalCluster do
  @moduledoc """
  Easy local cluster handling for Elixir.

  This library is a utility library to offer easier testing of distributed
  clusters for Elixir. It offers very minimal shimming above several built
  in Erlang features to provide seamless node creations, especially useful
  when testing distributed applications.
  """

  alias LocalCluster.Peer

  @doc """
  Starts the current node as a distributed node.
  """
  @spec start :: :ok
  def start do
    # boot server startup
    start_boot_server = fn ->
      # voodoo flag to generate a "started" atom flag
      :global_flags.once("local_cluster:started", fn ->
        {:ok, _} =
          :erl_boot_server.start([
            {127, 0, 0, 1}
          ])
      end)

      :ok
    end

    # only ever handle the :erl_boot_server on the initial startup
    case :net_kernel.start([:"manager@127.0.0.1"]) do
      # handle nodes that have already been started elsewhere
      {:error, {:already_started, _}} -> start_boot_server.()
      # handle the node being started
      {:ok, _} -> start_boot_server.()
      # pass anything else
      anything -> anything
    end
  end

  @doc """
  Starts a number of namespaced child nodes.

  This will start the current runtime environment on a set of child nodes
  and return a list of `%LocalCluster.Peer{}` structs for further use. All child
  nodes are linked to the current process, and so will terminate when the
  parent process does for automatic cleanup.

  The `:applications` option allows the caller to provide an ordered list
  of applications to be started on child nodes. This is useful when you
  need to control startup sequences, or omit applications completely. If
  this option is not provided, all currently loaded applications on the
  local node will be used as a default.

  The `:files` option can be used to load additional files onto remote
  nodes, which are then compiled on the remote node. This is necessary
  if you wish to spawn tasks from inside test code, as test code would
  not typically be loaded automatically.

  The caller should use `LocalCluster.node(peer)` and `LocalCluster.nodes(peers)`
  to retrieve the node names.
  """
  @spec start_nodes(binary, integer, Keyword.t()) :: [Peer.t()]
  def start_nodes(prefix, amount, options \\ [])
      when (is_binary(prefix) or is_atom(prefix)) and is_integer(amount) do
    peers =
      Enum.map(1..amount, fn idx ->
        {:ok, peer} = Peer.start_link(prefix, idx)

        peer
      end)

    rpc = &({_, []} = :rpc.multicall(Peer.nodes(peers), &1, &2, &3))

    rpc.(:code, :add_paths, [:code.get_path()])

    rpc.(Application, :ensure_all_started, [:mix])
    rpc.(Application, :ensure_all_started, [:logger])

    rpc.(Logger, :configure, [[level: Logger.level()]])
    rpc.(Mix, :env, [Mix.env()])

    loaded_apps =
      for {app_name, _, _} <- Application.loaded_applications() do
        base = Application.get_all_env(app_name)

        environment =
          options
          |> Keyword.get(:environment, [])
          |> Keyword.get(app_name, [])
          |> Keyword.merge(base, fn _, v, _ -> v end)

        for {key, val} <- environment do
          rpc.(Application, :put_env, [app_name, key, val])
        end

        app_name
      end

    ordered_apps = Keyword.get(options, :applications, loaded_apps)

    for app_name <- ordered_apps, app_name in loaded_apps do
      rpc.(Application, :ensure_all_started, [app_name])
    end

    for file <- Keyword.get(options, :files, []) do
      rpc.(Code, :require_file, [file])
    end

    peers
  end

  @doc """
  Stops a set of child nodes.
  """
  @spec stop_nodes([Peer.t()]) :: :ok
  def stop_nodes(peers) when is_list(peers),
    do: Enum.each(peers, &Peer.stop/1)

  defdelegate nodes(peers), to: Peer
  defdelegate node(peer), to: Peer

  @doc """
  Stops the current distributed node and turns it back into a local node.
  """
  @spec stop :: :ok | {:error, atom}
  def stop,
    do: :net_kernel.stop()
end

defmodule LocalCluster do
  @moduledoc """
  Easy local cluster handling for Elixir.

  This library is a utility library to offer easier testing of distributed
  clusters for Elixir. It offers very minimal shimming above several built
  in Erlang features to provide seamless node creations, especially useful
  when testing distributed applications.
  """

  @doc """
  Starts the current node as a distributed node.
  """
  @spec start :: :ok
  def start do
    # only ever handle the :erl_boot_server on the initial startup
    with { :ok, _ } <- :net_kernel.start([ :"manager@127.0.0.1" ]) do
      # voodoo flag to generate a "started" atom flag
      GlobalLazy.init("#{__MODULE__}:started", fn ->
        { :ok, _ } = :erl_boot_server.start([
          { 127, 0, 0, 1 }
        ])
      end)
    end
  end

  @doc """
  Starts a number of namespaced child nodes.

  This will start the current runtime environment on a set of child nodes
  and return the names of the nodes to the user for further use. All child
  nodes are linked to the current process, and so will terminate when the
  parent process does for automatic cleanup.
  """
  @spec start_nodes(binary, integer) :: [ atom ]
  def start_nodes(prefix, amount)
  when (is_binary(prefix) or is_atom(prefix)) and is_integer(amount) do
    nodes = Enum.map(1..amount, fn idx ->
      { :ok, name } = :slave.start_link(
        '127.0.0.1',
        :"#{prefix}#{idx}",
        '-loader inet -hosts 127.0.0.1 -setcookie #{:erlang.get_cookie()}'
      )
      name
    end)

    rpc = &({ _, [] } = :rpc.multicall(nodes, &1, &2, &3))

    rpc.(:code, :add_paths, [ :code.get_path() ])
    rpc.(Application, :ensure_all_started, [ :mix ])
    rpc.(Mix, :env, [ Mix.env() ])

    for { app_name, _, _ } <- Application.loaded_applications() do
      for { key, val } <- Application.get_all_env(app_name) do
        rpc.(Application, :put_env, [ app_name, key, val ])
      end
      rpc.(Application, :ensure_all_started, [ app_name ])
    end

    nodes
  end

  @doc """
  Stops a set of child nodes.
  """
  @spec stop_nodes([ atom ]) :: :ok
  def stop_nodes(nodes) when is_list(nodes),
    do: Enum.each(nodes, &:slave.stop/1)

  @doc """
  Stops the current distributed node and turns it back into a local node.
  """
  @spec stop :: :ok | { :error, atom }
  def stop,
    do: :net_kernel.stop()
end

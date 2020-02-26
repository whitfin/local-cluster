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
    # boot server startup
    start_boot_server = fn ->
      # voodoo flag to generate a "started" atom flag
      :global_flags.once("local_cluster:started", fn ->
        { :ok, _ } = :erl_boot_server.start([
          { 127, 0, 0, 1 }
        ])
      end)
      :ok
    end

    # only ever handle the :erl_boot_server on the initial startup
    case :net_kernel.start([ :"manager@127.0.0.1" ]) do
      # handle nodes that have already been started elsewhere
      { :error, { :already_started, _ } } -> start_boot_server.()
      # handle the node being started
      { :ok, _ } -> start_boot_server.()
      # pass anything else
      anything -> anything
    end
  end

  @doc """
  Starts a number of namespaced child nodes.

  This will start the current runtime environment on a set of child nodes
  and return the names of the nodes to the user for further use. All child
  nodes are linked to the current process, and so will terminate when the
  parent process does for automatic cleanup.

  Option `:app_names` specifies ordered list of applications to be started
  on child nodes. This is useful if only a subset of applications is needed.
  Application dependencies are started automatically.
  Note that only applications already loaded in current node will be started,
  other app names are silently ignored.
  Without this option, all currently loaded applications will be included.

  Option `:files` can be used to load additional files onto the remote nodes.
  Value is a list of absolute file paths to compile on the cluster.
  This is necessary if you wish to spawn tasks onto the cluster from inside
  the test code, as the test code is not loaded into the cluster automatically.
  """
  @spec start_nodes(binary, integer, Keyword.t) :: [ atom ]
  def start_nodes(prefix, amount, options \\ [])
  when (is_binary(prefix) or is_atom(prefix)) and is_integer(amount) do
    nodes = Enum.map(1..amount, fn idx ->
      { :ok, name } = :slave.start_link(
        '127.0.0.1',
        :"#{prefix}#{idx}",
        '-loader inet -hosts 127.0.0.1 -setcookie "#{:erlang.get_cookie()}"'
      )
      name
    end)

    rpc = &({ _, [] } = :rpc.multicall(nodes, &1, &2, &3))

    rpc.(:code, :add_paths, [ :code.get_path() ])

    rpc.(Application, :ensure_all_started, [ :mix ])
    rpc.(Application, :ensure_all_started, [ :logger ])

    rpc.(Logger, :configure, [ level: Logger.level() ])
    rpc.(Mix, :env, [ Mix.env() ])

    # copy all application environment values
    loaded_apps = for { app_name, _, _ } <- Application.loaded_applications() do
      for { key, val } <- Application.get_all_env(app_name) do
        rpc.(Application, :put_env, [ app_name, key, val ])
      end
      app_name
    end

    # start apps in specified order
    for app_name <- Keyword.get(options, :app_names, loaded_apps), app_name in loaded_apps do
      rpc.(Application, :ensure_all_started, [ app_name ])
    end

    for file <- Keyword.get(options, :files, []) do
      { :ok, source } = File.read(file)

      for { module, binary } <- Code.compile_string(source, file) do
        rpc.(:code, :load_binary, [
          module,
          :unicode.characters_to_list(file),
          binary
        ])
      end
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

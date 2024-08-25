defmodule LocalCluster.Peer do
  @moduledoc """
  Contains metadata about a peer that has been started with `LocalCluster.start_nodes/2`
  or `LocalCluster.start_nodes/3`.
  """
  import Kernel, except: [node: 1]

  @type t :: %__MODULE__{}

  defstruct [:node, :pid]

  @doc """
  Given a list of `LocalCluster.Peer` structs, returns the
  node names.

  The node names can be used for `:rpc` calls.
  """
  def nodes(peers) when is_list(peers) do
    Enum.map(peers, &node/1)
  end

  @doc """
  Given a `LocalCluster.Peer`, returns the node name.

  The node name can be used for `:rpc` calls.
  """
  def node(%__MODULE__{node: node}) do
    node
  end

  def start_link(prefix, idx) do
    args =
      ~w[-loader inet -hosts 127.0.0.1 -setcookie #{:erlang.get_cookie()}]
      |> Enum.map(&String.to_charlist/1)

    {:ok, pid, node} =
      start_link_int(%{
        host: ~c"127.0.0.1",
        name: :"#{prefix}#{idx}",
        args: args
      })

    {:ok, %__MODULE__{node: node, pid: pid}}
  end

  def stop(%__MODULE__{pid: pid, node: node}) do
    stop_int(pid, node)
  end

  if Code.ensure_loaded?(:peer) and function_exported?(:peer, :start_link, 1) do
    def start_link_int(opts), do: :peer.start_link(opts)
    def stop_int(pid, _node), do: :peer.stop(pid)
  else
    # Support for OTP < 25
    def start_link_int(%{host: host, name: name, args: args}) do
      case :slave.start_link(host, name, :string.join(args, ~c" ")) do
        {:ok, node} ->
          {:ok, nil, node}

        error ->
          error
      end
    end

    def stop_int(_pid, node), do: :slave.stop(node)
  end
end

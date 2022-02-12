# Should this be Define.Query? Will it be used outside of the build step?
defmodule Statechart.Definition.Query do
  alias Statechart.Definition
  alias Statechart.MetadataAccess, as: Metadata
  alias Statechart.Node
  alias Statechart.Tree
  alias Statechart.Tree.IsTree

  @type t :: Definition.t()

  #####################################
  # REDUCERS

  @spec update_node_by_name(t, Node.name(), (Node.t() -> Node.t())) ::
          {:ok, t} | {:error, :id_not_found}
  def update_node_by_name(statechart_def, name, update_fn) do
    with {:ok, node} <- fetch_node_by_name(statechart_def, name),
         {:ok, _statechart_def} = result <-
           Tree.update_node_by_id(statechart_def, Node.id(node), update_fn) do
      result
    else
      {:error, :id_not_found} = error -> error
    end
  end

  #####################################
  # CONVERTERS

  @spec fetch_node_by_metadata(t, Meta.t()) ::
          {:ok, Node.maybe_not_inserted()} | {:error, :no_metadata_match}
  def fetch_node_by_metadata(statechart_def, metadata) do
    statechart_def
    |> IsTree.fetch_nodes!()
    |> Enum.find(fn node -> Node.metadata(node) == metadata end)
    |> case do
      nil -> {:error, :no_metadata_match}
      %Node{} = node -> {:ok, node}
    end
  end

  # correct arg1 type?
  # TODO is maybe not inserted the right type?
  # TODO what error?
  @spec fetch_node_by_name(t, atom) ::
          {:ok, Node.t()} | {:error, :name_not_found} | {:error, :ambiguous_name}
  def fetch_node_by_name(statechart_def, name) when is_atom(name) do
    statechart_def
    |> local_nodes()
    |> Enum.filter(fn node -> Node.name(node) == name end)
    |> case do
      [%Node{} = node] -> {:ok, node}
      [] -> {:error, :name_not_found}
      _ -> {:error, :ambiguous_name}
    end
  end

  @spec local_nodes(t) :: [Node.t()]
  def local_nodes(%Definition{nodes: nodes} = statechart_def) do
    {:ok, tree_module} = Metadata.fetch_module(statechart_def)

    Enum.filter(nodes, fn node ->
      {:ok, node_module} = Metadata.fetch_module(node)
      tree_module == node_module
    end)
  end
end

# Should this be Define.Query? Will it be used outside of the build step?
defmodule Statechart.Definition.Query do
  alias Statechart.Node
  alias Statechart.TreeStructure

  # TODO rename be be more general, perhaps HasNodes?
  @type t :: TreeStructure

  #####################################
  # CONVERTERS

  @spec fetch_node_by_metadata(t, Node.meta()) ::
          {:ok, Node.maybe_not_inserted()} | {:error, :no_metadata_match}
  def fetch_node_by_metadata(tree, metadata) do
    tree
    |> TreeStructure.fetch_nodes!()
    |> Enum.find(fn node -> Node.metadata(node) == metadata end)
    |> case do
      nil -> {:error, :no_metadata_match}
      %Node{} = node -> {:ok, node}
    end
  end
end

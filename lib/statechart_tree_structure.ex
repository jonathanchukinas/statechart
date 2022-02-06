# TOOD rename NodesAccess
defprotocol Statechart.TreeStructure do
  @moduledoc false

  alias Statechart.Node

  # TODO this is just here for troubleshooting
  # turn it off eventually
  @fallback_to_any true

  # REDUCERS
  @spec put_nodes(t, [Node.t()]) :: t
  def put_nodes(tree, nodes)

  # CONVERTERS
  @spec fetch_nodes!(t) :: [Node.t()]
  def fetch_nodes!(tree)
end

defimpl Statechart.TreeStructure, for: Any do
  def put_nodes(not_a_tree, node) do
    raise "!!! #{inspect(not_a_tree)} is not a tree. Also, here's the node: #{inspect(node)}"
  end

  def fetch_nodes!(not_a_tree) do
    raise "!!! #{inspect(not_a_tree)} is not a tree"
  end
end

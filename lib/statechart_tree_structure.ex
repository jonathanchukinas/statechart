defprotocol Statechart.TreeStructure do
  alias Statechart.Node

  # REDUCERS
  @spec put_nodes(t, [Node.t()]) :: t
  def put_nodes(tree, nodes)

  # CONVERTERS
  @spec fetch_nodes!(t) :: [Node.t()]
  def fetch_nodes!(tree)
end

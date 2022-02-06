defprotocol Statechart.Tree.IsTree do
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

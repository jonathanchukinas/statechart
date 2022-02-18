alias Statechart.Node
alias Statechart.Chart

defprotocol Statechart.Tree.Insertable do
  @moduledoc false
  # Trees can have individual nodes or entire subtrees inserted into them.
  # This protocol defines the interface for these two types of "insertables".
  @spec nodes(t) :: [Node.maybe_not_inserted()]
  def nodes(insertable)

  @spec min_id(t) :: Node.id()
  def min_id(insertable)
end

defimpl Statechart.Tree.Insertable, for: Node do
  @spec nodes(Node.not_inserted()) :: [Node.not_inserted()]
  def nodes(node), do: [node]

  def min_id(node), do: Node.id(node)
end

defimpl Statechart.Tree.Insertable, for: Chart do
  @spec nodes(Chart.t()) :: [Node.t()]
  defdelegate nodes(definition), to: Chart

  defdelegate min_id(definition), to: Statechart.Tree, as: :min_node_id
end

alias Statechart.Node
alias Statechart.Definition

defprotocol Statechart.Tree.Insertable do
  @moduledoc false
  # Trees can have individual nodes or entire subtrees inserted into them.
  # This protocol defines the interface for these two types of "insertables".
  @spec nodes(t) :: [Node.maybe_not_inserted()]
  def nodes(insertable)
end

defimpl Statechart.Tree.Insertable, for: Node do
  @spec nodes(Node.not_inserted()) :: [Node.not_inserted()]
  def nodes(node), do: [node]
end

defimpl Statechart.Tree.Insertable, for: Definition do
  @spec nodes(Definition.t()) :: [Node.t()]
  defdelegate nodes(definition), to: Definition
end

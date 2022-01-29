alias Statechart.Node
alias Statechart.Definition

defprotocol Statechart.Insertable do
  @spec nodes(t) :: [Node.maybe_not_inserted()]
  def nodes(insertable)
end

defimpl Statechart.Insertable, for: Node do
  @spec nodes(Node.not_inserted()) :: [Node.not_inserted()]
  def nodes(node), do: [node]
end

defimpl Statechart.Insertable, for: Definition do
  @spec nodes(Definition.t()) :: [Node.t()]
  defdelegate nodes(definition), to: Definition
end

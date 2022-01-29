defprotocol Statechart.Insertable do
  alias Statechart.Node

  #####################################
  # TYPES

  @spec nodes(t) :: [Node.t()]
  def nodes(insertable)
end

defimpl Statechart.Insertable, for: Statechart.Node do
  def nodes(node), do: [node]
end

defimpl Statechart.Insertable, for: Statechart.Definition do
  defdelegate nodes(definition), to: Statechart.Definition
end

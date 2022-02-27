alias Statechart.Transitions.State

defprotocol State do
  # alias Statechart.State, as: StatechartState
  @spec parse(t) :: {:ok, should_be_state :: any, should_be_context :: any} | :error
  def parse(state)
end

defimpl State, for: Map do
  def parse(%{state: state, context: context}), do: {:ok, state, context}
  def parse(_), do: :error
end

defimpl State, for: Tuple do
  def parse({state, context}), do: {:ok, state, context}
  def parse(_), do: :error
end

defimpl State, for: [Atom, Integer] do
  alias Statechart.NoContext
  alias Statechart.Node
  @spec parse(Node.name()) :: {:ok, Node.name(), NoContext.t()}
  @spec parse(Node.id()) :: {:ok, Node.id(), NoContext.t()}
  def parse(state), do: {:ok, state, %NoContext{}}
end

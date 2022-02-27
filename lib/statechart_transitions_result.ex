defmodule Statechart.Transitions.Result do
  use Statechart.Util.GetterStruct
  alias Statechart.Context
  alias Statechart.NoContext
  alias Statechart.Node

  getter_struct do
    field :state_id, Node.id()
    field :state_name, Node.name()
    field :context, Context.t()
  end

  @spec new(Node.t(), Context.t() | NoContext.t()) :: t
  def new(destination_node, context \\ NoContext.new()),
    do: %__MODULE__{
      state_id: Node.id(destination_node),
      state_name: Node.name(destination_node),
      context: context
    }
end

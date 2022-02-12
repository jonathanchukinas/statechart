defmodule Statechart.Transition do
  use Statechart.Util.GetterStruct
  alias __MODULE__
  alias Statechart.Node
  alias Statechart.Event

  getter_struct do
    field :event, Event.t()
    field :destination_node_id, Node.id()
  end

  #####################################
  # CONSTRUCTORS

  def new(event, destination_node_id) do
    %__MODULE__{event: event, destination_node_id: destination_node_id}
  end

  #####################################
  # IMPLEMENTATIONS

  defimpl Inspect do
    def inspect(%Transition{event: event, destination_node_id: destination_node_id}, _opts) do
      "#Transition<#{event} >>> #{destination_node_id}>"
    end
  end
end

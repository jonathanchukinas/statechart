defmodule Statechart.Transition do
  use Statechart.Util.GetterStruct
  alias __MODULE__
  alias Statechart.Node
  alias Statechart.Event
  alias Statechart.Metadata

  getter_struct do
    field :event, Event.t()
    field :destination_node_id, Node.id()
    field :metadata, Metadata.t()
  end

  #####################################
  # CONSTRUCTORS

  def new(event, destination_node_id, metadata) do
    %__MODULE__{event: event, destination_node_id: destination_node_id, metadata: metadata}
  end

  #####################################
  # IMPLEMENTATIONS

  defimpl Inspect do
    def inspect(%Transition{event: event, destination_node_id: destination_node_id}, _opts) do
      "#Transition<#{event} >>> #{destination_node_id}>"
    end
  end
end

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

  defimpl Statechart.HasIdRefs do
    def incr_id_refs(%Transition{destination_node_id: id} = transition, start_id, addend) do
      if start_id <= id do
        Map.update!(transition, :destination_node_id, &(&1 + addend))
      else
        transition
      end
    end
  end
end

defmodule Statechart.Transition do
  use Statechart.Util.GetterStruct
  alias __MODULE__
  alias Statechart.Node
  alias Statechart.Event
  alias Statechart.Metadata

  getter_struct do
    field :event, Event.t()
    field :target_id, Node.id()
    field :metadata, Metadata.t()
  end

  #####################################
  # CONSTRUCTORS

  def new(event, target_id, metadata) do
    %__MODULE__{event: event, target_id: target_id, metadata: metadata}
  end

  #####################################
  # IMPLEMENTATIONS

  defimpl Inspect do
    def inspect(%Transition{event: event, target_id: target_id}, _opts) do
      "#Transition<#{event}-#{target_id}>"
    end
  end

  defimpl Statechart.Metadata.HasMetadata do
    def fetch(%Transition{metadata: metadata}) do
      case metadata do
        %Metadata{} -> {:ok, metadata}
        _ -> {:error, :missing_metadata}
      end
    end
  end

  defimpl Statechart.HasIdRefs do
    def incr_id_refs(%Transition{target_id: id} = transition, start_id, addend) do
      if start_id <= id do
        Map.update!(transition, :target_id, &(&1 + addend))
      else
        transition
      end
    end
  end
end

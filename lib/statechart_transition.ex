defmodule Statechart.Transition do
  use Statechart.Util.GetterStruct
  alias __MODULE__
  alias Statechart.HasIdRefs
  alias Statechart.Node
  alias Statechart.Event
  alias Statechart.Metadata
  alias Statechart.Metadata.HasMetadata

  getter_struct do
    field :event, Event.registation()
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
      "#Transition<#{Event.pretty(event)}-#{target_id}>"
    end
  end

  defimpl HasMetadata do
    def fetch(%Transition{metadata: metadata}) do
      case metadata do
        %Metadata{} -> {:ok, metadata}
        _ -> {:error, :missing_metadata}
      end
    end
  end

  defimpl HasIdRefs do
    def incr_id_refs(%Transition{target_id: id} = transition, start_id, addend) do
      # TODO update to call update_id_refs/2
      if start_id <= id do
        Map.update!(transition, :target_id, &(&1 + addend))
      else
        transition
      end
    end

    def update_id_refs(%Transition{target_id: id} = transition, fun) do
      %Transition{transition | target_id: fun.(id)}
    end
  end
end

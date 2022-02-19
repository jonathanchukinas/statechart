alias Statechart.Event.IsEvent

defprotocol IsEvent do
  @moduledoc """
  Events passed to `Statechart.Transitions` functions must implement this protocol.
  """

  @fallback_to_any true

  @spec event?(any) :: boolean
  def event?(maybe_event)
end

defimpl IsEvent, for: Atom do
  def event?(_atom), do: true
end

defimpl IsEvent, for: Any do
  def event?(_any), do: false
end

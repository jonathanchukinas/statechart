defmodule Statechart.Event do
  @type t :: atom

  def validate(event) when is_atom(event), do: :ok
  def validate(_event), do: {:error, :invalid_event}

  #####################################
  # CONVERTERS

  @spec match?(t, t) :: boolean
  def match?(event1, event2) do
    event1 == event2
  end
end

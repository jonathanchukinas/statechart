defmodule Statechart.Event do
  @type t :: atom

  # TODO need a type for the thing that you use when building a Chart (simple atom or module name)
  # Then I also need a type for the thing that gets sent to Transitions.transition/3/4
  #
  @spec validate(t) :: :ok | {:error, :invalid_event}
  def validate(event) when is_atom(event), do: :ok
  def validate(_event), do: {:error, :invalid_event}

  #####################################
  # CONVERTERS

  @spec match?(t, t) :: boolean
  def match?(event1, event2) do
    event1 == event2
  end
end

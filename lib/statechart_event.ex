defmodule Statechart.Event do
  @type t :: atom

  # CONSIDER does this belong here or in Statechart.Build?
  @typedoc """
  Valid value for registering transitions via `Statechart.Build.>>>/2`

  We recommend following a statechart convention and using uppercase for simple
  atom events, example: `:MY_EVENT`.

  Alternatively, you can use a module name.
  This module must define a struct that implements the `Statechart.Event` protocol.
  Normally, this is done via `use Statechart.Event`.
  """
  @type registration :: atom | module

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

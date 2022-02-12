defmodule Statechart.State do
  alias Statechart.Node

  @type as_atom :: atom

  @typedoc """
  Describes the current state.

  Being a valid type isn't necessarilly good enough by itself, of course.
  State is always subject to validation by the `Statechart.Transitions` module.
  """
  @type t :: as_atom | Node.id()
end

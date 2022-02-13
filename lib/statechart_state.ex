defmodule Statechart.State do
  alias Statechart.Node

  @typedoc """
  Describes the current state.

  Being a valid type isn't necessarilly good enough by itself, of course.
  State is always subject to validation by the `Statechart.Transitions` module.
  """
  @type t :: Node.name() | Node.id()
end

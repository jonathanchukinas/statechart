defmodule Statechart.State do
  alias Statechart.Node

  @type as_atom :: atom
  @type t :: as_atom | Node.id()
end

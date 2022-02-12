defmodule Statechart.Event do
  @type t :: atom

  # TODO build this out
  def validate(event) when is_atom(event), do: :ok
end

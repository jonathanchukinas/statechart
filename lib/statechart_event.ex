defmodule Statechart.Event do
  @type t :: atom

  def validate(event) when is_atom(event), do: :ok
  def validate(_event), do: {:error, :invalid_event}
end

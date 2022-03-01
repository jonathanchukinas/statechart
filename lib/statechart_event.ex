defmodule Statechart.Event do
  @moduledoc """
  Functions for working with Events.
  """

  alias Statechart.Event.IsEvent

  @type t :: IsEvent.t()

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

  @spec validate(registration) :: :ok | {:error, :invalid_event}
  def validate(event) when is_atom(event), do: :ok
  def validate(_event), do: {:error, :invalid_event}

  #####################################
  # CONVERTERS

  @spec match?(t, t) :: boolean
  def match?(event1, event2) do
    event1 == event2
  end

  @spec pretty(registration) :: String.t()
  def pretty(event) do
    IO.inspect(event)

    try do
      event
      |> Module.split()
      |> Enum.at(-1)
    rescue
      _ -> to_string(event)
    end
  end
end

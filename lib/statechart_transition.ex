defmodule Statechart.Transition do
  @moduledoc """
  Stateless functions for transitioning from one state to another.
  See `Statechart.Interpreter` for a stateful way of doing this.
  In fact, `Statechart.Interpreter` just holds state and delegates out to this module.
  """

  alias Statechart.Event
  alias Statechart.State
  alias Statechart.Definition

  @spec transition({State.t(), context}, Definition.t(context), Event.t()) ::
          {State.t(), context}
        when context: any
  def transition({state, context}, _definition, _event) do
    {state, context}
  end

  @spec transition(State.t(), Definition.t(), Event.t()) :: State.t()
  def transition(state, _definition, _event) do
    state
  end
end

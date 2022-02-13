defmodule Statechart.Transitions do
  @moduledoc """
  Stateless functions for transitioning from one state to another.
  See `Statechart.Interpreter` for a stateful way of doing this.
  In fact, `Statechart.Interpreter` just holds state and delegates out to this module.
  """

  use Statechart.Definition
  alias Statechart.Event
  alias Statechart.State
  alias Statechart.Transition

  #####################################
  # API

  # TODO rename handle_event
  # @spec transition({State.t(), context}, Definition.t(context), Event.t()) ::
  @spec transition({State.t(), context}, Definition.t(), Event.t()) ::
          {State.t(), context}
        when context: any
  def transition({state, context}, _definition, _event) do
    {state, context}
  end

  @spec transition(State.t(), Definition.t(), Event.t()) :: State.t()
  def transition(state, _definition, _event) do
    state
  end

  #####################################
  # HELPERS

  @type path_item :: {:up | :down, Node.t()}
  @spec fetch_transition_path(Definition.t(), State.t(), Event.t()) ::
          {:ok, [path_item]} | {:error, atom}
  def fetch_transition_path(definition, state, event) do
    with {:ok, node_id} <- fetch_node_id_by_state(definition, state),
         {:ok, transition} <- fetch_transition(definition, node_id, event),
         destination_node_id = Transition.destination_node_id(transition),
         {:ok, state_path} <- fetch_path_by_id(definition, node_id),
         {:ok, destination_path} <- fetch_path_by_id(definition, destination_node_id) do
      {:ok, do_transition_path(state_path, destination_path)}
    end
  end

  defp do_transition_path([head1, head2 | state_tail], [head1, head2 | destination_tail]) do
    do_transition_path([head2 | state_tail], [head2 | destination_tail])
  end

  defp do_transition_path([head1 | state_tail], [head1 | destination_tail]) do
    state_path_items = Stream.map(state_tail, &{:exit, &1})
    destination_path_items = Enum.map(destination_tail, &{:enter, &1})
    Enum.reduce(state_path_items, destination_path_items, &[&1 | &2])
  end
end

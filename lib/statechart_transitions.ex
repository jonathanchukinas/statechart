defmodule Statechart.Transitions do
  @moduledoc """
  Stateless functions for transitioning from one state to another.
  See `Statechart.Interpreter` for a stateful way of doing this.
  In fact, `Statechart.Interpreter` just holds state and delegates out to this module.
  """

  use Statechart.Chart
  alias Statechart.Chart
  alias Statechart.Event
  alias Statechart.State
  alias Statechart.Transition

  @typedoc """
  To travel from one node to another, you have to travel up the origin node's path
  and then down the target node's path. This type describes that path.
  You rarely ever go all the way up to the root node. Instead, you travel up to where
  the two paths meet.

  This is important for handling the exit/enter actions for each node along this path.

  CONSIDER: come up with a better term for it? One that doesn't use the word `path`?
  """
  @type transition_path :: [{:exit | :enter, Node.t()}]

  #####################################
  # API

  # @spec transition({State.t(), context}, Chart.t(context), Event.t()) ::
  # @spec transition({State.t(), context}, Chart.t(), Event.t()) ::
  #         {State.t(), context}
  #       when context: any
  # def transition({state, context}, _definition, _event) do
  #   {state, context}
  # end

  # TODO why don't these obviously wrong error messages not throw dialyzer warnings?
  @spec transition(Chart.spec(), State.t(), Event.t()) ::
          {:ok, State.t()} | {:error, :something | :something_else}
  def transition(chart_spec, state, event) do
    with {:ok, chart} <- Chart.fetch(chart_spec),
         {:ok, origin_id} <- fetch_id_by_state(chart, state),
         {:ok, target_id} <- fetch_target_id(chart, origin_id, event),
         {:ok, target_node} <- fetch_node_by_id(chart, target_id) do
      {:ok, Node.name(target_node)}
    end
  end

  #####################################
  # HELPERS

  defp fetch_target_id(chart, origin_id, event) do
    with {:ok, transition} <- fetch_transition(chart, origin_id, event),
         target_id = Transition.target_id(transition) do
      {:ok, target_id}
    end
  end

  @spec fetch_transition_path(Chart.t(), State.t(), Event.t()) ::
          {:ok, transition_path} | {:error, atom}
  def fetch_transition_path(chart, state, event) do
    with {:ok, origin_id} <- fetch_id_by_state(chart, state),
         {:ok, target_id} <- fetch_target_id(chart, origin_id, event),
         {:ok, current_path} <- fetch_path_by_id(chart, origin_id),
         {:ok, destination_path} <- fetch_path_by_id(chart, target_id) do
      {:ok, do_transition_path(current_path, destination_path)}
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

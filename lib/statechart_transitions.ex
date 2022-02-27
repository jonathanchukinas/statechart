defmodule Statechart.Transitions do
  @moduledoc """
  Stateless functions for transitioning from one state to another.
  See `Statechart.Interpreter` for a stateful way of doing this.
  In fact, `Statechart.Interpreter` just holds state and delegates out to this module.
  """

  use Statechart.Chart
  alias Statechart.Chart
  alias Statechart.Event
  alias Statechart.NoContext
  alias Statechart.State
  alias Statechart.Transition
  alias Statechart.Transitions.Result
  # alias Statechart.Transitions.State, as: TransitionsState

  #####################################
  # API

  # @spec transition(TransitionState.t(), Event.t()) :: {:ok, State.t()} | {:error, atom}
  # def transition(transition_state, event) do
  #   with {:ok, {chart_spec, state_spec, context}} <- fetch_as_tuple(transition_state),
  #        {:ok, result} <- transition(chart_spec, state_spec, context, event),
  #        {:ok, new_transition_state} <- TransitionState.put_result(result) do
  #     {:ok, new_transition_state}
  #   else
  #     {:error, reason} -> {:error, reason}
  #   end
  # end

  # TODO add a test
  # TODO Event.t or something else?
  @spec transition(Chart.spec(), State.name(), Event.t()) :: {:ok, State.name()} | {:error, atom}
  # TODO replace is_atom with
  def transition(chart_spec, state_name, event) when is_atom(state_name) do
    with {:ok, %Result{state_name: state_name}} <-
           transition(chart_spec, state_name, NoContext.new(), event) do
      {:ok, state_name}
    end
  end

  # TODO add a test
  @spec transition(Chart.spec(), State.t(), Context.t(), Event.t()) ::
          {:ok, Result.t()} | {:error, atom}
  def transition(chart_spec, state, context, event) do
    with {:ok, chart} <- Chart.fetch(chart_spec),
         {:ok, origin_id} <- fetch_id_by_state(chart, state, search_subcharts: true),
         {:ok, target_id} <- fetch_target_id(chart, origin_id, event),
         {:ok, target_node} <- fetch_node_by_id(chart, target_id),
         {:ok, destination_node} <- fetch_default_leaf_node(chart, target_node),
         destination_id = Node.id(destination_node),
         {:ok, actions} <- fetch_actions(chart, origin_id, destination_id) do
      context =
        Enum.reduce(actions, context, fn action, context ->
          action.(context)
        end)

      {:ok, Result.new(destination_node, context)}
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

  # defp fetch_as_tuple(transition_state) do
  #  case TransitionState.fetch_as_tuple(transition_state) do
  #    {:ok, {_chart_spec, _state_spec, _context}} = result -> result
  #    {:ok, {chart_spec, state_spec}} -> {:ok, {chart_spec, state_spec, NoContext.new()}}
  #    {:error, reason} -> {:error, reason}
  #  end
  # end
end

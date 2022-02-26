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
    context = nil

    with {:ok, chart} <- Chart.fetch(chart_spec),
         {:ok, origin_id} <- fetch_id_by_state(chart, state),
         {:ok, target_id} <- fetch_target_id(chart, origin_id, event),
         {:ok, target_node} <- fetch_node_by_id(chart, target_id),
         {:ok, destination_node} <- fetch_default_leaf_node(chart, target_node),
         destination_id = Node.id(destination_node),
         {:ok, actions} <- fetch_actions(chart, origin_id, destination_id) do
      _context =
        Enum.reduce(actions, context, fn action, context ->
          action.(context)
        end)

      {:ok, Node.name(destination_node)}
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

end

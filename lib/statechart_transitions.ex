defmodule Statechart.Transitions do
  @moduledoc """
  Stateless functions for transitioning from one state to another.
  See `Statechart.Interpreter` for a stateful way of doing this.
  In fact, `Statechart.Interpreter` just holds state and delegates out to this module.
  """

  use Statechart.Definition
  alias Statechart.Definition, as: Chart
  alias Statechart.Event
  alias Statechart.State
  alias Statechart.Transition

  @type path_item :: {:up | :down, Node.t()}

  @type chart_or_module :: Chart.t() | module

  #####################################
  # API

  # @spec transition({State.t(), context}, Definition.t(context), Event.t()) ::
  # @spec transition({State.t(), context}, Definition.t(), Event.t()) ::
  #         {State.t(), context}
  #       when context: any
  # def transition({state, context}, _definition, _event) do
  #   {state, context}
  # end

  # TODO test on_exit and on_enter actions
  # TODO test for event not in current path

  @spec transition(Definition.t(), State.t(), Event.t()) :: State.t()
  def transition(chart_or_module, state, event) do
    with {:ok, chart} <- fetch_chart(chart_or_module),
         {:ok, current_id} <- fetch_node_id_by_state(chart, state),
         {:ok, target_id} <- fetch_target_id(chart, current_id, event),
         {:ok, target_node} <- fetch_node_by_id(chart, target_id) do
      {:ok, Node.name(target_node)}
    end
  end

  #####################################
  # HELPERS

  # TODO clarify terms somewhere
  # Event can mean either the spec given to a chart or
  # it can mean the actual atom or Event struct incoming that drives a state change
  # a Transition is a combo of Event and target id
  #
  # TODO on Transition, rename target_id
  defp fetch_target_id(chart, current_id, event) do
    with {:ok, transition} <- fetch_transition(chart, current_id, event),
         # TODO rename this to Transition.target_id/1
         target_id = Transition.destination_node_id(transition) do
      {:ok, target_id}
    end
  end

  # TODO clarify terms:
  #   target_id is the one given by the event transition
  #   destination_id is the ultimate destination after branch nodes follow their default path down to a leaf node
  # TODO this should be broken up. Some functionality moves out to fetch_target_id
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

  # TODO move to Statechart.Chart?
  defp fetch_chart(%Chart{} = chart), do: {:ok, chart}
  defp fetch_chart(module) when is_atom(module), do: Chart.fetch_from_module(module)
  defp fetch_chart(_), do: {:error, :definition_not_found}
end

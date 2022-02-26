defmodule Statechart.Interpreter do
  @moduledoc """
  Provides a persistent interpreter for statecharts defined in a Chart module.
  """

  # use Statechart.Util.GetterStruct
  use TypedStruct
  alias Statechart.Chart

  #####################################
  # TYPES

  typedstruct enforce: true do
    field :chart_module, module
    field :context, any, default: nil
  end

  #####################################
  # CONSTRUCTORS

  @doc """
  Returns a t:__MODULE__.t/0 struct that acts as a persistent statechart.
  """
  @spec new(module, any) :: t
  def new(chart_module, context \\ nil) when is_atom(chart_module) do
    with true <- {:chart, 0} in chart_module.__info__(:functions),
         %Chart{} <- chart_from_module(chart_module) do
      %__MODULE__{chart_module: chart_module, context: context}
    else
      _ ->
        raise "expected chart_module to be a module that defines a statechart " <>
                "via Statechart.defchart/2, " <>
                "got: #{inspect(chart_module)}"
    end
  end

  #####################################
  # CONVERTERS

  def chart(%__MODULE__{chart_module: module}) do
    chart_from_module(module)
  end

  #####################################
  # HELPERS

  defp chart_from_module(module) do
    module.chart()
  end
end

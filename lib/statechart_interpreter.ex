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
    field :definition, module
    field :context, any, default: nil
  end

  #####################################
  # CONSTRUCTORS

  @doc """
  Returns a t:__MODULE__.t/0 struct that acts as a persistent statechart.
  """
  @spec new(module, any) :: t
  def new(definition_module, context \\ nil) when is_atom(definition_module) do
    with true <- {:definition, 0} in definition_module.__info__(:functions),
         %Chart{} <- definition_from_module(definition_module) do
      %__MODULE__{definition: definition_module, context: context}
    else
      _ ->
        raise "expected definition_module to be a module whose definition/0 " <>
                "function returns a Statechart.Chart struct, " <>
                "got: #{inspect(definition_module)}"
    end
  end

  #####################################
  # CONVERTERS

  def definition(%__MODULE__{definition: module}) do
    definition_from_module(module)
  end

  #####################################
  # HELPERS

  defp definition_from_module(module) do
    module.definition()
  end
end

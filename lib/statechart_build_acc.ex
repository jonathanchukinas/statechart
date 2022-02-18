defmodule Statechart.Build.Acc do
  @doc false
  use TypedStruct
  alias Statechart.Chart
  alias Statechart.Node
  alias Statechart.Tree
  @attr :__sc_acc__

  typedstruct enforce: true do
    field :statechart_def, Chart.t()
    field :current_node_id, Node.id()
  end

  # CONSTRUCTORS

  def put_new(env, statechart_def) do
    acc = %__MODULE__{
      statechart_def: statechart_def,
      current_node_id: Tree.max_node_id(statechart_def)
    }

    put_attribute(env, acc)
  end

  # REDUCERS

  def put_statechart_def(env, statechart_def) do
    acc = %__MODULE__{get_attribute(env) | statechart_def: statechart_def}
    put_attribute(env, acc)
  end

  def put_current_id(env, id) do
    acc = %__MODULE__{get_attribute(env) | current_node_id: id}
    put_attribute(env, acc)
  end

  # CONVERTERS

  @spec statechart_def(Macro.Env.t()) :: Chart.t()
  def statechart_def(%Macro.Env{module: module}) do
    module
    |> Module.get_attribute(@attr)
    |> Map.fetch!(:statechart_def)
  end

  @spec current_id(Macro.Env.t()) :: Node.id()
  def current_id(%Macro.Env{module: module}) do
    module
    |> Module.get_attribute(@attr)
    |> Map.fetch!(:current_node_id)
  end

  defp put_attribute(%Macro.Env{module: module} = env, acc) do
    Module.put_attribute(module, @attr, acc)
    env
  end

  # HELPERS

  def delete_attribute(%Macro.Env{module: module}) do
    Module.delete_attribute(module, @attr)
  end

  def get_attribute(%Macro.Env{module: module}), do: Module.get_attribute(module, @attr)
end

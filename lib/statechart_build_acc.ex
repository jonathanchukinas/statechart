defmodule Statechart.Build.Acc do
  use TypedStruct
  alias Statechart.Definition
  alias Statechart.Node
  alias Statechart.Tree
  @attr :__sc_acc__

  typedstruct enforce: true do
    field :statechart_def, Definition.t()
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

  # TODO which of these can be private?

  def put_current_id(env, id) do
    acc = %__MODULE__{get_attribute(env) | current_node_id: id}
    put_attribute(env, acc)
  end

  # CONVERTERS

  # TODO move this to another file?

  @spec statechart_def(Macro.Env.t()) :: Definition.t()
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

  def put_attribute(%Macro.Env{module: module} = env, acc) do
    Module.put_attribute(module, @attr, acc)
    env
  end

  # HELPERS

  def register_attribute(%Macro.Env{module: module}) do
    Module.register_attribute(module, @attr, [])
  end

  def delete_attribute(%Macro.Env{module: module}) do
    Module.delete_attribute(module, @attr)
  end

  defp get_attribute(%Macro.Env{module: module}), do: Module.get_attribute(module, @attr)
end
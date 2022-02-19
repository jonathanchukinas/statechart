defmodule Statechart.Build.Acc do
  @doc false
  use TypedStruct
  alias Statechart.Chart
  alias Statechart.Node
  alias Statechart.Tree
  @attr :__sc_acc__

  typedstruct enforce: true do
    field :statechart_def, Chart.t()
    field :path_ids, [Node.id()]
  end

  # CONSTRUCTORS

  def put_new(env, statechart_def) do
    acc = %__MODULE__{
      statechart_def: statechart_def,
      path_ids: [Tree.max_node_id(statechart_def)]
    }

    put_attribute(env, acc)
  end

  # REDUCERS

  def put_chart(env, statechart_def) do
    acc = %__MODULE__{get_attribute(env) | statechart_def: statechart_def}
    put_attribute(env, acc)
  end

  def push_current_id(env, id) do
    acc =
      env
      |> get_attribute
      |> Map.update!(:path_ids, &[id | &1])

    put_attribute(env, acc)
  end

  # CONVERTERS

  @spec statechart_def(Macro.Env.t()) :: Chart.t()
  def statechart_def(%Macro.Env{module: module}) do
    module
    |> Module.get_attribute(@attr)
    |> Map.fetch!(:statechart_def)
  end

  # TODO delete?
  @spec pop_id!(Macro.Env.t()) :: Node.id()
  def pop_id!(%Macro.Env{module: module} = env) do
    %__MODULE__{path_ids: ids} = acc = Module.get_attribute(module, @attr)

    case ids do
      [] ->
        raise "whoopsie! expected there to still be at least one id in path_ids"

      [current_id | tail] ->
        new_acc = %__MODULE__{acc | path_ids: tail}
        put_attribute(env, new_acc)
        current_id
    end
  end

  # TODO delete?
  @spec current_id(Macro.Env.t()) :: Node.id()
  def current_id(%Macro.Env{module: module}) do
    [current_id | _tail] =
      module
      |> Module.get_attribute(@attr)
      |> Map.fetch!(:path_ids)

    current_id
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

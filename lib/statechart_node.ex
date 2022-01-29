defmodule Statechart.Node do
  use Statechart.Util.GetterStruct

  @type id :: pos_integer
  @type lft_or_rgt :: non_neg_integer

  # TODO this doesn't belong here.
  @type fetch_spec ::
          {:lft, lft_or_rgt()}
          | {:id, id()}
          | {:name, atom}
  @type node_or_fetch_spec :: t | fetch_spec

  getter_struct enforce: false do
    field :id, id
    field :name, atom, enforce: true
    field :lft, lft_or_rgt, default: 0
    field :rgt, lft_or_rgt, default: 1
  end

  #####################################
  # CONSTRUCTORS

  def root() do
    %__MODULE__{id: 1, name: :root}
  end

  def new(name) when is_atom(name), do: %__MODULE__{name: name}

  #####################################
  # REDUCERS

  def add_to_lft(%__MODULE__{lft: lft} = node, addend) do
    %__MODULE__{node | lft: lft + addend}
  end

  def add_to_rgt(%__MODULE__{rgt: rgt} = node, addend) do
    %__MODULE__{node | rgt: rgt + addend}
  end

  def add_to_lft_rgt(%__MODULE__{lft: lft, rgt: rgt} = node, addend) do
    %__MODULE__{node | lft: lft + addend, rgt: rgt + addend}
  end

  def set_id(node, id) do
    %__MODULE__{node | id: id}
  end

  #####################################
  # CONVERTERS

  @spec match?(t, fetch_spec) :: boolean
  def match?(node, fetch_spec)
  def match?(%__MODULE__{id: value}, {:id, value}), do: true
  def match?(%__MODULE__{name: value}, {:name, value}), do: true
  def match?(%__MODULE__{lft: value}, {:lft, value}), do: true
  def match?(_, _), do: false

  @spec lft_rgt(t) :: {integer, integer}
  def lft_rgt(%__MODULE__{lft: lft, rgt: rgt}), do: {lft, rgt}

  #####################################
  # IMPLEMENTATIONS

  defimpl Inspect do
    alias Statechart.Node

    def inspect(%Node{name: :root} = node, opts) do
      fields = [
        id: node.id,
        lft_rgt: {node.lft, node.rgt}
      ]

      Statechart.Util.Inspect.custom_kv("Root", fields, opts)
    end

    def inspect(node, opts) do
      fields = [
        id: node.id,
        lft_rgt: {node.lft, node.rgt},
        name: node.name
      ]

      Statechart.Util.Inspect.custom_kv("Node", fields, opts)
    end
  end
end

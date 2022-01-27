defmodule Statechart.Node do
  use Statechart.Util.GetterStruct

  @type id :: pos_integer
  @type lft_or_rgt :: non_neg_integer
  @type fetch_spec ::
          {:lft, lft_or_rgt()}
          | {:id, id()}
          | {:name, atom}
  @type node_or_fetch_spec :: t | fetch_spec

  getter_struct enforce: false do
    field(:id, id)
    field(:name, atom, enforce: true)
    field(:lft, lft_or_rgt)

    field(:rgt, lft_or_rgt)
  end

  #####################################
  # CONSTRUCTORS

  def root() do
    %__MODULE__{
      id: 1,
      name: :root,
      lft: 0,
      rgt: 1
    }
  end

  def new(name) when is_atom(name), do: %__MODULE__{name: name}

  #####################################
  # REDUCERS

  @doc """
  Used when inserted other nodes into a tree.

  Should only be used by `Statechart`
  """
  def maybe_update_position(%__MODULE__{} = node, min_value, addend) do
    Enum.reduce([:lft, :rgt], node, fn key, node ->
      if Map.fetch!(node, key) >= min_value do
        Map.update!(node, key, &(&1 + addend))
      else
        node
      end
    end)
  end

  #####################################
  # CONVERTERS

  # TODO remove?
  def in_path?(
        %__MODULE__{lft: lft, rgt: rgt} = _maybe_ancestor_node,
        %__MODULE__{lft: desc_lft, rgt: desc_rgt} = _descendent_node
      )
      when (lft < desc_lft and desc_rgt < rgt) or
             (lft == desc_lft and desc_rgt == rgt),
      do: true

  def in_path?(_non_ancestor_node, _descendent_node), do: false

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

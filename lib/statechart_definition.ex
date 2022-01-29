defmodule Statechart.Definition do
  use Statechart.Util.GetterStruct
  alias Statechart.Node
  alias Statechart.Insertable

  #####################################
  # TYPES

  getter_struct do
    field(:nodes, [Node.t()], default: [])
  end

  #####################################
  # CONSTRUCTORS

  def new do
    %__MODULE__{nodes: [Node.root()]}
  end

  #####################################
  # REDUCERS

  # TODO this needs a boundary, which checks for:
  #   unique names
  #   existing parent_id
  #   insertable needs to valid
  #     node: lft = 0, rgt  = 1
  #     id: 0?
  @spec insert!(t, Insertable.t(), Node.id()) :: t
  def insert!(%__MODULE__{} = tree, insertable, parent_id) do
    new_nodes = Insertable.nodes(insertable)
    parent_rgt = tree |> fetch_node_by_id!(parent_id) |> Node.rgt()
    starting_new_id = 1 + max_node_id(tree)

    old_nodes_addend = 2 * length(new_nodes)
    new_nodes_addend = parent_rgt

    maybe_update_old_node = fn %Node{} = node, key ->
      Node.update_if(node, key, &(&1 >= parent_rgt), &(&1 + old_nodes_addend))
    end

    prepared_old_nodes =
      tree
      |> nodes
      |> Stream.map(&maybe_update_old_node.(&1, :lft))
      |> Stream.map(&maybe_update_old_node.(&1, :rgt))

    prepared_new_nodes =
      new_nodes
      |> Stream.map(&Node.add_to_lft_rgt(&1, new_nodes_addend))
      |> Enum.with_index(fn node, index -> Node.set_id(node, index + starting_new_id) end)

    nodes =
      [prepared_old_nodes, prepared_new_nodes]
      |> Stream.concat()
      |> Enum.sort_by(&Node.lft/1)

    %__MODULE__{tree | nodes: nodes}
  end

  #####################################
  # CONVERTERS

  # TODO rename to get_path_of?
  @spec get_path(t, Node.t() | Node.fetch_spec(), (Node.t() -> term)) :: [term]
  def get_path(tree, node, mapper \\ fn node -> node end)

  def get_path(%__MODULE__{} = tree, %Node{} = node, mapper) do
    tree
    |> nodes
    |> Stream.take_while(fn %Node{lft: lft} -> lft <= node.lft end)
    |> Stream.filter(fn %Node{rgt: rgt} -> node.rgt <= rgt end)
    |> Enum.map(mapper)
  end

  def fetch_parent_of!(tree, %Node{} = node) do
    tree
    |> get_path(node)
    |> Stream.reject(fn %Node{lft: lft} -> lft == node.lft end)
    |> Enum.at(-1)
  end

  def fetch_parent_of!(tree, fetch_spec) do
    {:ok, node} = fetch(tree, fetch_spec)
    fetch_parent_of!(tree, node)
  end

  def fetch_node_by_id!(tree, id) do
    {:ok, node} = fetch(tree, {:id, id})
    node
  end

  def fetch(%__MODULE__{nodes: nodes}, fetch_spec) do
    case Enum.find(nodes, &Node.match?(&1, fetch_spec)) do
      nil -> :error
      %Node{} = node -> {:ok, node}
    end
  end

  # TODO replaced by nodes/2
  def map_nodes(tree, mapper) do
    tree |> nodes |> Enum.map(mapper)
  end

  def nodes(tree, opts) do
    nodes = nodes(tree)

    case opts[:mapper] do
      nil -> nodes
      mapper -> Enum.map(nodes, mapper)
    end
  end

  def root(tree) do
    tree |> nodes |> hd
  end

  def node_count(tree) do
    {lft, rgt} = tree |> root() |> Node.lft_rgt()
    (rgt + 1 - lft) / 2
  end

  def max_node_id(tree), do: tree |> nodes(mapper: &Node.id/1) |> Enum.max()

  #####################################
  # IMPLEMENTATIONS

  # defimpl Inspect do
  #   def inspect(tree, opts) do
  #     Util.Inspect.custom_kv("Statechart", tree.nodes, opts)
  #   end
  # end
end

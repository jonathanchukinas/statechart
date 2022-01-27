defmodule Statechart.Definition do
  use Statechart.Util.GetterStruct
  alias Statechart.Node

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

  @spec add_child(t, Node.t(), integer | Node.fetch_spec()) :: t
  def add_child(%__MODULE__{} = tree, %Node{} = node, parent_id) when is_integer(parent_id) do
    add_child(tree, node, {:id, parent_id})
  end

  # TODO maybe don't use this. Maybe there's a separate module that acts as a boundary that absords the uncertainty
  def add_child(%__MODULE__{} = tree, %Node{} = node, parent_spec) do
    if node.name in Enum.map(tree.nodes, &Node.name/1) do
      raise "node names must be unique!"
    end

    case fetch(tree, parent_spec) do
      :error ->
        raise "Parent spec #{inspect(parent_spec)} has no match in #{inspect(tree)}"

      {:ok, %Node{rgt: parent_rgt} = parent} ->
        inserted_node_count = 1
        addend = 2 * inserted_node_count
        min_value = parent.rgt
        nodes = Enum.map(tree.nodes, &Node.maybe_update_position(&1, min_value, addend))

        new_child =
          struct!(node,
            lft: parent_rgt,
            rgt: parent_rgt + 1,
            id: max_node_id(tree) + 1
          )

        nodes = Enum.sort_by([new_child | nodes], &Node.lft/1)
        %__MODULE__{tree | nodes: nodes}
    end
  end

  #####################################
  # CONVERTERS

  # TODO rename to get_path_of?
  @spec get_path(t, Node.t() | Node.fetch_spec(), (Node.t() -> term)) :: [term]
  def get_path(tree, node, mapper \\ fn node -> node end)

  def get_path(tree, %Node{} = node, mapper) do
    tree
    |> nodes
    |> Stream.take_while(fn %Node{lft: lft} -> lft <= node.lft end)
    |> Stream.filter(fn %Node{rgt: rgt} -> node.rgt <= rgt end)
    |> Enum.map(mapper)
  end

  def get_path(tree, fetch_spec, mapper) do
    node = fetch(tree, fetch_spec)
    get_path(tree, node, mapper)
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

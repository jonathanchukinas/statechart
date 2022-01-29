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
  # TODO there should be a "fetch" version of this that returns an ok tuple
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

  def contains_id?(statechart_def, id), do: id in 1..max_node_id(statechart_def)

  @spec fetch_ancestors_by_id(t, Node.id()) :: {:ok, [Node.t()]} | {:error, atom}
  def fetch_ancestors_by_id(statechart_def, parent_id) do
    statechart_def
    |> stream_nodes_starting_at_node_id(parent_id)
    |> Enum.to_list()
    |> case do
      [] ->
        error_id_not_found()

      [%Node{} = parent | rest] ->
        rgt = Node.rgt(parent)
        ancestors = Enum.take_while(rest, fn node -> Node.rgt(node) < rgt end)
        {:ok, ancestors}
    end
  end

  @spec fetch_children_by_id(t, Node.id()) :: {:ok, [Node.t()]} | {:error, atom}
  def fetch_children_by_id(statechart_def, parent_id) do
    case fetch_ancestors_by_id(statechart_def, parent_id) do
      {:ok, [first_child | _rest] = ancestors} ->
        {_next_lft, children} =
          Enum.reduce(
            ancestors,
            {Node.lft(first_child), []},
            fn ancestor, {next_lft, children} = acc ->
              if Node.lft(ancestor) == next_lft do
                {Node.rgt(ancestor) + 1, [ancestor | children]}
              else
                acc
              end
            end
          )

        {:ok, children}

      ancestor_result ->
        ancestor_result
    end
  end

  @spec fetch_children_by_id!(t, Node.id()) :: [Node.t()]
  def fetch_children_by_id!(statechart_def, parent_id) do
    case fetch_children_by_id(statechart_def, parent_id) do
      {:ok, children} -> children
      {:error, _} = error -> raise error_msg(error, statechart_def, parent_id)
    end
  end

  # TODO rename to get_path_of?
  @spec get_path(t, Node.t() | Node.fetch_spec(), (Node.t() -> term)) :: [term]
  # TODO replace this default with nil
  def get_path(tree, node, mapper \\ fn node -> node end)

  def get_path(%__MODULE__{} = tree, %Node{} = node, mapper) do
    tree
    |> nodes
    |> Stream.take_while(fn %Node{lft: lft} -> lft <= node.lft end)
    |> Stream.filter(fn %Node{rgt: rgt} -> node.rgt <= rgt end)
    |> Enum.map(mapper)
  end

  def fetch_parent_by_id(statechart_def, child_id) do
    with {:ok, path} <- fetch_path_by_id(statechart_def, child_id),
         %Node{} = node <- Enum.at(path, -2, error_no_parent()) do
      {:ok, node}
    else
      {:error, _type} = error -> error
    end
  end

  @spec fetch_parent_by_id!(t, Node.id()) :: Node.t()
  def fetch_parent_by_id!(statechart_def, child_id) when is_integer(child_id) do
    case fetch_parent_by_id(statechart_def, child_id) do
      {:ok, parent} ->
        parent

      {:error, _type} = error ->
        raise error_msg(error, statechart_def, child_id)
    end
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

  # TODO rename tree -> statechart_def
  #####################################
  # CONVERTERS (private)

  @spec fetch_path_by_id(t, Node.id()) :: {:ok, [Node.t()]} | {:error, atom}
  defp fetch_path_by_id(statechart_def, id) do
    [terminator | rest] =
      statechart_def
      |> stream_nodes_up_to_and_incl_node_id(id)
      |> Enum.reverse()

    with :ok <- Node.check_id(terminator, id),
         {lft, rgt} <- Node.lft_rgt(terminator) do
      parent_nodes = for node <- rest, Node.lft(node) < lft, rgt < Node.rgt(node), do: node
      path = Enum.reverse([terminator | parent_nodes])
      {:ok, path}
    else
      {:error, :no_id_match} -> error_id_not_found()
    end
  end

  defp stream_nodes_up_to_and_incl_node_id(statechart_def, id) do
    statechart_def
    |> nodes
    |> Stream.chunk_by(fn node -> Node.id(node) == id end)
    |> Stream.take(2)
    |> Stream.concat()
  end

  defp stream_nodes_starting_at_node_id(statechart_def, id) do
    statechart_def
    |> nodes
    |> Stream.drop_while(fn node -> Node.id(node) != id end)
  end

  #####################################
  # HELPERS

  # TODO use this elsewhere
  defp error_id_not_found, do: {:error, :id_not_found}
  defp error_no_parent, do: {:error, :no_parent}

  defp error_msg({:error, error_type}, statechart_def, id) do
    case error_type do
      :id_not_found ->
        "Child id #{id} not found in #{inspect(statechart_def)}"

      :no_parent ->
        "Child node id=#{id} has no parent in #{inspect(statechart_def)}"
    end
  end

  #####################################
  # IMPLEMENTATIONS

  # defimpl Inspect do
  #   def inspect(tree, opts) do
  #     Util.Inspect.custom_kv("Statechart", tree.nodes, opts)
  #   end
  # end
end

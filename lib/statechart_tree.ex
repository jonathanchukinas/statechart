defmodule Statechart.Tree do
  @moduledoc """
  Some terminology:

  - `t:path/0`: a list of nodes tracing a path from root to the node in question
  - ancestors: the `t:path/0` list minus the last node
  - descendents: all nodes that have the current node as one of their ancestors
  - parent: the parent of the node in question
  - children: ancestors, but only one level deep
  """

  # TODO move the above definitions to type and typedocs

  alias Statechart.Node
  alias Statechart.Tree.Insertable
  alias Statechart.Tree.IsTree

  @type t :: IsTree.t()

  @typedoc """
  All the nodes that have a given node as an ancestor.

  In Modified Preorder Tree lingo,
  a descendent has an `lft` greater that its ancestor
  and a `rgt` less that its ancestor.
  """
  @type descendent :: Node.t()
  @type descendents :: [descendent]

  @typedoc """
  This is the line of nodes from root to the node in question.
  """
  @type path :: [Node.t()]

  @typedoc """
  Union of a node's `t:path/0` and `t:descendents/0`.

  Useful when e.g. looking for deplicate [transitions](`t:Statechart.Transition.t/0`).
  """
  @type family_tree :: [Node.t()]
  @starting_node_id 1

  #####################################
  # REDUCERS

  @spec insert(t, Insertable.t(), Node.id()) :: {:ok, t} | {:error, :id_not_found}
  def insert(tree, insertable, parent_id) do
    new_nodes = Insertable.nodes(insertable)

    with {:ok, parent} <- fetch_node_by_id(tree, parent_id) do
      parent_rgt = Node.rgt(parent)

      starting_new_id = 1 + max_node_id(tree)

      old_nodes_addend = 2 * length(new_nodes)
      new_nodes_addend = parent_rgt

      maybe_update_old_node = fn %Node{} = node, key ->
        Node.update_if(node, key, &(&1 >= parent_rgt), &(&1 + old_nodes_addend))
      end

      prepared_old_nodes =
        tree
        |> fetch_nodes!()
        |> Stream.map(&maybe_update_old_node.(&1, :lft))
        |> Stream.map(&maybe_update_old_node.(&1, :rgt))

      prepared_new_nodes =
        Enum.map(new_nodes, fn %Node{} = node ->
          node
          |> Node.add_to_lft_rgt(new_nodes_addend)
          |> Statechart.HasIdRefs.incr_id_refs(0, starting_new_id - Insertable.min_id(insertable))
        end)

      nodes =
        [prepared_old_nodes, prepared_new_nodes]
        |> Stream.concat()
        |> Enum.sort_by(&Node.lft/1)

      {:ok, put_nodes(tree, nodes)}
    else
      {:error, _type} = error -> error
    end
  end

  @spec insert!(t, Insertable.t(), Node.id()) :: t
  def insert!(tree, insertable, parent_id) do
    case insert(tree, insertable, parent_id) do
      {:ok, node} -> node
      error -> raise error_msg(error, tree, parent_id)
    end
  end

  defdelegate put_nodes(tree, nodes), to: IsTree

  def update_root(tree, fun) do
    [root | tail] = fetch_nodes!(tree)
    put_nodes(tree, [fun.(root) | tail])
  end

  @spec update_node_by_id(t, Node.id(), Node.reducer()) :: t
  def update_node_by_id(tree, id, update_fn) do
    tree
    |> fetch_nodes!
    |> _update_node_by_id([], id, update_fn)
    |> case do
      {:ok, nodes} -> {:ok, put_nodes(tree, nodes)}
      {:error, :id_not_found} = error -> error
    end
  end

  @spec replace_node(t, Node.t()) :: t
  def replace_node(tree, node) do
    update_fn = fn _node -> node end
    id = Node.id(node)
    update_node_by_id(tree, id, update_fn)
  end

  #####################################
  # CONVERTERS

  @spec contains_id?(t, Node.id()) :: boolean
  def contains_id?(tree, id), do: id in 1..max_node_id(tree)

  @doc """
  Get list of all of a node's [descendents](`t:descendent/0`)
  """
  @spec fetch_descendents_by_id(t, Node.id()) :: {:ok, descendents} | {:error, atom}
  def fetch_descendents_by_id(tree, parent_id) do
    tree
    |> nodes_starting_at_node_id(parent_id)
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

  @spec fetch_family_tree_by_id(t, Node.id()) :: {:ok, family_tree}
  def fetch_family_tree_by_id(tree, node_id) do
    with {:ok, path} <- fetch_path_by_id(tree, node_id),
         {:ok, descendents} <- fetch_descendents_by_id(tree, node_id) do
      {:ok, path ++ descendents}
    else
      {:error, _reason} = error -> error
    end
  end

  @spec fetch_children_by_id(t, Node.id()) :: {:ok, [Node.t()]} | {:error, atom}
  def fetch_children_by_id(tree, parent_id) do
    case fetch_descendents_by_id(tree, parent_id) do
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
  def fetch_children_by_id!(tree, parent_id) do
    case fetch_children_by_id(tree, parent_id) do
      {:ok, children} -> children
      {:error, _} = error -> raise error_msg(error, tree, parent_id)
    end
  end

  defdelegate fetch_nodes!(tree), to: IsTree

  @spec fetch_node_by_id(t, Node.id()) :: {:ok, Node.t()} | {:error, :id_not_found}
  def fetch_node_by_id(tree, id) do
    tree
    |> fetch_nodes!()
    |> Enum.find(error_id_not_found(), &(Node.id(&1) == id))
    |> case do
      %Node{} = node -> {:ok, node}
      {:error, _type} = error -> error
    end
  end

  @spec fetch_node_by_id!(t, Node.id()) :: Node.t()
  def fetch_node_by_id!(tree, id) do
    case fetch_node_by_id(tree, id) do
      {:ok, node} -> node
      error -> raise error_msg(error, tree, id)
    end
  end

  @spec fetch_parent_by_id(t, Node.id()) ::
          {:ok, Node.t()} | {:error, :id_not_found} | {:error, :no_parent}
  def fetch_parent_by_id(tree, child_id) do
    with {:ok, path} <- fetch_path_by_id(tree, child_id),
         %Node{} = node <- Enum.at(path, -2, error_no_parent()) do
      {:ok, node}
    else
      {:error, _type} = error -> error
    end
  end

  @spec fetch_parent_by_id!(t, Node.id()) :: Node.t()
  def fetch_parent_by_id!(tree, child_id) when is_integer(child_id) do
    case fetch_parent_by_id(tree, child_id) do
      {:ok, parent} ->
        parent

      {:error, _type} = error ->
        raise error_msg(error, tree, child_id)
    end
  end

  @spec fetch_path_by_id(t, Node.id()) :: {:ok, [Node.t()]} | {:error, :id_not_found}
  def fetch_path_by_id(tree, id) do
    [terminator | rest] =
      tree
      |> nodes_up_to_and_incl_node_id(id)
      |> Enum.reverse()

    with :ok <- check_id(terminator, id),
         {lft, rgt} <- Node.lft_rgt(terminator) do
      parent_nodes = for node <- rest, Node.lft(node) < lft, rgt < Node.rgt(node), do: node
      path = Enum.reverse([terminator | parent_nodes])
      {:ok, path}
    else
      {:error, _type} = error -> error
    end
  end

  @spec min_node_id(t) :: Node.id()
  def min_node_id(_tree) do
    @starting_node_id
  end

  @spec max_node_id(t) :: Node.id()
  def max_node_id(tree) do
    @starting_node_id - 1 + node_count(tree)
  end

  @spec node_count(t) :: pos_integer
  def node_count(tree) do
    {lft, rgt} = tree |> root() |> Node.lft_rgt()
    count = (rgt + 1 - lft) / 2
    round(count)
  end

  @spec root(t) :: Node.t()
  def root(tree) do
    tree |> fetch_nodes!() |> hd
  end

  #####################################
  # CONVERTERS (private)

  # TODO what does this do?
  @spec nodes_up_to_and_incl_node_id(t, Node.id()) :: Enumerable.t()
  defp nodes_up_to_and_incl_node_id(tree, id) do
    tree
    |> fetch_nodes!()
    |> Stream.chunk_by(fn node -> Node.id(node) == id end)
    |> Stream.take(2)
    |> Stream.concat()
  end

  @spec nodes_starting_at_node_id(t, Node.id()) :: Enumerable.t()
  defp nodes_starting_at_node_id(tree, id) do
    tree
    |> fetch_nodes!()
    |> Stream.drop_while(fn node -> Node.id(node) != id end)
  end

  #####################################
  # HELPERS

  def starting_node_id, do: @starting_node_id

  @spec check_id(Node.t(), Node.id()) :: :ok | {:error, :id_not_found}
  defp check_id(node, id) do
    if Node.id(node) == id, do: :ok, else: error_id_not_found()
  end

  defp error_id_not_found, do: {:error, :id_not_found}
  defp error_no_parent, do: {:error, :no_parent}

  @spec error_msg({:error, atom}, t, Node.id()) :: String.t()
  defp error_msg({:error, error_type}, tree, id) do
    case error_type do
      :id_not_found ->
        "Child id #{id} not found in #{inspect(tree)}"

      :no_parent ->
        "Child node id=#{id} has no parent in #{inspect(tree)}"
    end
  end

  @spec _update_node_by_id([Node.t()], [Node.t()], Node.id(), Node.reducer()) ::
          {:ok, [Node.t()]} | {:error, :id_not_found}
  defp _update_node_by_id([], _past_nodes, _id, _update_fn) do
    {:error, :id_not_found}
  end

  defp _update_node_by_id([node | tail], past_nodes, id, update_fn) do
    case Node.id(node) do
      ^id ->
        nodes = [update_fn.(node) | tail]

        all_nodes =
          Enum.reduce(past_nodes, nodes, fn node, nodes ->
            [node | nodes]
          end)

        {:ok, all_nodes}

      _ ->
        _update_node_by_id(tail, [node | past_nodes], id, update_fn)
    end
  end
end

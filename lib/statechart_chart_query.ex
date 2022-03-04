defmodule Statechart.Chart.Query do
  alias Statechart.Chart
  alias Statechart.Event
  alias Statechart.HasIdRefs
  alias Statechart.Metadata
  alias Statechart.MetadataAccess
  alias Statechart.Node
  alias Statechart.Transition
  alias Statechart.State
  alias Statechart.Tree
  alias Statechart.Tree.IsTree

  @type t :: Chart.t()

  @typedoc """
  To travel from one node to another, you have to travel up the origin node's path
  and then down the target node's path. This type describes that path.
  You rarely ever go all the way up to the root node. Instead, you travel up to where
  the two paths meet.

  This is important for handling the exit/enter actions for each node along this path.

  CONSIDER: come up with a better term for it? One that doesn't use the word `path`?
  """
  @type transition_path :: [{Node.action_type(), Node.t()}]

  #####################################
  # REDUCERS

  @spec update_node_by_name(t, Node.name(), (Node.t() -> Node.t())) ::
          {:ok, t} | {:error, :id_not_found | :name_not_found | :ambiguous_state_name}
  def update_node_by_name(chart, name, update_fn) do
    with {:ok, node} <- fetch_node_by_name(chart, name),
         {:ok, _chart} = result <- Tree.update_node_by_id(chart, Node.id(node), update_fn) do
      result
    else
      {:error, _reason} = error -> error
    end
  end

  @spec merge_subchart_at(t, t, Node.id()) :: {:ok, t} | {:error, :id_not_found}
  def merge_subchart_at(chart, subchart, merge_node_id) do
    subchart_root = Tree.root(subchart)
    subchart_root_id = Node.id(subchart_root)

    with {:ok, subchart_descendents} = Tree.fetch_descendents_by_id(subchart, subchart_root_id),
         {:ok, chart} <-
           Tree.update_node_by_id(chart, merge_node_id, &Node.merge(&1, subchart_root)),
         {:ok, merge_node} <- Tree.fetch_node_by_id(chart, merge_node_id) do
      parent_rgt = Node.rgt(merge_node)

      new_nodes =
        (fn ->
           old_nodes_addend_lft_rgt = 2 * length(subchart_descendents)
           # TODO DRY some of this out
           maybe_update_old_node = fn %Node{} = node, key ->
             Node.update_if(node, key, &(&1 >= parent_rgt), &(&1 + old_nodes_addend_lft_rgt))
           end

           chart
           |> Tree.fetch_nodes!()
           |> Stream.map(&maybe_update_old_node.(&1, :lft))
           |> Stream.map(&maybe_update_old_node.(&1, :rgt))
         end).()

      new_descendents =
        case subchart_descendents do
          [] ->
            []

          [first_descendent | _tail] ->
            descendents_lft_rgt_addend = parent_rgt - Node.lft(first_descendent)

            # TODO isn't there a better way?
            descendents_min_id = Enum.min_by(subchart_descendents, &Node.id/1) |> Node.id()

            starting_new_id = 1 + Tree.max_node_id(chart)
            descendents_id_addend = starting_new_id - descendents_min_id

            new_nodes_id_update = fn
              ^subchart_root_id -> merge_node_id
              id when is_integer(id) -> id + descendents_id_addend
            end

            Enum.map(subchart_descendents, fn %Node{} = node ->
              node
              |> Node.add_to_lft_rgt(descendents_lft_rgt_addend)
              |> HasIdRefs.update_id_refs(new_nodes_id_update)
            end)
        end

      nodes =
        [new_nodes, new_descendents]
        |> Stream.concat()
        |> Enum.sort_by(&Node.lft/1)

      {:ok, Tree.put_nodes(chart, nodes)}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  #####################################
  # CONVERTERS

  @spec fetch_actions(Chart.t(), Node.id(), Node.id()) ::
          {:ok, [Node.action_fn()]} | {:error, atom}
  def fetch_actions(chart, origin_id, destination_id) when is_integer(origin_id) do
    with {:ok, current_path} <- Tree.fetch_path_nodes_by_id(chart, origin_id),
         {:ok, destination_path} <- Tree.fetch_path_nodes_by_id(chart, destination_id) do
      actions =
        do_transition_path(current_path, destination_path)
        |> Enum.flat_map(fn {action_type, node} ->
          Node.actions(node, action_type)
        end)

      {:ok, actions}
    end
  end

  @spec fetch_node_by_metadata(t, Metadata.t()) ::
          {:ok, Node.maybe_not_inserted()} | {:error, :no_metadata_match}
  def fetch_node_by_metadata(chart, metadata) do
    chart
    |> IsTree.fetch_nodes!()
    |> Enum.find(fn node -> Node.metadata(node) == metadata end)
    |> case do
      nil -> {:error, :no_metadata_match}
      %Node{} = node -> {:ok, node}
    end
  end

  @doc """
  Seek a node with a maching name.

  `opts` supports the following:
  - `search_subcharts` (default: `false`)
  """
  @spec fetch_node_by_name(t, atom, Keyword.t()) ::
          {:ok, Node.t()} | {:error, :name_not_found} | {:error, :ambiguous_state_name}
  def fetch_node_by_name(%Chart{nodes: nodes} = chart, name, opts \\ []) when is_atom(name) do
    nodes =
      if opts[:search_subcharts] do
        nodes
      else
        local_nodes(chart)
      end

    name_matches = fn node -> Node.name(node) == name end

    case Enum.filter(nodes, name_matches) do
      [%Node{} = node] -> {:ok, node}
      [] -> {:error, :name_not_found}
      _ -> {:error, :ambiguous_state_name}
    end
  end

  @spec local_nodes(t) :: [Node.t()]
  def local_nodes(chart) do
    chart |> do_local_nodes |> Enum.to_list()
  end

  @spec local_nodes_by_name(t, Node.name()) :: [Node.t()]
  def local_nodes_by_name(chart, name) do
    chart |> do_local_nodes |> Enum.filter(&(Node.name(&1) == name))
  end

  @spec fetch_id_by_state(t, State.t(), Keyword.t()) :: {:ok, Node.id()} | {:error, :id_not_found}
  def fetch_id_by_state(chart, node_id, opts \\ [])

  def fetch_id_by_state(chart, node_id, _opts) when is_integer(node_id) do
    if Tree.contains_id?(chart, node_id), do: {:ok, node_id}, else: {:error, :id_not_found}
  end

  def fetch_id_by_state(chart, node_name, opts) when is_atom(node_name) do
    case fetch_node_by_name(chart, node_name, opts) do
      {:ok, node} -> {:ok, Node.id(node)}
      {:error, _reason} = error -> error
    end
  end

  @spec fetch_id_by_state!(t, State.t()) :: Node.id()
  def fetch_id_by_state!(chart, state) do
    case fetch_id_by_state(chart, state) do
      {:ok, node_id} -> node_id
      {:error, _reason} -> raise "#{state} not found!"
    end
  end

  @doc """
  Searches through a node's `t:Statechart.Tree.path/0` for a Transition matching the given Event.
  """
  @spec fetch_transition(t, Node.id(), Event.t()) ::
          {:ok, Transition.t()} | {:error, :event_not_found}
  def fetch_transition(chart, node_id, event) do
    with {:ok, nodes} <- Tree.fetch_path_nodes_by_id(chart, node_id),
         {:ok, transition} <- fetch_transition_from_nodes(nodes, event) do
      {:ok, transition}
    end
  end

  @doc """
  If it exists, return a transition that exists among a node's [family tree](`t:Statechart.Tree.family_tree/0`)
  """
  @spec find_transition_in_family_tree(Chart.t(), Node.id(), Event.t()) ::
          Transition.t() | nil
  def find_transition_in_family_tree(chart, id, event) do
    case fetch_transition_by_id_and_event(chart, id, event) do
      {:ok, %Transition{} = transition} -> transition
      _ -> nil
    end
  end

  @doc """
  Look for an event among a node's ancestors and path, which includes itself.
  """
  @spec fetch_transition_by_id_and_event(t, Node.id(), Event.t()) ::
          {:ok, Transition.t()} | {:error, atom}
  def fetch_transition_by_id_and_event(chart, id, event) do
    with {:ok, nodes} <- Tree.fetch_family_tree_by_id(chart, id) do
      nodes
      |> Stream.flat_map(&Node.transitions/1)
      |> Enum.find(&(Transition.event(&1) == event))
      |> case do
        %Transition{} = transition -> {:ok, transition}
        nil -> {:error, :transition_not_found}
      end
    else
      {:error, _reason} = error -> error
    end
  end

  @doc """
  Events can target branch nodes, but these nodes must resolve to a leaf node
  """
  @spec fetch_default_leaf_node(Chart.t(), Node.t()) :: {:ok, Node.t()} | {:error, atom}
  def fetch_default_leaf_node(%Chart{} = chart, %Node{} = node) do
    with :ok <- Node.validate_branch_node(node),
         {:ok, destination_id} <- Node.fetch_default_id(node),
         {:ok, destination_node} <- Tree.fetch_node_by_id(chart, destination_id) do
      fetch_default_leaf_node(chart, destination_node)
    else
      {:error, :is_leaf_node} -> {:ok, node}
      _ -> {:error, :no_default_leaf}
    end
  end

  # TODO make sure used
  @spec validate_node_resolves(Chart.t(), Node.id()) :: :ok | {:error, :no_default_leaf}
  def validate_node_resolves(chart, id) do
    with {:ok, node} <- Tree.fetch_node_by_id(chart, id),
         {:ok, _leaf_node} <- fetch_default_leaf_node(chart |> IO.inspect(), node) do
      :ok
    end
  end

  def validate_target_id_is_descendent(chart, origin_id, target_id) do
    with {:ok, descendents} <- Tree.fetch_descendents_by_id(chart, origin_id),
         true <- target_id in Stream.map(descendents, &Node.id/1) do
      :ok
    else
      _ -> {:error, :target_not_descendent}
    end
  end

  @spec local_node_names(t) :: [Node.name()]
  def local_node_names(chart) do
    chart
    |> do_local_nodes
    |> Enum.map(&Node.name/1)
  end

  #####################################
  # CONVERTERS (private)

  @spec do_local_nodes(t) :: Enumerable.t()
  defp do_local_nodes(%Chart{nodes: nodes} = chart) do
    {:ok, tree_module} = MetadataAccess.fetch_module(chart)

    Stream.filter(nodes, fn node ->
      {:ok, node_module} = MetadataAccess.fetch_module(node)
      tree_module == node_module
    end)
  end

  #####################################
  # HELPERS

  @spec fetch_transition_from_nodes(Tree.path(), Event.IsEvent.t()) ::
          {:ok, Transition.t()} | {:error, :event_not_found}
  defp fetch_transition_from_nodes(nodes, event) do
    nodes
    |> Stream.flat_map(&Node.transitions/1)
    |> Enum.reverse()
    |> Enum.find(&(&1 |> Transition.event() |> Event.match?(event)))
    |> case do
      nil -> {:error, :event_not_found}
      transition -> {:ok, transition}
    end
  end

  @spec do_transition_path([Node.t()], [Node.t()]) :: transition_path
  defp do_transition_path([head1, head2 | state_tail], [head1, head2 | destination_tail]) do
    do_transition_path([head2 | state_tail], [head2 | destination_tail])
  end

  defp do_transition_path([head1 | state_tail], [head1 | destination_tail]) do
    state_path_items = Stream.map(state_tail, &{:exit, &1})
    destination_path_items = Enum.map(destination_tail, &{:enter, &1})
    Enum.reduce(state_path_items, destination_path_items, &[&1 | &2])
  end
end

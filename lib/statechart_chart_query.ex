defmodule Statechart.Chart.Query do
  alias Statechart.Chart
  alias Statechart.Event
  alias Statechart.Metadata
  alias Statechart.MetadataAccess
  alias Statechart.Node
  alias Statechart.Transition
  alias Statechart.State
  alias Statechart.Tree
  alias Statechart.Tree.IsTree

  @type t :: Chart.t()

  #####################################
  # REDUCERS

  @spec update_node_by_name(t, Node.name(), (Node.t() -> Node.t())) ::
          {:ok, t} | {:error, :id_not_found | :name_not_found | :ambiguous_name}
  def update_node_by_name(statechart_def, name, update_fn) do
    with {:ok, node} <- fetch_node_by_name(statechart_def, name),
         {:ok, _statechart_def} = result <-
           Tree.update_node_by_id(statechart_def, Node.id(node), update_fn) do
      result
    else
      {:error, _reason} = error -> error
    end
  end

  #####################################
  # CONVERTERS

  @spec fetch_node_by_metadata(t, Metadata.t()) ::
          {:ok, Node.maybe_not_inserted()} | {:error, :no_metadata_match}
  def fetch_node_by_metadata(statechart_def, metadata) do
    statechart_def
    |> IsTree.fetch_nodes!()
    |> Enum.find(fn node -> Node.metadata(node) == metadata end)
    |> case do
      nil -> {:error, :no_metadata_match}
      %Node{} = node -> {:ok, node}
    end
  end

  @spec fetch_node_by_name(t, atom) ::
          {:ok, Node.t()} | {:error, :name_not_found} | {:error, :ambiguous_name}
  def fetch_node_by_name(statechart_def, name) when is_atom(name) do
    statechart_def
    |> local_nodes()
    |> Enum.filter(fn node -> Node.name(node) == name end)
    |> case do
      [%Node{} = node] -> {:ok, node}
      [] -> {:error, :name_not_found}
      _ -> {:error, :ambiguous_name}
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

  @spec fetch_id_by_state(t, State.t()) :: {:ok, Node.id()} | {:error, :id_not_found}
  def fetch_id_by_state(chart, node_id) when is_integer(node_id) do
    if Tree.contains_id?(chart, node_id), do: {:ok, node_id}, else: {:error, :id_not_found}
  end

  def fetch_id_by_state(chart, node_name) when is_atom(node_name) do
    case fetch_node_by_name(chart, node_name) do
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
    with {:ok, nodes} <- Tree.fetch_path_by_id(chart, node_id),
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

  def validate_target_id_is_descendent(chart, origin_id, target_id) do
    with {:ok, descendents} <- Tree.fetch_descendents_by_id(chart, origin_id),
         true <- target_id in Stream.map(descendents, &Node.id/1) do
      :ok
    else
      _ -> {:error, :target_not_descendent}
    end
  end

  #####################################
  # CONVERTERS (private)

  defp do_local_nodes(%Chart{nodes: nodes} = statechart_def) do
    {:ok, tree_module} = MetadataAccess.fetch_module(statechart_def)

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
end

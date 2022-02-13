defmodule Statechart.Definition.Query do
  alias Statechart.Definition
  alias Statechart.Event
  alias Statechart.Metadata
  alias Statechart.MetadataAccess
  alias Statechart.Node
  alias Statechart.Transition
  alias Statechart.Tree
  alias Statechart.Tree.IsTree

  @type t :: Definition.t()

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
  def local_nodes(%Definition{nodes: nodes} = statechart_def) do
    {:ok, tree_module} = MetadataAccess.fetch_module(statechart_def)

    Enum.filter(nodes, fn node ->
      {:ok, node_module} = MetadataAccess.fetch_module(node)
      tree_module == node_module
    end)
  end

  @spec fetch_node_id_by_state(t, State.t()) :: {:ok, Node.id()} | :error
  def fetch_node_id_by_state(definition, node_id) when is_integer(node_id) do
    if Tree.contains_id?(definition, node_id), do: {:ok, node_id}, else: :error
  end

  def fetch_node_id_by_state(definition, node_name) when is_atom(node_name) do
    case fetch_node_by_name(definition, node_name) do
      {:ok, node} -> {:ok, Node.id(node)}
      {:error, _reason} -> :error
    end
  end

  @spec fetch_node_id_by_state!(t, State.t()) :: Node.id()
  def fetch_node_id_by_state!(definition, state) do
    case fetch_node_id_by_state(definition, state) do
      {:ok, node_id} -> node_id
      {:error, _reason} -> raise "#{state} not found!"
    end
  end

  @spec fetch_transition(Definition.t(), Node.id(), Event.t()) ::
          {:ok, Transition.t()} | {:error, :event_not_found}
  def fetch_transition(definition, node_id, event) do
    {:ok, nodes} = Tree.fetch_path_by_id(definition, node_id)

    nodes
    |> Stream.flat_map(&Node.transitions/1)
    |> Enum.find(&(&1 |> Transition.event() |> Event.match?(event)))
    |> case do
      nil -> {:error, :event_not_found}
      transition -> {:ok, transition}
    end
  end
end

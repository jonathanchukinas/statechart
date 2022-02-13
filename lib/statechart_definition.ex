defmodule Statechart.Definition do
  use Statechart.Util.GetterStruct
  alias Statechart.Node
  alias Statechart.Tree
  alias Statechart.Tree.IsTree
  alias Statechart.Metadata
  alias Statechart.Metadata.HasMetadata

  #####################################
  # TYPES

  @starting_node_id Tree.starting_node_id()

  getter_struct do
    field :nodes, [Node.t(), ...], default: [Node.root(@starting_node_id)]
  end

  #####################################
  # CONSTRUCTORS

  @spec new() :: t
  def new() do
    %__MODULE__{nodes: [Node.root(@starting_node_id)]}
  end

  def from_env(env) do
    %__MODULE__{
      nodes: [Node.root(@starting_node_id, metadata: Metadata.from_env(env))]
    }
  end

  def fetch_from_module(module) do
    with true <- {:definition, 0} in module.__info__(:functions),
         %__MODULE__{} = definition <- module.definition() do
      {:ok, definition}
    else
      _ -> {:error, :definition_not_found}
    end
  end

  #####################################
  # API

  @doc false
  defmacro __using__(_opts) do
    quote do
      import Statechart.Definition.Query
      import Statechart.Tree
      alias Statechart.Definition
      alias Statechart.Node
    end
  end

  #####################################
  # IMPLEMENTATIONS

  defimpl IsTree do
    alias Statechart.Definition

    def put_nodes(statechart_def, nodes) do
      struct!(statechart_def, nodes: nodes)
    end

    defdelegate fetch_nodes!(statechart_def), to: Definition, as: :nodes
  end

  defimpl HasMetadata do
    # A tree's metadata is the metadata of its root node

    def fetch(statechart_def) do
      statechart_def
      |> Tree.root()
      |> HasMetadata.fetch()
    end
  end

  # defimpl Inspect do
  #   def inspect(statechart_def, opts) do
  #     Util.Inspect.custom_kv("Statechart", statechart_def.nodes, opts)
  #   end
  # end
end

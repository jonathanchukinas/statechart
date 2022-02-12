defmodule Statechart.Definition do
  use Statechart.Util.GetterStruct
  alias Statechart.Node
  alias Statechart.Tree
  alias Statechart.Tree.IsTree
  alias Statechart.Metadata
  alias Statechart.Metadata.HasMetadata

  #####################################
  # TYPES

  @starting_node_id 1

  getter_struct do
    field :nodes, [Node.t(), ...], default: [Node.root(@starting_node_id)]
    # TODO move to the interpreter?
    field :context, nil, default: nil
  end

  @type t(context_type) ::
          %__MODULE__{
            nodes: [Node.t(), ...],
            context: context_type
          }

  #####################################
  # CONSTRUCTORS

  @spec new() :: t
  def new, do: %__MODULE__{}

  # TODO move the context into the opts
  @spec new(context_type, keyword) :: t(context_type) when context_type: any
  def new(context, opts \\ []) when is_list(opts) do
    # There's gotta be a more idiomatic way to do this
    opts =
      [metadata: %{}]
      |> Keyword.merge(opts)

    %__MODULE__{
      context: context,
      # TODO the root I should be part of opts?
      nodes: [Node.root(@starting_node_id, opts)]
    }
  end

  def from_metadata(%Metadata{} = metadata) do
    %__MODULE__{
      nodes: [Node.root(@starting_node_id, metadata: metadata)]
    }
  end

  #####################################
  # API

  # TODO this ought to move to Statechart
  # TODO in the docs, talk about a convention where you would name the using module something like MyApp.Statechart
  defmacro __using__(_opts) do
    quote do
      import Statechart.Build, only: [defchart: 1, defchart: 2]
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

    def put(statechart_def, metadata) do
      Tree.update_root(statechart_def, &HasMetadata.put(&1, metadata))
    end
  end

  # defimpl Inspect do
  #   def inspect(statechart_def, opts) do
  #     Util.Inspect.custom_kv("Statechart", statechart_def.nodes, opts)
  #   end
  # end
end

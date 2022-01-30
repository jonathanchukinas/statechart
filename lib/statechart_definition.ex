defmodule Statechart.Definition do
  use Statechart.Util.GetterStruct
  alias Statechart.Node

  #####################################
  # TYPES

  @starting_node_id 1

  getter_struct do
    field :nodes, [Node.t(), ...], default: [Node.root(@starting_node_id)]
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

  @spec new(context_type) :: t(context_type) when context_type: any
  def new(context), do: %__MODULE__{context: context}

  #####################################
  # API

  defmacro __using__(_opts) do
    quote do
      import Statechart.Define, only: [defchart: 1, defchart: 2]
    end
  end

  #####################################
  # IMPLEMENTATIONS

  defimpl Statechart.TreeStructure do
    alias Statechart.Definition

    def put_nodes(statechart_def, nodes) do
      struct!(statechart_def, nodes: nodes)
    end

    defdelegate fetch_nodes!(statechart_def), to: Definition, as: :nodes
  end

  # defimpl Inspect do
  #   def inspect(statechart_def, opts) do
  #     Util.Inspect.custom_kv("Statechart", statechart_def.nodes, opts)
  #   end
  # end
end

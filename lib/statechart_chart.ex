defmodule Statechart.Chart do
  use Statechart.Util.GetterStruct
  alias Statechart.Node
  alias Statechart.Tree
  alias Statechart.Tree.IsTree
  alias Statechart.Metadata
  alias Statechart.Metadata.HasMetadata

  #####################################
  # TYPES

  @starting_node_id Tree.starting_node_id()

  @type spec :: t() | module

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

  @spec fetch(spec) :: {:ok, t} | {:error, :chart_not_found}
  def fetch(%__MODULE__{} = chart), do: {:ok, chart}

  def fetch(module) when is_atom(module) do
    with true <- {:__chart__, 0} in module.__info__(:functions),
         %__MODULE__{} = chart <- module.__chart__() do
      {:ok, chart}
    else
      _ -> {:error, :chart_not_found}
    end
  end

  def fetch(_), do: {:error, :chart_not_found}

  #####################################
  # API

  @doc false
  defmacro __using__(_opts) do
    quote do
      import Statechart.Chart.Query
      import Statechart.Tree
      alias Statechart.Chart
      alias Statechart.Node
    end
  end

  #####################################
  # IMPLEMENTATIONS

  defimpl IsTree do
    alias Statechart.Chart

    def put_nodes(chart, nodes) do
      struct!(chart, nodes: nodes)
    end

    defdelegate fetch_nodes!(chart), to: Chart, as: :nodes
  end

  defimpl HasMetadata do
    # A tree's metadata is the metadata of its root node

    def fetch(chart) do
      chart
      |> Tree.root()
      |> HasMetadata.fetch()
    end
  end

  # defimpl Inspect do
  #   def inspect(chart, opts) do
  #     Util.Inspect.custom_kv("Statechart", chart.nodes, opts)
  #   end
  # end
end

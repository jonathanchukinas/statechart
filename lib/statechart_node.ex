defmodule Statechart.Node do
  use Statechart.Util.GetterStruct
  alias __MODULE__
  alias Statechart.Metadata
  alias Statechart.Transition

  # @type id :: Statechart.HasIdRefs.id()
  @type id :: pos_integer

  getter_struct do
    field :id, id, default: 0
    field :name, name
    field :lft, non_neg_integer, default: 0
    field :rgt, pos_integer, default: 1
    field :metadata, Metadata.t(), enforce: false
    field :transitions, [Transition.t()], default: []
    field :default, id, enforce: nil
  end

  @type not_inserted ::
          %__MODULE__{
            id: 0 | id,
            name: atom,
            lft: non_neg_integer,
            rgt: pos_integer
          }

  @type maybe_not_inserted :: t | not_inserted
  @type reducer :: (t -> t)
  @type name :: atom

  #####################################
  # CONSTRUCTORS

  @spec root(id, keyword) :: t
  def root(id, opts \\ []) do
    new(:root, Keyword.put(opts, :id, id))
  end

  @spec new(atom, keyword) :: not_inserted
  def new(name, opts \\ []) when is_atom(name) do
    opts = Keyword.put(opts, :name, name)
    struct(__MODULE__, opts)
  end

  #####################################
  # REDUCERS

  @spec update_if(t, :lft | :rgt, (t -> boolean), (integer -> integer)) :: t
  def update_if(%__MODULE__{} = node, key, if_fn, update_fn) do
    if node |> Map.fetch!(key) |> if_fn.() do
      Map.update!(node, key, update_fn)
    else
      node
    end
  end

  @spec add_to_lft_rgt(t, integer) :: t
  def add_to_lft_rgt(%__MODULE__{lft: lft, rgt: rgt} = node, addend) do
    %__MODULE__{node | lft: lft + addend, rgt: rgt + addend}
  end

  @spec put_transition(t, Transition.t()) :: t
  def put_transition(%__MODULE__{} = node, %Transition{} = transition) do
    Map.update!(node, :transitions, &[transition | &1])
  end

  @spec put_new_default(t, id) :: {:ok, t} | {:error, :default_already_present}
  def put_new_default(node, id) do
    case default(node) do
      nil -> {:ok, %__MODULE__{node | default: id}}
      integer when is_integer(integer) -> {:error, :default_already_present}
    end
  end

  #####################################
  # CONVERTERS

  @spec lft_rgt(t) :: {integer, integer}
  def lft_rgt(%__MODULE__{lft: lft, rgt: rgt}), do: {lft, rgt}

  def validate_branch_node(%__MODULE__{lft: lft, rgt: rgt}) do
    case rgt - lft do
      1 -> {:error, :is_leaf_node}
      _ -> :ok
    end
  end

  def fetch_default_id(%__MODULE__{default: default}) do
    case default do
      nil -> {:error, :no_default}
      id when is_integer(id) -> {:ok, id}
    end
  end

  #####################################
  # IMPLEMENTATIONS

  defimpl Statechart.Metadata.HasMetadata do
    def fetch(%Node{metadata: metadata}) do
      case metadata do
        %Metadata{} -> {:ok, metadata}
        _ -> {:error, :missing_metadata}
      end
    end
  end

  defimpl Statechart.HasIdRefs do
    def incr_id_refs(%Node{id: id} = node, start_id, addend) do
      id =
        if start_id <= id do
          id + addend
        else
          id
        end

      transitions =
        node
        |> Node.transitions()
        |> Enum.map(&Statechart.HasIdRefs.incr_id_refs(&1, start_id, addend))

      %Node{node | id: id, transitions: transitions}
    end
  end

  defimpl Inspect do
    alias Statechart.Node

    def inspect(%Node{name: :root} = node, opts) do
      fields = [
        id: node.id,
        lft_rgt: {node.lft, node.rgt},
        meta: node.metadata,
        transitions: node.transitions
      ]

      Statechart.Util.Inspect.custom_kv("Root", fields, opts)
    end

    def inspect(node, opts) do
      fields = [
        id: node.id,
        lft_rgt: {node.lft, node.rgt},
        name: node.name,
        meta: node.metadata,
        transitions: node.transitions
      ]

      Statechart.Util.Inspect.custom_kv("Node", fields, opts)
    end
  end
end

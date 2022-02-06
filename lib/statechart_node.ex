defmodule Statechart.Node do
  use Statechart.Util.GetterStruct

  @type id :: pos_integer

  getter_struct do
    field :id, id, default: 0
    field :name, atom
    field :lft, non_neg_integer, default: 0
    field :rgt, pos_integer, default: 1
    field :metadata, Statechart.Node.Meta.t(), enforce: false
  end

  @type not_inserted ::
          %__MODULE__{
            id: 0 | id,
            name: atom,
            lft: non_neg_integer,
            rgt: pos_integer
          }

  @type maybe_not_inserted :: t | not_inserted

  #####################################
  # CONSTRUCTORS

  @spec root(id, keyword) :: t
  # TODO id should be part of opts?
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

  # TODO review typespecs
  @spec update_if(t, :id | :lft | :rgt, (t -> boolean), (integer -> integer)) :: t
  def update_if(%__MODULE__{} = node, key, if_fn, update_fn) do
    if node |> Map.fetch!(key) |> if_fn.() do
      Map.update!(node, key, update_fn)
    else
      node
    end
  end

  def add_to_lft_rgt(%__MODULE__{lft: lft, rgt: rgt} = node, addend) do
    %__MODULE__{node | lft: lft + addend, rgt: rgt + addend}
  end

  def set_id(node, id) do
    %__MODULE__{node | id: id}
  end

  #####################################
  # CONVERTERS

  @spec lft_rgt(t) :: {integer, integer}
  def lft_rgt(%__MODULE__{lft: lft, rgt: rgt}), do: {lft, rgt}

  #####################################
  # IMPLEMENTATIONS

  defimpl Inspect do
    alias Statechart.Node

    def inspect(%Node{name: :root} = node, opts) do
      fields = [
        id: node.id,
        lft_rgt: {node.lft, node.rgt},
        meta: node.metadata
      ]

      Statechart.Util.Inspect.custom_kv("Root", fields, opts)
    end

    def inspect(node, opts) do
      fields = [
        id: node.id,
        lft_rgt: {node.lft, node.rgt},
        name: node.name,
        meta: node.metadata
      ]

      Statechart.Util.Inspect.custom_kv("Node", fields, opts)
    end
  end
end

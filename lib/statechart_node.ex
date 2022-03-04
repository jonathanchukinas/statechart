defmodule Statechart.Node do
  use Statechart.Util.GetterStruct
  alias __MODULE__
  alias Statechart.Metadata
  alias Statechart.Transition
  alias Statechart.HasIdRefs

  # @type id :: Statechart.HasIdRefs.id()
  @type id :: pos_integer

  @type action_type :: :exit | :enter
  @type action_fn :: (State.t(), Context.t() -> Context.t())

  getter_struct do
    field :id, id, default: 0
    field :name, name
    field :lft, non_neg_integer, default: 0
    field :rgt, pos_integer, default: 1
    field :metadata, Metadata.t(), enforce: false
    field :transitions, [Transition.t()], default: []
    field :default, id, enforce: false
    field :actions, [{action_type, action_fn}], default: []
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

  defguard is_action_type(maybe_action_type) when maybe_action_type in ~w/exit enter/a

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

  @doc false
  # Used when inserting a subchart into a parent tree.
  # It's only meant to be called early in the build process,
  # just after nodes have been added to the tree.
  @spec merge(t, t) :: t
  def merge(
        %__MODULE__{default: nil, transitions: [], actions: []} = orig_node,
        %__MODULE__{} = updating_node
      ) do
    %__MODULE__{
      orig_node
      | transitions: updating_node.transitions,
        default: updating_node.default,
        actions: updating_node.actions
    }
  end

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

  @spec push_action(t, action_type, action_fn) :: t
  def push_action(%__MODULE__{actions: actions} = node, action_type, fun)
      when is_action_type(action_type) do
    %__MODULE__{node | actions: [{action_type, fun} | actions]}
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

  @spec actions(t, action_type) :: [Node.action_fn()]
  def actions(%__MODULE__{actions: actions}, action_type) when is_action_type(action_type) do
    actions
    |> Stream.filter(fn {i_action_type, _action_fn} -> i_action_type == action_type end)
    |> Stream.map(fn {_action_type, action_fn} -> action_fn end)
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

  defimpl HasIdRefs do
    def incr_id_refs(%Node{id: id} = node, start_id, addend) do
      # TODO this should call update_id_refs
      id =
        if start_id <= id do
          id + addend
        else
          id
        end

      transitions =
        node
        |> Node.transitions()
        |> Enum.map(&HasIdRefs.incr_id_refs(&1, start_id, addend))

      %Node{node | id: id, transitions: transitions}
    end

    def update_id_refs(%Node{id: id, default: default, transitions: transitions} = node, fun) do
      %Node{
        node
        | id: fun.(id),
          default: if(default, do: fun.(default)),
          transitions: Enum.map(transitions, &HasIdRefs.update_id_refs(&1, fun))
      }
    end
  end

  defimpl Inspect do
    alias Statechart.Node

    def inspect(%Node{name: :root} = node, opts) do
      fields = [id: node.id] ++ standard_fields(node)
      Statechart.Util.Inspect.custom_kv("Root", fields, opts)
    end

    def inspect(node, opts) do
      fields = [id: node.id, name: node.name] ++ standard_fields(node)
      Statechart.Util.Inspect.custom_kv("Node", fields, opts)
    end

    defp standard_fields(%Node{transitions: t, actions: a, default: d} = node) do
      [
        {:lft_rgt, {node.lft, node.rgt}},
        {:meta, node.metadata},
        if(d, do: {:default, d}),
        unless(t == [], do: {:transitions, t}),
        unless(a == [], do: {:actions, a})
      ]
      |> Enum.filter(& &1)
    end
  end
end

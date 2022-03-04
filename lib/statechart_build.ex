defmodule Statechart.Build do
  @moduledoc """
  Macros for building a statechart.

  `use Statechart, :chart` makes `defchart/2` available to

  The only macro allowed to be called initially is `defchart/2`.
  Even this can only be called once per module.
  The other macros have limited scopes where they are allowed to be called.
  `defstate/1`, `defstate/2`, `subchart/2` can be called anywhere **within**
  a `defchart/2` block, including within `defstate/2` blocks.
  `>>>/2` must occur within `defstate/2` blocks.

  These macros provide many compile checks.
  For example, if you try to define a `:hello` state twice,
  a `StatechartBuildError` exception will raise.
  """

  use TypedStruct
  use Statechart.Chart
  require Statechart.Node
  alias __MODULE__
  alias Statechart.Build.Acc
  alias Statechart.Event
  alias Statechart.Metadata
  alias Statechart.MetadataAccess
  alias Statechart.Transition

  # CONSIDER do transitions, default, and subcharts.. can they all go at the same time?
  @build_steps ~w/
    insert_nodes
    insert_subcharts
    insert_actions
    insert_transitions_and_defaults
    /a

  @type build_step :: :insert_nodes | :insert_transitions_and_defaults | :insert_subcharts

  #####################################
  # DEFCHART

  @doc """
  Create and register a statechart to this module.

  This module can be passed into `Statechart.Transitions` and `Statechart.Interpreter` functions.
  """
  @spec defchart(Keyword.t(), any) :: any
  defmacro defchart(opts \\ [], do: block) do
    ast = Build.__defchart__(block, opts)

    quote do
      (fn -> unquote(ast) end).()
    end
  end

  @doc false
  @spec __defchart__(any, keyword) :: Macro.t()
  def __defchart__(block, opts) do
    quote do
      Build.__defchart_enter__(__ENV__)

      import Build

      Build.__context_type__(unquote(opts[:context_type]))

      for build_step <- unquote(@build_steps) do
        @__sc_build_step__ build_step
        unquote(block)
      end

      Build.__defchart_exit__(__ENV__)
      @before_compile unquote(__MODULE__)
    end
  end

  defmacro __before_compile__(env) do
    chart = Acc.chart(env)
    Acc.delete_attribute(env)

    quote do
      @spec __chart__() :: t
      def __chart__, do: unquote(Macro.escape(chart))
    end
  end

  @doc false
  defmacro __context_type__(_type) do
    # case type do
    case nil do
      nil ->
        quote do
          @type t :: Chart.t()
        end

        # type ->
        #   quote do
        #     @type t :: Chart.t(unquote(type))
        #   end
    end
  end

  @doc false
  @spec __defchart_enter__(Macro.Env.t()) :: :ok
  def __defchart_enter__(%Macro.Env{} = env) do
    if Module.has_attribute?(env.module, :__sc_defchart__) do
      raise StatechartBuildError, "Only one defchart call may be made per module"
    end

    chart = Chart.from_env(env)
    Module.register_attribute(env.module, :__sc_build_step__, [])
    Module.put_attribute(env.module, :__sc_defchart__, nil)
    Acc.put_new(env, chart)
    :ok
  end

  @doc false
  @spec __defchart_exit__(Macro.Env.t()) :: :ok
  def __defchart_exit__(env) do
    Module.delete_attribute(env.module, :__sc_build_step__)
    :ok
  end

  #####################################
  # DEFSTATE

  defmacro defstate(name) do
    quote do
      defstate unquote(name), do: nil
    end
  end

  @doc """
  Create a statechart node.

  `name` must be an atom and must be unique amongst nodes defined in this
  module's statechart.
  The way to have multiple nodes sharing the same name is to define statechart
  partials in separate module and then insert those partials into a parent statechart.
  """
  defmacro defstate(name, opts \\ [], do: block) do
    quote do
      raise_if_out_of_scope("defstate/1 and defstate/2 must be called inside a defchart/2 block")
      Build.__defstate_enter__(@__sc_build_step__, __ENV__, unquote(name), unquote(opts))
      unquote(block)
      Build.__defstate_exit__(__ENV__)
    end
  end

  @doc false
  @spec __defstate_enter__(build_step, Macro.Env.t(), Node.name(), Keyword.t()) :: :ok
  def __defstate_enter__(build_step, env, name, opts \\ [])

  def __defstate_enter__(:insert_nodes = _build_step, env, name, _opts) do
    old_chart = Acc.chart(env)
    parent_id = Acc.current_id(env)

    with :ok <- validate_name!(old_chart, name),
         new_node = Node.new(name, metadata: Metadata.from_env(env)),
         {:ok, new_chart} <- insert(old_chart, new_node, parent_id),
         {:ok, new_node_id} <- fetch_id_by_state(new_chart, name) do
      env
      |> Acc.put_chart(new_chart)
      |> Acc.push_current_id(new_node_id)

      :ok
    else
      {:error, reason} ->
        raise reason
    end
  end

  def __defstate_enter__(:insert_transitions_and_defaults, env, _name, opts) do
    chart = Acc.chart(env)
    {:ok, origin_node} = fetch_node_by_metadata(chart, Metadata.from_env(env))
    Acc.push_current_id(env, Node.id(origin_node))

    with {:ok, target_name} <- Keyword.fetch(opts, :default),
         :ok <- Node.validate_branch_node(origin_node),
         {:ok, target_id} <- fetch_id_by_state(chart, target_name),
         :ok <- validate_target_id_is_descendent(chart, Node.id(origin_node), target_id),
         {:ok, new_origin_node} <- Node.put_new_default(origin_node, target_id),
         {:ok, new_chart} <- replace_node(chart, new_origin_node) do
      env
      |> Acc.push_current_id(Node.id(origin_node))
      |> Acc.put_chart(new_chart)

      :ok
    else
      :error ->
        # no :default in keyword
        :ok

      {:error, :is_leaf_node} ->
        # tried assigning a default to a leaf node
        msg = "cannot assign a default to a leaf node"
        raise StatechartBuildError, msg

      {:error, :target_not_descendent} ->
        msg = "default node must be a descendent"
        raise StatechartBuildError, msg

      {:error, reason} ->
        raise reason
    end
  end

  def __defstate_enter__(_build_step, env, _name, _ops) do
    __push_current_id__(env)
  end

  @doc false
  @spec __defstate_exit__(Macro.Env.t()) :: :ok
  def __defstate_exit__(env) do
    _current_id = Acc.pop_id!(env)
    :ok
  end

  #####################################
  # ON EXIT / ENTER

  @doc """
  Register a function to be executed anytime a given node is entered or exited.
  """
  defmacro on([{action_type, action_fn}] = arg) do
    unless Node.is_action_type(action_type) do
      msg =
        "the on/1 macro expects a single-item keyword list with a " <>
          "key of either :enter or :exit, got: #{inspect(arg)}"

      raise StatechartBuildError, msg
    end

    quote do
      Build.__action__(
        @__sc_build_step__,
        __ENV__,
        unquote(action_type),
        unquote(action_fn)
      )
    end
  end

  @doc false
  @spec __action__(build_step, Macro.Env.t(), Node.action_type(), Node.action_fn()) :: :ok
  def __action__(:insert_actions, env, action_type, action_fn) do
    chart = Acc.chart(env)
    current_id = Acc.current_id(env)

    {:ok, new_chart} =
      update_node_by_id(chart, current_id, &Node.push_action(&1, action_type, action_fn))

    Acc.put_chart(env, new_chart)
    :ok
  end

  def __action__(_build_step, _env, _action_type, _action_fn) do
    :ok
  end

  #####################################
  # TRANSITION

  @doc """
  Register a transtion from an event and target state.
  """
  defmacro transition(event, target_name) do
    quote bind_quoted: [event: event, target_name: target_name] do
      Build.__transition__(@__sc_build_step__, __ENV__, event, target_name)
    end
  end

  @doc """
  Alias for `transition/2`
  """
  defmacro event >>> target_name do
    quote do: transition(unquote(event), unquote(target_name))
  end

  @spec __transition__(build_step, Macro.Env.t(), Event.t(), Node.name()) :: :ok
  def __transition__(:insert_transitions_and_defaults, env, event, target_name) do
    chart = Acc.chart(env)
    node_id = Acc.current_id(env)

    unless :ok == Event.validate(event) do
      raise StatechartBuildError, "expect event to be an atom or module, got: #{inspect(event)}"
    end

    if transition = find_transition_in_family_tree(chart, node_id, event) do
      msg =
        "events must be unique within a node and among its path and descendents, the event " <>
          inspect(event) <>
          " is already registered on line " <>
          inspect(MetadataAccess.fetch_line_number(transition))

      raise StatechartBuildError, msg
    end

    with {:ok, target_id} <-
           fetch_id_by_state(chart, target_name),
         transition = Transition.new(event, target_id, Metadata.from_env(env)),
         {:ok, chart} <-
           update_node_by_id(chart, node_id, &Node.put_transition(&1, transition)) do
      Acc.put_chart(env, chart)
      :ok
    else
      {:error, :name_not_found} ->
        msg =
          "Expected to find a target state with name :#{target_name} but none was found, " <>
            "valid names are: #{inspect(local_node_names(chart))}"

        raise StatechartBuildError, msg

      {:error, error} ->
        raise StatechartBuildError, to_string(error)
    end
  end

  def __transition__(_build_step, _env, _event, _destination_node_name) do
    :ok
  end

  #####################################
  # SUBCHART

  @doc """
  Inject a chart defined in another module.
  """
  defmacro subchart(name, module) do
    quote bind_quoted: [name: name, module: module] do
      Build.subchart(name, module, do: nil)
    end
  end

  defmacro subchart(name, module, do: block) do
    quote do
      Build.__subchart_enter__(@__sc_build_step__, __ENV__, unquote(name), unquote(module))
      unquote(block)
      Build.__pop_current_id__(__ENV__)
    end
  end

  @spec __subchart_enter__(build_step, Macro.Env.t(), Node.name(), module) :: :ok
  def __subchart_enter__(:insert_nodes = build_step, env, name, _module) do
    __defstate_enter__(build_step, env, name)
  end

  def __subchart_enter__(:insert_subcharts, env, _name, module) do
    meta = Metadata.from_env(env)

    with chart = Acc.chart(env),
         {:ok, root_node} <- fetch_node_by_metadata(chart, meta),
         # TODO use a normal fetch?
         # TODO test for raise on invalid module
         subchart <- fetch_chart!(module, Metadata.line(meta)),
         {:ok, new_chart} <- merge_subchart_at(chart, subchart, Node.id(root_node)) do
      Acc.put_chart(env, new_chart)
      __push_current_id__(env)
    end

    :ok
  end

  def __subchart_enter__(_build_step, env, _name, _module) do
    __push_current_id__(env)
  end

  # TODO test that calling defstate inside subchart raises

  #####################################
  # HELPERS

  @doc false
  @spec __push_current_id__(Macro.Env.t()) :: :ok
  def __push_current_id__(env) do
    {:ok, node} = fetch_node_by_metadata(Acc.chart(env), Metadata.from_env(env))

    Acc.push_current_id(env, Node.id(node))
  end

  @doc false
  @spec __pop_current_id__(Macro.Env.t()) :: :ok
  def __pop_current_id__(env) do
    _current_id = Acc.pop_id!(env)
    :ok
  end

  @doc false
  @spec validate_name!(Chart.t(), Node.name()) :: :ok | no_return
  defp validate_name!(chart, name) do
    unless is_atom(name) do
      msg = "expected defstate arg1 to be an atom, got: #{inspect(name)}"
      raise StatechartBuildError, msg
    end

    case local_nodes_by_name(chart, name) do
      [] ->
        :ok

      [node_with_same_name | _tail] ->
        {:ok, line_number} = MetadataAccess.fetch_line_number(node_with_same_name)
        msg = "a state with name '#{name}' was already declared on line #{line_number}"
        raise StatechartBuildError, msg
    end
  end

  #####################################
  # VALIDATION

  # CONSIDER making this specific to subchart
  defp fetch_chart!(module, line_number) do
    case Chart.fetch(module) do
      {:ok, chart} ->
        chart

      _ ->
        raise StatechartBuildError,
              "the module #{module} on line #{line_number} does not define a Statechart.Chart.t struct. See `use Statechart`"
    end
  end

  defmacro raise_if_out_of_scope(message) do
    quote do
      unless Module.has_attribute?(__MODULE__, :__sc_build_step__) do
        raise StatechartBuildError, unquote(message)
      end
    end
  end
end

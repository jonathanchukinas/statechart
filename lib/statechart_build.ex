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

  # TODO implement a `transition/2` macro. `>>>/2` will be a shorthand for it.
  # TODO implement `use Statechart, :chart`

  use TypedStruct
  use Statechart.Chart
  alias __MODULE__
  alias Statechart.Build.Acc
  alias Statechart.Event
  alias Statechart.Metadata
  alias Statechart.MetadataAccess
  alias Statechart.State
  alias Statechart.Transition

  @build_steps ~w/
    insert_nodes
    insert_transitions
    insert_subcharts
    /a

  @type build_step :: :insert_nodes | :insert_transitions | :insert_subcharts

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
    statechart_def = Acc.statechart_def(env)
    Acc.delete_attribute(env)

    quote do
      @spec __chart__() :: t
      def __chart__, do: unquote(Macro.escape(statechart_def))
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

    statechart_def = Chart.from_env(env)
    Module.register_attribute(env.module, :__sc_build_step__, [])
    Module.put_attribute(env.module, :__sc_defchart__, nil)
    Acc.put_new(env, statechart_def)
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
  defmacro defstate(name, do: block) do
    quote do
      Build.__defstate_enter__(@__sc_build_step__, __ENV__, unquote(name))
      unquote(block)
      Build.__defstate_exit__(__ENV__)
    end
  end

  @doc false
  @spec __defstate_enter__(build_step, Macro.Env.t(), Node.name()) :: :ok
  def __defstate_enter__(:insert_nodes = _build_step, env, name) do
    old_definition = Acc.statechart_def(env)
    parent_id = Acc.current_id(env)

    with :ok <- validate_name!(old_definition, name),
         new_node = Node.new(name, metadata: Metadata.from_env(env)),
         {:ok, new_definition} <- insert(old_definition, new_node, parent_id),
         {:ok, new_node_id} <- fetch_id_by_state(new_definition, name) do
      env
      |> Acc.put_statechart_def(new_definition)
      |> Acc.put_current_id(new_node_id)

      :ok
    else
      {:error, reason} ->
        raise reason
    end
  end

  def __defstate_enter__(_build_step, env, _name) do
    {:ok, node} = fetch_node_by_metadata(Acc.statechart_def(env), Metadata.from_env(env))
    Acc.put_current_id(env, Node.id(node))
    :ok
  end

  @doc false
  @spec __defstate_exit__(Macro.Env.t()) :: :ok
  def __defstate_exit__(env) do
    statechart_def = Acc.statechart_def(env)

    with {:ok, current_node} <- fetch_node_by_metadata(statechart_def, Metadata.from_env(env)),
         {:ok, parent_node} <- fetch_parent_by_id(statechart_def, Node.id(current_node)),
         parent_id <- Node.id(parent_node) do
      Acc.put_current_id(env, parent_id)
      :ok
    else
      {:error, reason} -> raise CompileError, description: to_string(reason)
    end
  end

  #####################################
  # TRANSITION

  @doc """
  Register a transtion from an event and target state.
  """
  @spec Event.registration() >>> State.t() :: :ok
  defmacro event >>> destination_node_name do
    unless :ok == Event.validate(event) do
      raise CompileError, description: "#{event} is not a valid event"
    end

    quote bind_quoted: [event: event, destination_node_name: destination_node_name] do
      Build.__transition__(@__sc_build_step__, __ENV__, event, destination_node_name)
    end
  end

  @spec __transition__(build_step, Macro.Env.t(), Event.t(), Node.name()) :: :ok
  def __transition__(:insert_transitions, env, event, destination_node_name) do
    statechart_def = Acc.statechart_def(env)
    node_id = Acc.current_id(env)

    unless :ok == Event.validate(event) do
      raise StatechartBuildError, "expect event to be an atom or module, got: #{inspect(event)}"
    end

    if transition = find_transition_among_path_and_ancestors(statechart_def, node_id, event) do
      msg =
        "events must be unique within a node and among its path and descendents, the event " <>
          inspect(event) <>
          " is already registered on line " <>
          inspect(MetadataAccess.fetch_line_number(transition))

      raise StatechartBuildError, msg
    end

    with {:ok, destination_id} <- fetch_id_by_state(statechart_def, destination_node_name),
         transition = Transition.new(event, destination_id, Metadata.from_env(env)),
         {:ok, statechart_def} <-
           update_node_by_id(statechart_def, node_id, &Node.put_transition(&1, transition)) do
      Acc.put_statechart_def(env, statechart_def)
      :ok
    else
      {:error, error} -> raise to_string(error)
    end
  end

  def __transition__(_build_step, _env, _event, _destination_node_name) do
    :ok
  end

  #####################################
  # TRANSITION

  @doc """
  Inject a chart defined in another module.
  """
  defmacro subchart(name, module) do
    quote bind_quoted: [name: name, module: module] do
      Build.__subchart__(@__sc_build_step__, __ENV__, name, module)
    end
  end

  def __subchart__(:insert_subcharts, env, name, module) do
    metadata = Metadata.from_env(env)

    update_child_root = fn %Node{} = node ->
      %Node{node | name: name, metadata: metadata}
    end

    with parent_definition = Acc.statechart_def(env),
         parent_id = Acc.current_id(env),
         :ok <- validate_name!(parent_definition, name),
         child_definition <- fetch_definition!(module, Metadata.line(metadata)),
         new_child_definition = update_root(child_definition, update_child_root),
         {:ok, new_parent_definition} <-
           insert(parent_definition, new_child_definition, parent_id) do
      Acc.put_statechart_def(env, new_parent_definition)
    end

    :ok
  end

  def __subchart__(_build_step, _env, _name, _module) do
    :ok
  end

  #####################################
  # HELPERS

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
  defp fetch_definition!(module, line_number) do
    case Chart.fetch_from_module(module) do
      {:ok, chart} ->
        chart

      _ ->
        raise StatechartBuildError,
              "the module #{module} on line #{line_number} does not define a Statechart.Chart.t struct. See `use Statechart`"
    end
  end
end

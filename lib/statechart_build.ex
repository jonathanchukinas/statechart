defmodule Statechart.Build do
  use TypedStruct
  use Statechart.Definition
  alias __MODULE__
  alias Statechart.Build.Acc
  alias Statechart.Event
  alias Statechart.Metadata
  alias Statechart.MetadataAccess

  @build_steps ~w/
    insert_nodes
    insert_transitions
    /a

  @type build_step :: :insert_nodes | :insert_transitions

  #####################################
  # DEFCHART

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
      @spec definition() :: t
      def definition, do: unquote(Macro.escape(statechart_def))
    end
  end

  @doc false
  defmacro __context_type__(_type) do
    # case type do
    case nil do
      nil ->
        quote do
          @type t :: Definition.t()
        end

        # type ->
        #   quote do
        #     @type t :: Definition.t(unquote(type))
        #   end
    end
  end

  @doc false
  @spec __defchart_enter__(Macro.Env.t()) :: :ok
  def __defchart_enter__(%Macro.Env{} = env) do
    if Module.has_attribute?(env.module, :__sc_defchart__) do
      raise StatechartCompileError, "Only one defchart call may be made per module"
    end

    statechart_def = Definition.from_env(env)
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
    new_node = Node.new(name, metadata: Metadata.from_env(env))
    old_definition = Acc.statechart_def(env)
    parent_id = Acc.current_id(env)

    with [] <- local_nodes_by_name(old_definition, name),
         {:ok, new_definition} <- insert(old_definition, new_node, parent_id),
         {:ok, new_node_id} <- fetch_node_id_by_state(new_definition, name) do
      env
      |> Acc.put_statechart_def(new_definition)
      |> Acc.put_current_id(new_node_id)
    else
      [node_with_same_name | _tail] ->
        {:ok, line_number} = MetadataAccess.fetch_line_number(node_with_same_name)
        msg = "A state with name #{name} was already declared on line #{line_number}"
        raise StatechartCompileError, msg
    end

    :ok
  end

  def __defstate_enter__(_build_step, _env, _name) do
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

  defmacro event >>> destination_node_name do
    if :ok != Event.validate(event) do
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

    with :ok <- Event.validate(event),
         {:ok, destination_node} <- fetch_node_by_name(statechart_def, destination_node_name),
         update_fn =
           &Node.put_transition(&1, event, Node.id(destination_node), Metadata.from_env(env)),
         {:ok, statechart_def} <-
           update_node_by_id(statechart_def, node_id, update_fn) do
      Acc.put_statechart_def(env, statechart_def)
      :ok
    else
      {:error, error} -> raise to_string(error)
    end
  end

  def __transition__(_build_step, _env, _event, _destination_node_name) do
    :ok
  end
end

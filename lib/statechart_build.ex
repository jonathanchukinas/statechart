defmodule Statechart.Build do
  alias __MODULE__
  alias Statechart.Definition
  alias Statechart.Definition.Query
  alias Statechart.Event
  alias Statechart.Metadata
  alias Statechart.Node
  alias Statechart.Tree

  @build_steps ~w/
    insert_nodes
    insert_transitions
    /a

  #####################################
  # DEFCHART

  defmacro defchart(opts \\ [], do: block) do
    ast = Statechart.Build.__defchart__(block, opts)

    quote do
      (fn -> unquote(ast) end).()
    end
  end

  @doc false
  def __defchart__(block, opts) do
    quote do
      Build.__defchart_enter__(__ENV__)

      import Build

      # TODO context type rename
      Build.__type__(unquote(opts[:type]))

      for build_step <- unquote(@build_steps) do
        @__sc_build_step__ build_step
        unquote(block)
      end

      @spec definition() :: t
      def definition, do: @__sc_acc__.statechart_def

      Build.__defchart_exit__(__ENV__)
    end
  end

  @doc false
  defmacro __type__(_type) do
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
  def __defchart_enter__(%Macro.Env{} = env) do
    %Definition{} = statechart_def = Definition.from_env(env)

    Module.register_attribute(env.module, :__sc_build_step__, [])

    # TODO this should be a struct. Build.Acc?
    Module.put_attribute(env.module, :__sc_acc__, %{
      statechart_def: statechart_def,
      current_node_id: Tree.max_node_id(statechart_def)
    })
  end

  @doc false
  def __defchart_exit__(env) do
    Module.delete_attribute(env.module, :__sc_build_step__)
    Module.delete_attribute(env.module, :__sc_acc__)
  end

  #####################################
  # DEFSTATE

  # TODO add test for testing that node's block is optional
  @doc """
  Create a statechart node.

  `name` must be an atom and must be unique amongst nodes defined in this
  module's statechart.
  The way to have multiple nodes sharing the same name is to define statechart
  partials in separate module and then insert those partials into a parent statechart.
  """
  defmacro defstate(name, do: block) do
    quote do
      Build.__defstate_enter__(@__sc_build_step__, @__sc_acc__, __ENV__, unquote(name))
      unquote(block)
      Build.__defstate_exit__(@__sc_build_step__, @__sc_acc__, __ENV__)
    end
  end

  @doc false
  def __defstate_enter__(
        :insert_nodes = _build_step,
        %{statechart_def: definition, current_node_id: parent_id} = acc,
        env,
        name
      ) do
    %Node{} = new_node = Node.new(name, metadata: Metadata.from_env(env))
    {:ok, updated_statechart_def} = Tree.insert(definition, new_node, parent_id)
    # TODO wrap this update in function
    Module.put_attribute(env.module, :__sc_acc__, %{acc | statechart_def: updated_statechart_def})
  end

  def __defstate_enter__(_build_step, _acc, _env, _name) do
    nil
  end

  @doc false
  def __defstate_exit__(_build_step, %{statechart_def: statechart_def} = acc, env) do
    with {:ok, current_node} <-
           Statechart.Definition.Query.fetch_node_by_metadata(
             statechart_def,
             Metadata.from_env(env)
           ),
         {:ok, parent_node} <- Tree.fetch_parent_by_id(statechart_def, Node.id(current_node)),
         parent_id <- Node.id(parent_node) do
      Module.put_attribute(env.module, :__sc_acc__, %{acc | current_node_id: parent_id})
    else
      {:error, _type} -> raise "whoopsie!"
    end

    # set current node_id to this node's parent
    # TODO add function/macro for retrieving node_id via its metadata
    # TODO on enter, get all nodes defined in this module and check that they don't have they the same name.
    # raise if any are found. Include that nodes's line# in the error message.
    # TODO create a StatechartCompileError exception. I'd use this any time a predictable compile error occurs.
    nil
  end

  #####################################
  # TRANSITION

  defmacro event >>> destination_node_name do
    # TODO check that event is an atom or a module
    quote bind_quoted: [event: event, destination_node_name: destination_node_name] do
      Build.__transition__(
        @__sc_build_step__,
        @__sc_acc__,
        __ENV__,
        event,
        destination_node_name
      )
    end
  end

  def __transition__(
        :insert_transitions,
        # TODO make this a struct I can just use dot notation on
        %{statechart_def: statechart_def, current_node_id: node_id} = acc,
        env,
        event,
        destination_node_name
      ) do
    with :ok <- Event.validate(event),
         {:ok, destination_node} <-
           Query.fetch_node_by_name(statechart_def, destination_node_name),
         update_fn = &Node.put_transition(&1, event, Node.id(destination_node)),
         {:ok, statechart_def} <- Tree.update_node_by_id(statechart_def, node_id, update_fn) do
      # TODO can I clean this up? make a macro for it?
      Module.put_attribute(env.module, :__sc_acc__, %{acc | statechart_def: statechart_def})
    else
      # TODO implement
      {:error, error} -> raise error
    end

    nil
  end

  def __transition__(_build_step, _acc, _env, _event, _destination_node_name) do
    nil
  end
end

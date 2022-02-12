defmodule Statechart.Build do
  use TypedStruct
  alias __MODULE__
  alias Statechart.Build.Acc
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
    statechart_def = Definition.from_env(env)
    Module.register_attribute(env.module, :__sc_build_step__, [])
    Acc.put_new(env, statechart_def)
  end

  @doc false
  def __defchart_exit__(env) do
    Module.delete_attribute(env.module, :__sc_build_step__)
  end

  #####################################
  # DEFSTATE

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
  def __defstate_enter__(:insert_nodes = _build_step, env, name) do
    new_node = Node.new(name, metadata: Metadata.from_env(env))

    parent_id = Acc.current_id(env)

    {:ok, updated_statechart_def} =
      env
      |> Acc.statechart_def()
      |> Tree.insert(new_node, parent_id)

    Acc.put_statechart_def(env, updated_statechart_def)
  end

  def __defstate_enter__(_build_step, _env, _name) do
    nil
  end

  @doc false
  def __defstate_exit__(env) do
    statechart_def = Acc.statechart_def(env)

    with {:ok, current_node} <-
           Statechart.Definition.Query.fetch_node_by_metadata(
             statechart_def,
             Metadata.from_env(env)
           ),
         {:ok, parent_node} <- Tree.fetch_parent_by_id(statechart_def, Node.id(current_node)),
         parent_id <- Node.id(parent_node) do
      Acc.put_current_id(env, parent_id)
    else
      # TODO implement
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
      Build.__transition__(@__sc_build_step__, __ENV__, event, destination_node_name)
    end
  end

  def __transition__(:insert_transitions, env, event, destination_node_name) do
    statechart_def = Acc.statechart_def(env)
    node_id = Acc.current_id(env)

    with :ok <- Event.validate(event),
         {:ok, destination_node} <-
           Query.fetch_node_by_name(statechart_def, destination_node_name),
         update_fn = &Node.put_transition(&1, event, Node.id(destination_node)),
         {:ok, statechart_def} <- Tree.update_node_by_id(statechart_def, node_id, update_fn) do
      Acc.put_statechart_def(env, statechart_def)
    else
      {:error, error} ->
        # TODO Test that this raises on the correct line
        raise error
        # {:error, error} ->
        #   msg =
        #     case error do
        #       :ambiguous_name -> "neitsornatorsa"
        #       :name_not_found -> "neitsornatorsa"
        #       :id_not_found -> "neitsornatorsa"
        #     end

        #   raise msg
    end
  end

  def __transition__(_build_step, _env, _event, _destination_node_name) do
    nil
  end
end

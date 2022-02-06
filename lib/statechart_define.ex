defmodule Statechart.Define do
  alias __MODULE__
  alias Statechart.Node
  alias Statechart.Definition
  alias Statechart.Tree

  #####################################
  # DEFCHART

  defmacro defchart(opts \\ [], do: block) do
    ast = Statechart.Define.__defchart__(block, opts)

    quote do
      (fn -> unquote(ast) end).()
    end
  end

  @doc false
  def __defchart__(block, opts) do
    quote do
      Define.__defchart_enter__(__ENV__)

      import Statechart.Define

      Define.__type__(unquote(opts[:type]))

      unquote(block)

      @spec definition() :: t
      def definition, do: @__sc_acc__.statechart_def

      Define.__defchart_exit__(__ENV__)
    end
  end

  @doc false
  defmacro __type__(type) do
    case type do
      nil ->
        quote do
          @type t :: Definition.t()
        end

      type ->
        quote do
          @type t :: Definition.t(unquote(type))
        end
    end
  end

  @doc false
  def __defchart_enter__(env) do
    # TODO move the context to the Interpreter
    %Definition{} = statechart_def = Definition.new("hi!", metadata: metadata(env))
    Module.put_attribute(env.module, :__sc_build_step__, :insert_nodes)

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
      Define.__defstate_enter__(@__sc_build_step__, @__sc_acc__, __ENV__, unquote(name))
      unquote(block)
      Define.__defstate_exit__(@__sc_build_step__, @__sc_acc__, __ENV__)
    end
  end

  @doc false
  def __defstate_enter__(
        :insert_nodes = _build_step,
        %{statechart_def: definition, current_node_id: parent_id} = acc,
        env,
        name
      ) do
    %Node{} = new_node = Node.new(name, metadata: metadata(env))
    {:ok, updated_statechart_def} = Tree.insert(definition, new_node, parent_id)
    # TODO wrap this update in function
    Module.put_attribute(env.module, :__sc_acc__, %{acc | statechart_def: updated_statechart_def})
  end

  @doc false
  def __defstate_exit__(_build_step, %{statechart_def: statechart_def} = acc, env) do
    with {:ok, current_node} <-
           Statechart.Definition.Query.fetch_node_by_metadata(statechart_def, metadata(env)),
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
  # HELPERS

  defp metadata(caller), do: Map.take(caller, [:line, :module])
end

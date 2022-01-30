defmodule Statechart.Define do
  alias __MODULE__
  alias Statechart.Node
  alias Statechart.Definition
  alias Statechart.Tree

  #####################################
  # DEFCHART

  defmacro defchart(opts \\ [], do: block) do
    opts = Keyword.put(opts, :metadata, Macro.escape(metadata(__CALLER__)))
    ast = Statechart.Define.__defchart__(block, opts)

    quote do
      # Module.register_attribute(__MODULE__, :__sc_current_id__)
      (fn -> unquote(ast) end).()
    end
  end

  @doc false
  def __defchart__(block, opts) do
    quote do
      Define.__defchart_enter__(__ENV__)

      import Statechart.Define
      @__sc_chart__ Definition.new("hi!", unquote(opts))
      # TODO dynamically set the suubtype
      @type t :: Definition.t(String.t())

      unquote(block)

      @spec definition() :: t
      def definition, do: @__sc_chart__

      Define.__defchart_exit__(__ENV__)
    end
  end

  @doc false
  def __defchart_enter__(env) do
    Module.put_attribute(env.module, :__sc_build_step__, :insert_nodes)
    Module.put_attribute(env.module, :__sc_current_id__, 1)
    Module.register_attribute(env.module, :__sc_chart__, [])
  end

  @doc false
  def __defchart_exit__(_env) do
    # TODO delete module attrs
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
      Define.__defstate_enter__(@__sc_build_step__, unquote(name), __ENV__)
      unquote(block)
      Define.__defstate_exit__(@__sc_build_step__, __ENV__)
    end
  end

  @doc false
  def __defstate_enter__(:insert_nodes = _build_step, name, env) do
    # TODO replace the multiple __sc...__ module attrs with a single __sc__ map
    # This makes more sense since these aren't accumulating attrs.
    # It gets annoying doing all this read/writing from/to module attrs.
    # Do it once for each read and write. use a map or, better yet, a struct
    %Definition{} = definition = Module.get_attribute(env.module, :__sc_chart__)
    parent_id = Module.get_attribute(env.module, :__sc_current_id__)
    node_opts = [metadata: metadata(env)]
    %Node{} = node = Node.new(name, node_opts)
    {:ok, definition} = Tree.insert(definition, node, parent_id)
    Module.put_attribute(env.module, :__sc_chart__, definition)
  end

  @doc false
  def __defstate_exit__(_build_step, _env) do
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

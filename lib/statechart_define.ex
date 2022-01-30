defmodule Statechart.Define do
  alias __MODULE__
  alias Statechart.Node
  alias Statechart.Definition
  alias Statechart.Tree

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
      @__sc_current_id__ 1
      import Statechart.Define
      @__sc_chart__ Definition.new("hi!", unquote(opts))
      unquote(block)

      # TODO temp
      @type t :: Definition.t(String.t())
      # Statechart.Define.__definition_getter__(0)

      @spec definition() :: t
      def definition, do: @__sc_chart__
    end
  end

  defmacro defstate(name) do
    quote do: Define.__defstate__(unquote(name), __ENV__)
  end

  @doc false
  def __defstate__(name, env) do
    definition = Module.get_attribute(env.module, :__sc_chart__)
    parent_id = Module.get_attribute(env.module, :__sc_current_id__)
    node_opts = [metadata: metadata(env)]
    node = Node.new(name, node_opts)
    {:ok, definition} = Tree.insert(definition, node, parent_id)
    Module.get_attribute(env.module, :__sc_chart__, definition)
  end

  defp metadata(caller), do: Map.take(caller, [:line, :module])
end

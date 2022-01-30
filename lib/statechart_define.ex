defmodule Statechart.Define do
  defmacro defchart(opts \\ [], do: block) do
    metadata = Map.take(__CALLER__, [:line, :module])
    opts = Keyword.put(opts, :metadata, Macro.escape(metadata))
    ast = Statechart.Define.__defchart__(block, opts)
    quote do: (fn -> unquote(ast) end).()
  end

  @doc false
  def __defchart__(block, opts) do
    quote do
      import Statechart.Define
      unquote(block)
      # TODO temp
      @__statechart_definition__ Statechart.Definition.new("hi!", unquote(opts))
      @type t :: Statechart.Definition.t(String.t())
      # Statechart.Define.__definition_getter__(0)
      @spec definition() :: t
      def definition, do: @__statechart_definition__
    end
  end
end

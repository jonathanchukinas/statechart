defmodule Statechart.Define do
  defmacro defchart(opts \\ [], do: block) do
    ast = Statechart.Define.__defchart__(block, opts)
    quote do: (fn -> unquote(ast) end).()
  end

  @doc false
  def __defchart__(block, _opts) do
    quote do
      import Statechart.Define
      unquote(block)
    end
  end
end

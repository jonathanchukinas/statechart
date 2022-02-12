defmodule Statechart do
  @moduledoc """
  As convention, use this module in a module that ends in Statechart
  """
  defmacro __using__(_opts) do
    quote do
      import Statechart.Build, only: [defchart: 1, defchart: 2]
    end
  end
end

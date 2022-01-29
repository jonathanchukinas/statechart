defmodule Statechart.Define do
  defmacro __using__(_opts) do
    quote do
      alias Statechart.Define
      import Define
    end
  end
end

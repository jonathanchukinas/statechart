defmodule Statechart do
  @moduledoc """
  TODO
  - add link to statechart paper

  You first build a statechart via `use Statechart, :chart` and
  the `Statechart.Build` macros.

  You then have two options for doing stuff with a statechart.
  You can do one-off transitions using `Statechart.Transitions`,
  but the more common way is to create a `Statechart.Interpreter`,
  which isn't much more than a wrapper around `Statechart.Transitions`.
  It makes it more convenient to pipe your statechart, for example.

  As convention, use this module in a module that ends in Statechart
  """
  defmacro __using__(_opts) do
    quote do
      import Statechart.Build, only: [defchart: 1, defchart: 2]
    end
  end
end

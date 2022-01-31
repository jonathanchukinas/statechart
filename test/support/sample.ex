# TODO change file name
defmodule Statechart.TestSupport.SampleDefinition do
  use Statechart.Definition

  # TODO Tests
  # Ensure only one defchart can be declared per module
  defchart type: String.t() do
    defstate :on do
    end
  end
end

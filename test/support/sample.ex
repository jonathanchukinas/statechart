# TODO change file name
defmodule Statechart.TestSupport.SampleDefinition do
  use Statechart.Definition

  # TODO Tests
  # Ensure only one defchart can be declared per module
  defchart do
    defstate :on
  end
end

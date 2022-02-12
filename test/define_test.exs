defmodule Statechart.BuildTest do
  use ExUnit.Case
  # use ExUnitProperties
  # alias Statechart.Node
  # alias Statechart.Tree
  alias Statechart.Definition
  alias Statechart.TestSupport.SampleDefinition

  test "defchart/2 injects a definition/0 function into caller" do
    assert {:definition, 0} in SampleDefinition.__info__(:functions)
    assert match?(%Definition{}, SampleDefinition.definition())
  end
end

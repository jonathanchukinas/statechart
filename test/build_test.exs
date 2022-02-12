defmodule Statechart.BuildTest do
  use ExUnit.Case
  # use ExUnitProperties
  # alias Statechart.Node
  # alias Statechart.Tree
  alias Statechart.Definition
  alias Statechart.TestSupport.SampleDefinition

  describe "defchart/2" do
    test "injects a definition/0 function into caller" do
      assert {:definition, 0} in SampleDefinition.__info__(:functions)
      assert match?(%Definition{}, SampleDefinition.definition())
    end
  end

  describe "defstate/2" do
    test "do-block is optional"

    # This should test for the line number
    # Should give suggestions for matching names ("Did you mean ...?")
    test "raises a StatechartCompileError on invalid state names"
  end

  describe ">>>/2" do
    # This should test for the line number
    test "raises a StatechartCompileError on invalid event names"
  end
end

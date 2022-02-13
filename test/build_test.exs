defmodule Statechart.BuildTest do
  use ExUnit.Case
  # use ExUnitProperties
  # alias Statechart.Node
  # alias Statechart.Tree
  use Statechart.Definition

  alias Statechart.TestSupport.SampleDefinition

  defmodule Sample do
    use Statechart

    defchart do
      defstate :a do
        defstate :b do
          # TODO Can I make this caps case?
          :goto_d >>> :d

          defstate :c do
            defstate :d do
            end
          end
        end
      end
    end
  end

  describe "defchart/2" do
    test "injects a definition/0 function into caller" do
      assert {:definition, 0} in SampleDefinition.__info__(:functions)
      assert match?(%Definition{}, SampleDefinition.definition())
    end
  end

  describe "defstate/2" do
    test "correctly nests states" do
      # TODO rename to fetch_... and return tuple?
      definition = Definition.from_module(Sample)
      {:ok, 5 = d_node_id} = fetch_node_id_by_state(definition, :d)
      {:ok, d_path} = fetch_path_by_id(definition, d_node_id)
      assert length(d_path) == 5
      d_path_as_atoms = Enum.map(d_path, &Node.name/1)
      assert d_path_as_atoms == ~w/root a b c d/a
    end

    test "do-block is optional"

    # This should test for the line number
    # Should give suggestions for matching names ("Did you mean ...?")
    test "raises a StatechartCompileError on invalid state names"
  end

  describe ">>>/2" do
    # This should test for the line number
    test "raises a StatechartCompileError on invalid event names"

    test "raises a StatechartCompileError if event already exists for this event (event itself, its ancestors, or descendents)"
  end
end

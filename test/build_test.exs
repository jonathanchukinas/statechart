defmodule Statechart.BuildTest do
  use ExUnit.Case
  use Statechart.Definition

  describe "defchart/2" do
    defmodule Sample do
      use Statechart

      defchart do
        defstate :on, do: :flip >>> :off

        defstate :off do
          :flip >>> :on
        end
      end
    end

    test "only one statechart is allowed per module"

    test "injects a definition/0 function into caller" do
      assert {:definition, 0} in Sample.__info__(:functions)
      assert match?(%Definition{}, Sample.definition())
    end
  end

  describe "defstate/2" do
    defmodule Sample do
      use Statechart

      defchart do
        defstate :a do
          defstate :b do
            :GOTO_D >>> :d

            defstate :c do
              defstate :d do
              end
            end
          end
        end
      end
    end

    test "correctly nests states" do
      {:ok, definition} = Definition.fetch_from_module(Sample)
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

    test "raises on duplicate **local** state name"
  end

  describe "subchart/2" do
    test "successfully inserts a sub-chart into a parent chart"
  end

  describe ">>>/2" do
    # This should test for the line number
    test "raises a StatechartCompileError on invalid event names"

    test "raises a StatechartCompileError if event already exists for this event (event itself, its ancestors, or descendents)"
  end
end

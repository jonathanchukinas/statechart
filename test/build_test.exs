defmodule Statechart.BuildTest do
  use ExUnit.Case
  use Statechart.Definition

  describe "defchart/2" do
    # defmodule Sample do
    #   use Statechart

    #   defchart do
    #     defstate :on, do: :flip >>> :off

    #     defstate :off do
    #       :flip >>> :on
    #     end
    #   end
    # end

    test "raises if defchart was already called in this module" do
      assert_raise StatechartCompileError, ~r/Only one defchart/, fn ->
        defmodule InvalidDoubleDefchart do
          use Statechart
          defchart do: nil
          defchart do: nil
        end
      end
    end

    test "injects a definition/0 function into caller" do
      defmodule SingleDefchart do
        use Statechart
        defchart do: nil
      end

      assert {:definition, 0} in SingleDefchart.__info__(:functions)
      assert match?(%Definition{}, SingleDefchart.definition())
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

    test "raises on duplicate **local** state name" do
      assert_raise StatechartCompileError, fn ->
        defmodule DuplicateLocalNodeName do
          use Statechart

          defchart do
            defstate :on
            defstate :on
          end
        end
      end
    end
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

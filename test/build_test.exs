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

  describe "defstate/1" do
    test "do-block is optional" do
      defmodule DefstateWithNoDoBlock do
        use Statechart

        defchart do
          defstate :hello
        end
      end
    end
  end

  describe "defstate/2" do
    test "correctly nests states" do
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

      {:ok, definition} = Definition.fetch_from_module(Sample)
      {:ok, 5 = d_node_id} = fetch_node_id_by_state(definition, :d)
      {:ok, d_path} = fetch_path_by_id(definition, d_node_id)
      assert length(d_path) == 5
      d_path_as_atoms = Enum.map(d_path, &Node.name/1)
      assert d_path_as_atoms == ~w/root a b c d/a
    end

    test "raises a StatechartCompileError on non-atom state names" do
      assert_raise StatechartCompileError, ~r/expected defstate arg1 to be an atom/, fn ->
        defmodule InvalidStateName do
          use Statechart
          defchart do: defstate(%{})
        end
      end
    end

    test "raises on duplicate **local** state name" do
      assert_raise StatechartCompileError, ~r/was already declared on line/, fn ->
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
    test "successfully inserts a sub-chart into a parent chart" do
      defmodule SubChart do
        use Statechart

        defchart do
          defstate :on
          defstate :off
        end
      end

      defmodule MainChart do
        use Statechart

        defchart do
          defstate :flarb
          subchart(:flazzl, SubChart)
        end
      end

      {:ok, definition} = Definition.fetch_from_module(MainChart)
      assert length(fetch_nodes!(definition)) == 5
      assert {:ok, 3} = fetch_node_id_by_state(definition, :flazzl)
    end
  end

  # This should test for the line number
  # Should give suggestions for matching names ("Did you mean ...?")
  describe ">>>/2" do
    # This should test for the line number
    test "raises a StatechartCompileError on invalid event names"

    test "raises if one of node's ancestors already has a transition with this event" do
      # TODO rename StatechartBuildError ?

      assert_raise StatechartCompileError, ~r/events must be unique/, fn ->
        defmodule AmbiguousEventInAncestor do
          use Statechart

          defchart do
            :AMBIGUOUS_EVENT >>> :b

            defstate :a do
              :AMBIGUOUS_EVENT >>> :c
            end

            defstate :b
            defstate :c
          end
        end
      end
    end
  end
end

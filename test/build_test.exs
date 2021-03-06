defmodule Statechart.BuildTest do
  use ExUnit.Case
  use Statechart.Chart

  use Statechart

  # BuildTest chart:
  defchart do
  end

  describe "defchart/2" do
    test "add opt to defchart to create a new module" do
      use Statechart

      defchart module: ChartDefinedViaOpts do
        nil
      end
    end

    test "raises if defchart was already called in this module" do
      assert_raise StatechartBuildError, ~r/Only one defchart/, fn ->
        defmodule InvalidDoubleDefchart do
          use Statechart
          defchart do: nil
          defchart do: nil
        end
      end
    end
  end

  describe "defstate/1 or /2" do
    test "raises if called before defchart block" do
      assert_raise StatechartBuildError, ~r/must be called inside/, fn ->
        defmodule DefstateOutOfScopeBefore do
          import Statechart.Build
          defstate :naughty
        end
      end
    end

    test "raises if called after a defchart block" do
      assert_raise StatechartBuildError, ~r/must be called inside/, fn ->
        defmodule DefstateOutOfScopeAfter do
          use Statechart

          defchart do
          end

          import Statechart.Build
          defstate :naughty
        end
      end
    end

    test "raises if default opt if given to a leaf node" do
      assert_raise StatechartBuildError, ~r/cannot assign a default to a leaf/, fn ->
        defmodule DefaultPassedToLeafNode do
          use Statechart

          defchart do
            defstate :a, default: :b do
            end

            defstate :b
          end
        end
      end
    end

    test "raises if default target is not a descendent" do
      assert_raise StatechartBuildError, ~r/must be a descendent/, fn ->
        defmodule DefaultIsNotDescendent do
          use Statechart

          defchart do
            defstate :a, default: :b do
              defstate :c
            end

            defstate :b
          end
        end
      end
    end

    test "do-block is optional" do
      defmodule DefstateWithNoDoBlock do
        use Statechart

        defchart do
          defstate :hello
        end
      end
    end

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

      {:ok, chart} = Chart.fetch(Sample)
      {:ok, 5 = d_node_id} = fetch_id_by_state(chart, :d)
      {:ok, d_path} = fetch_path_nodes_by_id(chart, d_node_id)
      assert length(d_path) == 5
      d_path_as_atoms = Enum.map(d_path, &Node.name/1)
      assert d_path_as_atoms == ~w/root a b c d/a
    end

    test "raises a StatechartBuildError on non-atom state names" do
      assert_raise StatechartBuildError, ~r/expected defstate arg1 to be an atom/, fn ->
        defmodule InvalidStateName do
          use Statechart
          defchart do: defstate(%{})
        end
      end
    end

    test "raises on duplicate **local** state name" do
      assert_raise StatechartBuildError, ~r/was already declared on line/, fn ->
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
          subchart :flazzl, SubChart
        end
      end

      {:ok, chart} = Chart.fetch(MainChart)
      assert length(fetch_nodes!(chart)) == 5
      assert {:ok, 3} = fetch_id_by_state(chart, :flazzl)
    end
  end

  # This should test for the line number
  # Should give suggestions for matching names ("Did you mean ...?")
  describe "transition/2 & >>>/2" do
    test "an event targetting a branch node must provides a default path to a leaf node"

    test "raises if event targets a root that doesn't resolve"
    # This should test for the line number
    test "raises a StatechartBuildError on invalid event names"
    test "raises if target does not resolve to a leaf node"
    test "raises if target does not exist"

    test "raises if one of node's ancestors already has a transition with this event" do
      assert_raise StatechartBuildError, ~r/events must be unique/, fn ->
        defmodule AmbiguousEventInAncestor do
          use Statechart

          defchart do
            transition(:AMBIGUOUS_EVENT, :b)

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

  describe "on/1" do
    test "raises on invalid input"
  end
end

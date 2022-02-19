# TODO test for e.g. defstate called out of place

defmodule Statechart.BuildTest do
  use ExUnit.Case
  use Statechart.Chart

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
      assert_raise StatechartBuildError, ~r/Only one defchart/, fn ->
        defmodule InvalidDoubleDefchart do
          use Statechart
          defchart do: nil
          defchart do: nil
        end
      end
    end

    # TODO rename this test
    test "injects a definition/0 function into caller" do
      defmodule SingleDefchart do
        use Statechart
        defchart do: nil
      end

      # TODO Investigate all other __chart__ calls
      assert {:ok, %Chart{}} = Chart.fetch_from_module(SingleDefchart)
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

      {:ok, chart} = Chart.fetch_from_module(Sample)
      {:ok, 5 = d_node_id} = fetch_id_by_state(chart, :d)
      {:ok, d_path} = fetch_path_by_id(chart, d_node_id)
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
          subchart(:flazzl, SubChart)
        end
      end

      {:ok, chart} = Chart.fetch_from_module(MainChart)
      assert length(fetch_nodes!(chart)) == 5
      assert {:ok, 3} = fetch_id_by_state(chart, :flazzl)
    end
  end

  # This should test for the line number
  # Should give suggestions for matching names ("Did you mean ...?")
  describe "transition/2 & >>>/2" do
    # This should test for the line number
    test "raises a StatechartBuildError on invalid event names"

    # TODO test for self, path, and ancestors
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
end

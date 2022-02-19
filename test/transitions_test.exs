defmodule Statechart.TransitionsTest do
  use ExUnit.Case
  use Statechart.Chart
  alias Statechart.Transitions

  defmodule Sample do
    use Statechart

    defchart context_type: String.t() do
      defstate :a do
        defstate :b do
          :GOTO_G >>> :g

          defstate :c do
            defstate :d do
            end
          end
        end
      end

      defstate :e do
        defstate :f do
          defstate :g do
          end
        end
      end
    end
  end

  describe "fetch_transition_path/3" do
    test "returns a list of exit/enter node tuples" do
      {:ok, chart} = Chart.fetch_from_module(Sample)
      {:ok, transition_path} = Transitions.fetch_transition_path(chart, :d, :GOTO_G)

      transition_path_atoms =
        for {direction, node} <- transition_path, do: {direction, Node.name(node)}

      assert transition_path_atoms == [
               {:exit, :d},
               {:exit, :c},
               {:exit, :b},
               {:exit, :a},
               {:enter, :e},
               {:enter, :f},
               {:enter, :g}
             ]
    end
  end

  test "fetch_target_id/?"
  test "an event targetting a branch node must provides a default path to a leaf node"

  test "the builder raises on events that target a branch node that doesn't have a default path to a leaf node"

  test "on_exit events fire"
  test "on_enter events fire"
  test "root can have a default"

  describe "Events targeting a branch node" do
    defmodule DefaultsTest do
      use Statechart

      defchart do
        :GOTO_BRANCH_WITH_DEFAULT >>> :branch_with_default
        :GOTO_BRANCH_NO_DEFAULT >>> :branch_no_default

        defstate :branch_with_default, default: :c do
          defstate :c
        end

        defstate :branch_no_default do
          defstate :e
        end
      end
    end

    test "will cause travel to a default leaf node"

    test "fail: will return an error tuple if the branch node has no default leaf node" do
      Transitions.transition(DefaultsTest, :c, :GOTO_D)
    end
  end

  # TODO is this already tested somewhere else?
  # TODO what to call such an event? invalid?
  test "fail: an event not in current path returns an error tuple"

  describe "transition/3" do
    defmodule SimpleToggle do
      use Statechart

      defchart do
        :GLOBAL_TURN_ON >>> :on
        :GLOBAL_TURN_OFF >>> :off

        defstate :on do
          :TOGGLE >>> :off
          :LOCAL_TURN_OFF >>> :off
        end

        defstate :off do
          :TOGGLE >>> :on
          :LOCAL_TURN_ON >>> :on
        end
      end
    end

    test "a transition registered directly on current node allows a transition" do
      assert {:ok, :off} = Transitions.transition(SimpleToggle, :on, :TOGGLE)
    end

    test "a non-existent event returns an error tuple" do
      assert {:error, :event_not_found} =
               Transitions.transition(SimpleToggle, :on, :MISSPELLED_TOGGLE)
    end

    test "a transition that doesn't apply to current returns an error tuple" do
      assert {:error, :event_not_found} =
               Transitions.transition(SimpleToggle, :on, :LOCAL_TURN_ON)
    end

    test "a transition registered earlier in a node's path still allows an event" do
      assert {:ok, :off} = Transitions.transition(SimpleToggle, :on, :GLOBAL_TURN_OFF)
      assert {:ok, :on} = Transitions.transition(SimpleToggle, :on, :GLOBAL_TURN_ON)
      assert {:ok, :on} = Transitions.transition(SimpleToggle, :off, :GLOBAL_TURN_ON)
      assert {:ok, :off} = Transitions.transition(SimpleToggle, :off, :GLOBAL_TURN_OFF)
    end
  end
end

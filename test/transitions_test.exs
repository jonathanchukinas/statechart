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
      {:ok, chart} = Chart.fetch(Sample)
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

  describe "defaults" do
    defmodule DefaultsTest do
      use Statechart

      defchart do
        :GOTO_BRANCH_WITH_DEFAULT >>> :branch_with_default
        :GOTO_BRANCH_NO_DEFAULT >>> :branch_no_default

        # TODO do i already test for raising when builder tries to create a transition with no resolution?
        :GOTO_BRANCH_NO_DEFAULT_BUT_NO_RESOLUTION >>> :branch_with_default_but_no_resolution

        defstate :branch_with_default_but_no_resolution, default: :branch_no_default do
          defstate :branch_no_default do
            defstate :a
          end
        end

        defstate :branch_with_default, default: :b do
          defstate :b
        end
      end
    end

    test "will cause travel to a default leaf node" do
      assert {:ok, :b} = Transitions.transition(DefaultsTest, :a, :GOTO_BRANCH_WITH_DEFAULT)
    end

    test "return error tuple when transitioning to a branch node that has a default that doesn't resolve to a leaf node" do
      assert {:error, :no_default_leaf} =
               Transitions.transition(DefaultsTest, :b, :GOTO_BRANCH_NO_DEFAULT_BUT_NO_RESOLUTION)
    end

    test "fail: will return an error tuple if the branch node has no default leaf node" do
      assert {:error, :no_default_leaf} =
               Transitions.transition(DefaultsTest, :b, :GOTO_BRANCH_NO_DEFAULT)
    end
  end
end

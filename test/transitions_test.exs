defmodule Statechart.TransitionsTest do
  use ExUnit.Case
  use Statechart.Definition
  alias Statechart.Transitions

  defmodule Sample do
    use Statechart

    defchart context_type: String.t() do
      defstate :a do
        defstate :b do
          :goto_g >>> :g

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
      {:ok, definition} = Definition.fetch_from_module(Sample)
      # TODO rename all events to be uppercase
      {:ok, transition_path} = Transitions.fetch_transition_path(definition, :d, :goto_g)

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

  # TODO rename Definition -> Chart
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

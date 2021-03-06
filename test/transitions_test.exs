defmodule Statechart.TransitionsTest do
  use ExUnit.Case
  use Statechart.Chart
  alias Statechart.Transitions

  defmodule Sample do
    use Statechart

    defchart do
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

    test "transitioning from a non-unique state name will raise?" do
      defmodule NonUniqueState do
        defmodule SubchartWithRepeatName do
          # TODO move this up?
          use Statechart

          defchart do
            defstate :non_unique_name
          end
        end

        use Statechart

        defchart do
          :SOME_EVENT >>> :bar
          defstate :bar
          defstate :non_unique_name
          subchart(:foo, SubchartWithRepeatName)
        end
      end

      assert {:error, :ambiguous_state_name} =
               Transitions.transition(NonUniqueState, :non_unique_name, :SOME_EVENT)
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

    test "root can have a default" do
      defmodule RootHasDefault do
        use Statechart

        defchart default: :foo do
          :GOTO_ROOT >>> :root
          defstate :foo
        end
      end

      assert {:ok, :foo} = Transitions.transition(RootHasDefault, :foo, :GOTO_ROOT)
    end
  end

  describe "on_exit and on_exit" do
    test "for a subchart root having actions declared at both the subchart and parent levels" do
      defmodule SubchartRootActionsBothLocalAndFromParent do
        use Statechart

        def action_entering_foo(_context), do: IO.puts("action declared by parent!")
        def action_entering_subchart(_context), do: IO.puts("action declared by subchart!")

        defmodule Subchart do
          use Statechart

          defchart do
            on enter: &SubchartRootActionsBothLocalAndFromParent.action_entering_subchart/1
          end
        end

        defchart do
          :GOTO_FOO >>> :foo

          subchart :foo, Subchart do
            on enter: &__MODULE__.action_entering_foo/1
          end

          defstate :bar
        end
      end

      captured_io =
        ExUnit.CaptureIO.capture_io(fn ->
          Transitions.transition(SubchartRootActionsBothLocalAndFromParent, :bar, :GOTO_FOO)
        end)

      assert captured_io =~ "declared by subchart!"
      assert captured_io =~ "declared by parent!"
    end

    test "actions registered on a subchart's root persist after being inserted into a parent chart" do
      defmodule SubchartRootHasActions do
        use Statechart

        def action_entering_subchart(_context), do: IO.puts("entering subchart!")

        defmodule Subchart do
          use Statechart

          defchart do
            on enter: &SubchartRootHasActions.action_entering_subchart/1
          end
        end

        defchart do
          :GOTO_FOO >>> :foo
          subchart :foo, Subchart
          defstate :bar
        end
      end

      captured_io =
        ExUnit.CaptureIO.capture_io(fn ->
          Transitions.transition(SubchartRootHasActions, :bar, :GOTO_FOO)
        end)

      assert captured_io =~ "entering subchart!"
    end

    test "on-exit & -enter actions fire" do
      defmodule OnExitEnterTest do
        use Statechart

        def action_put_a(_context), do: IO.puts("put a")
        def action_put_b(_context), do: IO.puts("put b")

        defchart do
          :GOTO_B >>> :b

          defstate :a do
            on exit: &__MODULE__.action_put_a/1
          end

          defstate :b do
            on enter: &__MODULE__.action_put_b/1
          end
        end
      end

      captured_io =
        ExUnit.CaptureIO.capture_io(fn -> Transitions.transition(OnExitEnterTest, :a, :GOTO_B) end)

      assert captured_io =~ "put a"
      assert captured_io =~ "put b"
    end
  end
end

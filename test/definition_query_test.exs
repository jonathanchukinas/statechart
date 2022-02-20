defmodule Statechart.Chart.QueryTest do
  use ExUnit.Case
  use Statechart.Chart
  alias Statechart.Transition

  describe "fetch_transition/3" do
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

    test "returns ok transition tuple" do
      {:ok, chart} = Chart.fetch(Sample)
      {:ok, 4 = node_id} = fetch_id_by_state(chart, :c)

      assert {:ok, %Transition{}} = fetch_transition(chart, node_id, :GOTO_D)
    end
  end
end

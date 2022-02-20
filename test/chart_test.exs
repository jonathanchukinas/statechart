defmodule Statechart.ChartTest do
  use ExUnit.Case
  use Statechart.Chart

  test "injects a __chart__/0 function into caller" do
    defmodule SingleDefchart do
      use Statechart
      defchart do: nil
    end

    assert {:ok, %Chart{}} = Chart.fetch_from_module(SingleDefchart)
  end
end

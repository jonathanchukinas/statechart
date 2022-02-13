defmodule Statechart.Definition.QueryTest do
  use ExUnit.Case
  use Statechart.Definition
  alias Statechart.Transition

  describe "fetch_transition/3" do
    defmodule Sample do
      use Statechart

      defchart do
        defstate :a do
          defstate :b do
            # TODO Can I make this caps case?
            :goto_d >>> :d

            defstate :c do
              defstate :d do
              end
            end
          end
        end
      end
    end

    test "returns ok transition tuple" do
      definition = Definition.from_module(Sample)
      {:ok, 4 = node_id} = fetch_node_id_by_state(definition, :c)

      assert {:ok, %Transition{}} = fetch_transition(definition, node_id, :goto_d)
    end
  end
end

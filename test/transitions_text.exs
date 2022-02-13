defmodule Statechart.TransitionsTest do
  use ExUnit.Case
  use Statechart.Definition
  alias Statechart.Transitions

  describe "fetch_transition_path/3" do
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

    test "returns a list of exit/enter node tuples" do
      {:ok, transition_path} =
        Sample
        |> Definition.from_module()
        |> Transitions.fetch_transition_path(:d, :goto_g)

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
end

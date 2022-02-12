# TODO change file name
defmodule Statechart.TestSupport.SampleDefinition do
  use Statechart

  # TODO Tests
  # Ensure only one defchart can be declared per module
  # Ensure each node name declared in a module is unique
  # TODO does this context_type belong here?
  defchart context_type: String.t() do
    defstate :on do
      :flip >>> :off
    end

    defstate :off do
      :flip >>> :on
    end
  end
end

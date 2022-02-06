defmodule Statechart.Node.Meta do
  use TypedStruct

  typedstruct do
    field :module, module
    field :line, pos_integer
  end

  def from_env(%Macro.Env{module: module, line: line}) do
    %__MODULE__{
      module: module,
      line: line
    }
  end
end

defmodule Statechart.Metadata do
  @moduledoc """
  For storing module and line data for each tree and node.

  Used for generating clear exception messages and namespacing nodes.
  For example, the user can refer to a node by its name, but we raise an exception
  if that name isn't found among nodes defined in the current module.
  """

  alias __MODULE__
  use Statechart.Util.GetterStruct

  getter_struct do
    field :module, module
    field :line, pos_integer
  end

  @type t_or_nil :: t | nil

  @spec from_env(Macro.Env.t()) :: t
  def from_env(%Macro.Env{module: module, line: line}) do
    %__MODULE__{
      module: module,
      line: line
    }
  end

  #####################################
  # IMPLEMENTATIONS

  defimpl Inspect do
    alias Statechart.Metadata

    def inspect(%Metadata{} = metadata, _opts) do
      "#{metadata.module |> Module.split() |> Enum.at(-1)}:#{metadata.line}"
    end
  end
end

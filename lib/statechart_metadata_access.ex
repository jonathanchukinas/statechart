defmodule Statechart.MetadataAccess do
  @doc """
  must be used within a typedstruct block
  """

  alias Statechart.Metadata
  alias Statechart.Metadata.HasMetadata

  @type t :: HasMetadata.t()

  @spec fetch_module(t) :: {:ok, module} | {:error, :missing_metadata}
  def fetch_module(has_metadata) do
    case HasMetadata.fetch(has_metadata) do
      {:ok, metadata} -> {:ok, Metadata.module(metadata)}
      error -> error
    end
  end
end

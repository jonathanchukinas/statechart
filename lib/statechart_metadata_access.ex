# TODO this should actually be called Metadata
# then Metadata should in turn be called ... ?
# TODO can the various metadata modules be combined back into one file? Should they?
defmodule Statechart.MetadataAccess do
  @doc """
  must be used within a typedstruct block
  """

  alias Statechart.Metadata
  alias Statechart.Metadata.HasMetadata

  @type t :: HasMetadata.t()

  defmacro __using__(_opts) do
    # import TypedStruct, only: [field: 3]
    quote do
      @before_compile {unquote(__MODULE__), :implement_has_metadata}
      field :metadata, Metadata.t(), enforce: false
    end
  end

  @spec fetch_module(t) :: {:ok, module} | {:error, :missing_metadata}
  def fetch_module(has_metadata) do
    case HasMetadata.fetch(has_metadata) do
      {:ok, metadata} -> {:ok, Metadata.module(metadata)}
      error -> error
    end
  end

  # TODO remove?
  def put_from_env(has_metadata, env) do
    metadata = Metadata.from_env(env)
    HasMetadata.put(has_metadata, metadata)
  end
end

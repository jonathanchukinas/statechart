defprotocol Statechart.Metadata.HasMetadata do
  alias Statechart.Metadata

  @spec fetch(t) :: {:ok, Metadata.t()} | {:error, :missing_metadata}
  def fetch(has_metadata)
end

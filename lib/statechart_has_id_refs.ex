defprotocol Statechart.HasIdRefs do
  @moduledoc false
  # When a node or tree is inserted into a tree, its local ids will have be incremented.
  # Any ids smaller that `start_id` will be left alone.

  alias Statechart.Node

  @type id :: pos_integer

  # @spec incr_id_refs(arg, Node.id(), integer) :: arg when arg: t
  # @spec incr_id_refs(t, Node.id(), integer) :: t
  @spec incr_id_refs(t, id, integer) :: t
  def incr_id_refs(item, start_id, addend)

  @spec update_id_refs(t, (Node.id() -> Node.id())) :: t
  def update_id_refs(item, fun)
end

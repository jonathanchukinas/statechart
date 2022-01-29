defmodule StatechartTest do
  use ExUnit.Case
  use ExUnitProperties
  alias Statechart.Node
  alias Statechart.Definition

  # properties:
  #   when inserted a node, I know its parent id (b/c I randomly picked it)
  #     so I can look up a node by that id and compare it to the node's parent
  #     they should be the same.
  # Test for what happens when duplicate name is attempted to be inserted
  # What's the name of this type of data structure? Make a note of that in the docs

  setup_all do
    empty_tree = Definition.new()
    starting_max_parent_id = Definition.max_node_id(empty_tree)
    min_possible_parent_id = empty_tree |> Definition.nodes(mapper: &Node.id/1) |> Enum.min()

    # :: [{Node.t(), integer}]
    nodes_with_parent_ids_generator =
      map(uniq_list_of(atom(:alphanumeric)), fn names ->
        Enum.with_index(names, fn name, index ->
          max_parent_id = index + starting_max_parent_id
          rand_parent_id = Enum.random(min_possible_parent_id..max_parent_id)
          {Node.new(name), rand_parent_id}
        end)
      end)

    build_tree = fn nodes_and_parent_ids ->
      Enum.reduce(nodes_and_parent_ids, empty_tree, fn {node, parent_id}, tree ->
        Definition.insert!(tree, node, parent_id)
      end)
    end

    [
      tree_generator: map(nodes_with_parent_ids_generator, build_tree)
    ]
  end

  property "Nodes are stored in ascending lft order", %{tree_generator: generator} do
    check all(tree <- generator) do
      node_lft_values = Definition.nodes(tree, mapper: &Node.lft/1)
      assert node_lft_values == Enum.sort(node_lft_values)
    end
  end

  property "Node lft and rgt values are uniq and the sets don't overlap ", %{
    tree_generator: generator
  } do
    check all(tree <- generator) do
      sorted_node_lft_values = Definition.nodes(tree, mapper: &Node.lft/1) |> Enum.sort()
      assert sorted_node_lft_values == Enum.uniq(sorted_node_lft_values)

      sorted_node_rgt_values = Definition.nodes(tree, mapper: &Node.rgt/1) |> Enum.sort()
      assert sorted_node_rgt_values == Enum.uniq(sorted_node_rgt_values)

      sorted_lft_and_rgt = Enum.sort(sorted_node_lft_values ++ sorted_node_rgt_values)
      assert sorted_lft_and_rgt == Enum.uniq(sorted_lft_and_rgt)
    end
  end

  property "Node ids are unique", %{tree_generator: generator} do
    check all(tree <- generator) do
      sorted_node_ids = Definition.nodes(tree, mapper: &Node.id/1) |> Enum.sort()
      assert sorted_node_ids == Enum.uniq(sorted_node_ids)
    end
  end

  property "We can calculate node count using root's lft/rgt", %{tree_generator: generator} do
    check all(tree <- generator) do
      {lft, rgt} = tree |> Definition.root() |> Node.lft_rgt()
      expected_node_count = (rgt + 1 - lft) / 2
      assert expected_node_count == length(Definition.nodes(tree))
      assert expected_node_count == Definition.node_count(tree)
    end
  end
end

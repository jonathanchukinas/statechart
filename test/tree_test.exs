defmodule Statechart.TreeTest do
  use ExUnit.Case
  use ExUnitProperties
  alias Statechart.Node
  alias Statechart.Definition
  alias Statechart.Tree

  # properties:
  #   when inserted a node, I know its parent id (b/c I randomly picked it)
  #     so I can look up a node by that id and compare it to the node's parent
  #     they should be the same.
  # Test for what happens when duplicate name is attempted to be inserted
  # What's the name of this type of data structure? Make a note of that in the docs

  setup_all do
    empty_tree = Definition.new()
    starting_max_parent_id = Tree.max_node_id(empty_tree)

    min_possible_parent_id =
      empty_tree |> Tree.fetch_nodes!() |> Stream.map(&Node.id/1) |> Enum.min()

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
        {:ok, statechart_def} = Tree.insert(tree, node, parent_id)
        statechart_def
      end)
    end

    tree_generator = map(nodes_with_parent_ids_generator, build_tree)

    tree_and_node_parent_id_list_generator =
      map(nodes_with_parent_ids_generator, fn nodes_and_parent_ids ->
        %{
          tree: build_tree.(nodes_and_parent_ids),
          nodes_and_parent_ids: nodes_and_parent_ids
        }
      end)

    [
      tree_generator: tree_generator,
      tree_and_orig_inputs: tree_and_node_parent_id_list_generator
    ]
  end

  property "Nodes are stored in ascending lft order", %{tree_generator: tree_generator} do
    check all(tree <- tree_generator) do
      node_lft_values = tree |> Tree.fetch_nodes!() |> Stream.map(&Node.lft/1)
      assert Enum.to_list(node_lft_values) == Enum.sort(node_lft_values)
    end
  end

  property "Node lft and rgt values are uniq and the sets don't overlap ", %{
    tree_generator: tree_generator
  } do
    check all(tree <- tree_generator) do
      sorted_node_lft_values =
        tree |> Tree.fetch_nodes!() |> Stream.map(&Node.lft/1) |> Enum.sort()

      assert sorted_node_lft_values == Enum.uniq(sorted_node_lft_values)

      sorted_node_rgt_values =
        tree |> Tree.fetch_nodes!() |> Stream.map(&Node.rgt/1) |> Enum.sort()

      assert sorted_node_rgt_values == Enum.uniq(sorted_node_rgt_values)

      sorted_lft_and_rgt = Enum.sort(sorted_node_lft_values ++ sorted_node_rgt_values)
      assert sorted_lft_and_rgt == Enum.uniq(sorted_lft_and_rgt)
    end
  end

  property "Node ids are unique", %{tree_generator: tree_generator} do
    check all(tree <- tree_generator) do
      sorted_node_ids = tree |> Tree.fetch_nodes!() |> Stream.map(&Node.id/1) |> Enum.sort()

      assert sorted_node_ids == Enum.uniq(sorted_node_ids)
    end
  end

  property "We can calculate node count using root's lft/rgt", %{tree_generator: tree_generator} do
    check all(tree <- tree_generator) do
      {lft, rgt} = tree |> Tree.root() |> Node.lft_rgt()
      expected_node_count = (rgt + 1 - lft) / 2
      assert expected_node_count == length(Tree.fetch_nodes!(tree))
      assert expected_node_count == Tree.node_count(tree)
    end
  end

  property "Once inserted, a node's parent never changes", %{tree_and_orig_inputs: generator} do
    check all(
            %{
              tree: statechart_def,
              nodes_and_parent_ids: nodes_and_parent_ids
            } <- generator
          ) do
      input_names_grouped_by_parent_id =
        Enum.group_by(
          nodes_and_parent_ids,
          fn {_child, parent_id} -> parent_id end,
          fn {child, _parent_id} -> Node.name(child) end
        )

      Enum.each(input_names_grouped_by_parent_id, fn {parent_id, child_names} ->
        expected_child_names = Enum.sort(child_names)

        actual_child_names =
          statechart_def
          |> Tree.fetch_children_by_id!(parent_id)
          |> Stream.map(&Node.name/1)
          |> Enum.sort()

        message =
          "expected parent node (id: #{parent_id}) to have children with names #{inspect(expected_child_names)}, got: #{inspect(actual_child_names)}"

        assert actual_child_names == expected_child_names, message
      end)
    end
  end
end

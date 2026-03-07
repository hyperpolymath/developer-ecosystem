# SPDX-License-Identifier: PMPL-1.0-or-later
# SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell <jonathan.jewell@open.ac.uk>

defmodule ALib.AST.Traversal do
  @moduledoc """
  Generic AST tree walking utilities.

  Used by: Compiler, Linter, Analyzer, Formatter, Doc Generator

  These functions work on any AST structure that follows Elixir tuple conventions.

  ## Example

      ast = {:binary_op, :add, {:literal, :integer, 1}, {:literal, :integer, 2}}

      # Find all literals
      literals = ALib.AST.Traversal.find_all(ast, fn
        {:literal, _, _} -> true
        _ -> false
      end)

      # Replace all integers with zero
      new_ast = ALib.AST.Traversal.replace(ast, fn
        {:literal, :integer, _} -> true
        _ -> false
      end, fn {:literal, :integer, _} -> {:literal, :integer, 0} end)
  """

  @doc """
  Walk AST with pre-order and post-order callbacks.

  The `pre_fn` is called before visiting children.
  The `post_fn` is called after visiting children.

  ## Example

      # Count nodes
      count = walk(ast, fn node -> node end, fn _ -> 1 end)
  """
  @spec walk(any(), (any() -> any()), (any() -> any())) :: any()
  def walk(node, pre_fn, post_fn) do
    node = pre_fn.(node)
    children = get_children(node)
    children = Enum.map(children, &walk(&1, pre_fn, post_fn))
    node = set_children(node, children)
    post_fn.(node)
  end

  @doc """
  Find all nodes matching predicate.

  Returns a flat list of all matching nodes.

  ## Example

      # Find all identifiers
      identifiers = find_all(ast, fn
        {:identifier, _} -> true
        _ -> false
      end)
  """
  @spec find_all(any(), (any() -> boolean())) :: [any()]
  def find_all(ast, predicate_fn) do
    walk(
      ast,
      fn node ->
        if predicate_fn.(node), do: [node], else: []
      end,
      fn results ->
        if is_list(results) do
          List.flatten(results)
        else
          []
        end
      end
    )
  end

  @doc """
  Replace nodes matching predicate with result of replacement function.

  ## Example

      # Replace all variables with zero
      new_ast = replace(ast, fn
        {:identifier, _} -> true
        _ -> false
      end, fn _ -> {:literal, :integer, 0} end)
  """
  @spec replace(any(), (any() -> boolean()), (any() -> any())) :: any()
  def replace(ast, predicate_fn, replacement_fn) do
    walk(
      ast,
      fn node ->
        if predicate_fn.(node), do: replacement_fn.(node), else: node
      end,
      fn node -> node end
    )
  end

  @doc """
  Get children of a node.

  Handles common AST tuple patterns:
  - Binary ops: {:binary_op, op, left, right}
  - Unary ops: {:unary_op, op, operand}
  - Lists: [node1, node2, ...]
  - Atoms/primitives: no children
  """
  @spec get_children(any()) :: [any()]
  def get_children(node) when is_tuple(node) do
    case node do
      # Binary operations
      {:binary_op, _op, left, right} -> [left, right]
      {:comparison, _op, left, right} -> [left, right]

      # Unary operations
      {:unary_op, _op, operand} -> [operand]

      # Module calls
      {:module_call, _path, args} -> args

      # Field access
      {:field_access, base, _field} -> [base]
      {:optional_access, base, _field} -> [base]

      # Actions
      {:execute, _name, args} -> args
      {:report, message} -> [message]
      {:reject, reason} when reason != nil -> [reason]
      {:accept, reason} when reason != nil -> [reason]
      {:block, actions} -> actions
      {:conditional, condition, then_action, else_action} ->
        [condition, then_action] ++ if(else_action, do: [else_action], else: [])

      # Declarations
      {:policy, _name, condition, action, _metadata} -> [condition, action]
      {:const, _name, value} -> [value]
      {:import, _path, _alias} -> []

      # Literals have no children
      {:literal, _type, _value} -> []
      {:identifier, _name} -> []

      # Default: extract all non-atom elements
      tuple ->
        tuple
        |> Tuple.to_list()
        |> Enum.filter(&(!is_atom(&1)))
    end
  end

  def get_children(node) when is_list(node), do: node
  def get_children(_node), do: []

  @doc """
  Set children of a node.

  Creates a new node with updated children.
  """
  @spec set_children(any(), [any()]) :: any()
  def set_children(node, children) when is_tuple(node) do
    case node do
      {:binary_op, op, _left, _right} ->
        [left, right] = children
        {:binary_op, op, left, right}

      {:comparison, op, _left, _right} ->
        [left, right] = children
        {:comparison, op, left, right}

      {:unary_op, op, _operand} ->
        [operand] = children
        {:unary_op, op, operand}

      {:module_call, path, _args} ->
        {:module_call, path, children}

      {:field_access, _base, field} ->
        [base] = children
        {:field_access, base, field}

      {:optional_access, _base, field} ->
        [base] = children
        {:optional_access, base, field}

      {:execute, name, _args} ->
        {:execute, name, children}

      {:report, _message} ->
        [message] = children
        {:report, message}

      {:reject, _reason} when length(children) == 1 ->
        [reason] = children
        {:reject, reason}

      {:accept, _reason} when length(children) == 1 ->
        [reason] = children
        {:accept, reason}

      {:block, _actions} ->
        {:block, children}

      {:conditional, _cond, _then, _else} ->
        case children do
          [condition, then_action, else_action] ->
            {:conditional, condition, then_action, else_action}

          [condition, then_action] ->
            {:conditional, condition, then_action, nil}
        end

      {:policy, name, _condition, _action, metadata} ->
        [condition, action] = children
        {:policy, name, condition, action, metadata}

      {:const, name, _value} ->
        [value] = children
        {:const, name, value}

      # Default: return node unchanged if we don't know how to update it
      _ ->
        node
    end
  end

  def set_children(_node, children) when is_list(children), do: children
  def set_children(node, _children), do: node
end

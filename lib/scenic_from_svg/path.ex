defmodule Scenic.FromSVG.Path do
  @moduledoc """
  Implements parsing and conversion of SVG path "d" attribute.

  Upper case opcodes use absolute coordinates.
  Lower case opcodes use relative coordinates.
  """

  def tokenize(d), do: tokenize(d, [])
  def reduce_tokens(tokens), do: reduce_tokens(tokens, [:begin], {0.0, 0.0, nil})

  defp tokenize("", tok_rev), do: tok_rev |> Enum.reverse()

  defp tokenize(<<sep, rest::binary>>, tok_rev) when sep in [?\s, ?,] do
    tokenize(rest, tok_rev)
  end

  defp tokenize(<<op, rest::binary>>, tok_rev)
       when op in [?M, ?m, ?L, ?l, ?V, ?v, ?H, ?h, ?Z, ?z, ?C, ?c] do
    tokenize(rest, [op | tok_rev])
  end

  defp tokenize(rest, tok_rev) do
    {num, rest} = rest |> Float.parse()
    tokenize(rest, [num | tok_rev])
  end

  defp reduce_tokens([], path_cmds_rev, {_cx, _cy, _op}) do
    path_cmds_rev |> Enum.reverse()
  end

  defp reduce_tokens([op | rest], path_cmds_rev, {_cx, _cy, _op}) when op in [?Z, ?z] do
    cmd = :close_path
    # XXX:
    {new_cx, new_cy} = {0.0, 0.0}
    reduce_tokens(rest, [cmd | path_cmds_rev], {new_cx, new_cy, nil})
  end

  defp reduce_tokens([op | rest], path_cmds_rev, {cx, cy, _op})
       when op in [?M, ?m, ?L, ?l, ?V, ?v, ?H, ?h, ?C, ?c] do
    reduce_tokens(rest, path_cmds_rev, {cx, cy, op})
  end

  defp reduce_tokens([x, y | rest], path_cmds_rev, {_cx, _cy, ?M = op})
       when is_float(x) and is_float(y) do
    cmd = {:move_to, x, y}
    reduce_tokens(rest, [cmd | path_cmds_rev], {x, y, op})
  end

  defp reduce_tokens([dx, dy | rest], path_cmds_rev, {cx, cy, ?m = op})
       when is_float(dx) and is_float(dy) do
    x = cx + dx
    y = cy + dy
    cmd = {:move_to, x, y}
    reduce_tokens(rest, [cmd | path_cmds_rev], {x, y, op})
  end

  defp reduce_tokens([x, y | rest], path_cmds_rev, {_cx, _cy, ?L = op})
       when is_float(x) and is_float(y) do
    cmd = {:line_to, x, y}
    reduce_tokens(rest, [cmd | path_cmds_rev], {x, y, op})
  end

  defp reduce_tokens([dx, dy | rest], path_cmds_rev, {cx, cy, ?l = op})
       when is_float(dx) and is_float(dy) do
    x = cx + dx
    y = cy + dy
    cmd = {:line_to, x, y}
    reduce_tokens(rest, [cmd | path_cmds_rev], {x, y, op})
  end

  defp reduce_tokens([x | rest], path_cmds_rev, {_cx, cy, ?H = op}) when is_float(x) do
    cmd = {:line_to, x, cy}
    reduce_tokens(rest, [cmd | path_cmds_rev], {x, cy, op})
  end

  defp reduce_tokens([dx | rest], path_cmds_rev, {cx, cy, ?h = op}) when is_float(dx) do
    x = cx + dx
    cmd = {:line_to, x, cy}
    reduce_tokens(rest, [cmd | path_cmds_rev], {x, cy, op})
  end

  defp reduce_tokens([y | rest], path_cmds_rev, {cx, _cy, ?V = op}) when is_float(y) do
    cmd = {:line_to, cx, y}
    reduce_tokens(rest, [cmd | path_cmds_rev], {cx, y, op})
  end

  defp reduce_tokens([dy | rest], path_cmds_rev, {cx, cy, ?v = op}) when is_float(dy) do
    y = cy + dy
    cmd = {:line_to, cx, y}
    reduce_tokens(rest, [cmd | path_cmds_rev], {cx, y, op})
  end

  defp reduce_tokens([c1x, c1y, c2x, c2y, x, y | rest], path_cmds_rev, {_cx, _cy, ?C = op})
       when is_float(c1x) and is_float(c1y) and is_float(c2x) and is_float(c2y) and is_float(x) and
              is_float(y) do
    cmd = {:bezier_to, c1x, c1y, c2x, c2y, x, y}
    reduce_tokens(rest, [cmd | path_cmds_rev], {x, y, op})
  end

  defp reduce_tokens(
         [c1dx, c1dy, c2dx, c2dy, dx, dy | rest],
         path_cmds_rev,
         {cx, cy, ?c = op}
       )
       when is_float(c1dx) and is_float(c1dy) and is_float(c2dx) and is_float(c2dy) and
              is_float(dx) and is_float(dy) do
    {c1x, c1y, c2x, c2y, x, y} = {c1dx + cx, c1dy + cy, c2dx + cx, c2dy + cy, dx + cx, dy + cy}
    cmd = {:bezier_to, c1x, c1y, c2x, c2y, x, y}
    reduce_tokens(rest, [cmd | path_cmds_rev], {x, y, op})
  end
end

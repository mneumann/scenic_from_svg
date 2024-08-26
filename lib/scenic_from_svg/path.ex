defmodule Scenic.FromSVG.Path do
  @moduledoc """
  Implements parsing and conversion of SVG path "d" attributes into
  a list of cmd() recognized by Scenic's `path` primitive.

  Upper case opcodes (e.g. "M" or "V") use absolute coordinates.
  Lower case opcodes (e.g. "m" or "v") use relative coordinates.
  """

  @type cmd :: Scenic.Primitive.Path.cmd()

  @typep op :: ?M | ?m | ?L | ?l | ?V | ?v | ?H | ?h | ?Z | ?z | ?C | ?c
  @typep token :: op() | Float.t()


  @doc """
  Parses a SVG path "d" into a list of cmd()s as recognized by Scenic's `path`
  primitive.
  """
  @spec parse(String.t()) :: [cmd()]
  def parse(d), do: tokenize(d, []) |> reduce_tokens()

  @spec tokenize(String.t(), [token()]) :: [token()]
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

  @spec reduce_tokens([token()]) :: [cmd()]
  defp reduce_tokens(tokens), do: reduce_tokens(tokens, [:begin], {0.0, 0.0, nil})

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

  defp reduce_tokens([x, y | rest], path_cmds_rev, {_cx, _cy, ?M})
       when is_float(x) and is_float(y) do
    cmd = {:move_to, x, y}

    # "If a moveto is followed by multiple pairs of coordinates, the subsequent
    # pairs are treated as implicit lineto commands"
    reduce_tokens(rest, [cmd | path_cmds_rev], {x, y, ?L})
  end

  defp reduce_tokens([dx, dy | rest], path_cmds_rev, {cx, cy, ?m})
       when is_float(dx) and is_float(dy) do
    x = cx + dx
    y = cy + dy
    cmd = {:move_to, x, y}
    # "If a moveto is followed by multiple pairs of coordinates, the subsequent
    # pairs are treated as implicit lineto commands"
    reduce_tokens(rest, [cmd | path_cmds_rev], {x, y, ?l})
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

  defp reduce_tokens([x1, y1, x2, y2, x, y | rest], path_cmds_rev, {_cx, _cy, ?C = op})
       when is_float(x1) and is_float(y1) and is_float(x2) and is_float(y2) and is_float(x) and
              is_float(y) do
    cmd = {:bezier_to, x1, y1, x2, y2, x, y}
    reduce_tokens(rest, [cmd | path_cmds_rev], {x, y, op})
  end

  defp reduce_tokens(
         [dx1, dy1, dx2, dy2, dx, dy | rest],
         path_cmds_rev,
         {cx, cy, ?c = op}
       )
       when is_float(dx1) and is_float(dy1) and is_float(dx2) and is_float(dy2) and
              is_float(dx) and is_float(dy) do
    {x1, y1, x2, y2, x, y} = {dx1 + cx, dy1 + cy, dx2 + cx, dy2 + cy, dx + cx, dy + cy}
    cmd = {:bezier_to, x1, y1, x2, y2, x, y}
    reduce_tokens(rest, [cmd | path_cmds_rev], {x, y, op})
  end
end

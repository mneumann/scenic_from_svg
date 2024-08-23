defmodule Scenic.FromSVG do
  @moduledoc """
  Derives `Scenic.Primitives` from Scalable Vector Graphics (SVG).
  """

  import SweetXml

  @type prim_opts :: [any()]
  @type prim ::
          {:rect, {Float.t(), Float.t()}, prim_opts()}
          | {:circle, Float.t(), prim_opts()}
          | {:text, String.t(), prim_opts()}
          | {:path, [Scenic.Primitive.Path.cmd()], prim_opts()}
          | {:group, [prim()], prim_opts()}

  @spec svg_to_prim(binary()) :: prim()

  @doc """
  Parses the SVG into a (complex) drawing primitive. As :group is a drawing primitive,
  this returns a single primitive.

  ## Examples

      iex> ~s(
      ...>     <svg>
      ...>       <rect x="10" y="10" width="100" height="100" style="fill:#ff0000;" />
      ...>       <text x="80" y="80">
      ...>          <tspan x="80" y="80" style="font-size:64px;fill:#000000">Hello</tspan>
      ...>       </text>
      ...>       <circle style="fill:#ad1c1c;fill-opacity:0.71" cx="180" cy="180" r="20" />
      ...>       <g style="fill:white; stroke-width: 2; stroke: black;">
      ...>         <path d="m 458.94046,243.85936 h 40 l 20,34.64 -20,34.64 h -40 l -20,-34.64 z" />
      ...>         <path d="m 218.94046,243.85936 h 40 l 20,34.64 -20,34.64 h -40 l -20,-34.64 z" />
      ...>       </g>
      ...>     </svg>
      ...> )
      ...> |> Scenic.FromSVG.svg_to_prim()
      {:group,
       [
         {:rect, {100.0, 100.0}, [fill: {255, 0, 0, 255}, t: {10.0, 10.0}]},
         {:group,
          [
            {:text, "Hello",
             [fill: {0, 0, 0, 255}, font_size: 64, text_align: :left, font: :roboto, t: {80, 80}]}
          ], []},
         {:circle, 20.0, [fill: {173, 28, 28, 181}, t: {180.0, 180.0}]},
         {:group,
          [
            {:path,
             [
               :begin,
               {:move_to, 458.94046, 243.85936},
               {:line_to, 498.94046, 243.85936},
               {:line_to, 518.94046, 278.49936},
               {:line_to, 498.94046000000003, 313.13936},
               {:line_to, 458.94046000000003, 313.13936},
               {:line_to, 438.94046000000003, 278.49936},
               :close_path
             ], []},
            {:path,
             [
               :begin,
               {:move_to, 218.94046, 243.85936},
               {:line_to, 258.94046000000003, 243.85936},
               {:line_to, 278.94046000000003, 278.49936},
               {:line_to, 258.94046000000003, 313.13936},
               {:line_to, 218.94046000000003, 313.13936},
               {:line_to, 198.94046000000003, 278.49936},
               :close_path
             ], []}
          ], [{:fill, {255, 255, 255, 255}}, {:stroke, {2, {0, 0, 0}}}]}
       ], []}

  """

  def svg_to_prim(svg) when is_binary(svg) do
    {:xmlElement, :svg, :svg, _, _, _, _, _attrs, children, _, _, _} =
      svg |> parse() |> xpath(~x"///svg"e)

    children =
      children
      |> Enum.map(&node_to_prim/1)
      |> Enum.filter(& &1)

    {:group, children, []}
  end

  @spec svg_spec(binary()) :: Scenic.Graph.deferred()

  @doc """
  Converts the SVG into a deferred graph.
  """

  def svg_spec(svg) do
    svg
    |> svg_to_prim()
    |> prim_spec()
  end

  @spec prim_spec(prim()) :: Scenic.Graph.deferred()

  @doc """
  Converts the drawing primitive into a deferred graph.
  """

  def prim_spec({:rect, {w, h}, opts}), do: Scenic.Primitives.rect_spec({w, h}, opts)
  def prim_spec({:circle, r, opts}), do: Scenic.Primitives.circle_spec(r, opts)
  def prim_spec({:text, text, opts}), do: Scenic.Primitives.text_spec(text, opts)
  def prim_spec({:path, cmds, opts}), do: Scenic.Primitives.path_spec(cmds, opts)

  def prim_spec({:group, children, opts}),
    do: Scenic.Primitives.group_spec(Enum.map(children, &prim_spec/1), opts)

  defp node_to_prim({:xmlElement, :rect, :rect, _, _, _, _, _, [], _, _, _} = node) do
    style = node |> parse_style()
    _id = node |> xpath(~x"./@id"so)
    width = node |> xpath(~x"./@width"f)
    height = node |> xpath(~x"./@height"f)
    x = node |> xpath(~x"./@x"f)
    y = node |> xpath(~x"./@y"f)

    opts =
      [
        fill_from_style(style),
        stroke_from_style(style),
        t: {x, y}
      ]
      |> Enum.filter(& &1)

    {:rect, {width, height}, opts}
  end

  defp node_to_prim({:xmlElement, :circle, :circle, _, _, _, _, _, [], _, _, _} = node) do
    style = node |> parse_style()
    _id = node |> xpath(~x"./@id"so)
    cx = node |> xpath(~x"./@cx"f)
    cy = node |> xpath(~x"./@cy"f)
    r = node |> xpath(~x"./@r"f)

    opts =
      [
        fill_from_style(style),
        stroke_from_style(style),
        t: {cx, cy}
      ]
      |> Enum.filter(& &1)

    {:circle, r, opts}
  end

  defp node_to_prim({:xmlElement, :text, :text, _, _, _, _, _, _, _, _, _} = node) do
    node_style = parse_style(node)
    # node_x = node |> xpath(~x"./@x"f) |> trunc
    # node_y = node |> xpath(~x"./@y"f) |> trunc

    {scale_x, scale_y} =
      case xpath(node, ~x"./@transform"so) do
        <<"scale(", rest::binary>> ->
          {scale_x, <<",", rest::binary>>} = Float.parse(rest)
          {scale_y, ")"} = Float.parse(rest)
          {scale_x, scale_y}

        _ ->
          {1.0, 1.0}
      end

    children =
      node
      |> xpath(~x"./tspan"el)
      |> Enum.map(fn
        tspan ->
          style = Map.merge(node_style, parse_style(tspan))
          _id = tspan |> xpath(~x"./@id"so)
          x = (scale_x * xpath(tspan, ~x"./@x"f)) |> trunc
          y = (scale_y * xpath(tspan, ~x"./@y"f)) |> trunc
          text_value = tspan |> xpath(~x"./text()"s)

          opts =
            [
              fill_from_style(style),
              stroke_from_style(style),
              font_size_from_style(style),
              text_align: :left,
              # XXX
              font: :roboto,
              t: {x, y}
            ]
            |> Enum.filter(& &1)

          {:text, text_value, opts}
      end)

    {:group, children, []}
  end

  defp node_to_prim({:xmlElement, :g, :g, _, _, _, _, _, children, _, _, _} = node) do
    style = parse_style(node)
    transform_opts = parse_transform(node)

    children =
      children
      |> Enum.map(&node_to_prim/1)
      |> Enum.filter(& &1)

    opts =
      [
        fill_from_style(style),
        stroke_from_style(style)
        | transform_opts
      ]
      |> Enum.filter(& &1)

    {:group, children, opts}
  end

  defp node_to_prim({:xmlElement, :path, :path, _, _, _, _, _, _, _, _, _} = node) do
    style = parse_style(node)
    transform_opts = parse_transform(node)
    _id = node |> xpath(~x"./@id"so)
    d = node |> xpath(~x"./@d"s)

    path_cmds =
      Scenic.FromSVG.Path.tokenize(d)
      |> Scenic.FromSVG.Path.reduce_tokens()

    opts =
      [
        fill_from_style(style),
        stroke_from_style(style)
        | transform_opts
      ]
      |> Enum.filter(& &1)

    {:path, path_cmds, opts}
  end

  defp node_to_prim(_node), do: nil

  defp parse_transform(node) do
    (xpath(node, ~x"./@transform"so) || "") |> parse_transform([])
  end

  defp parse_transform("", opts), do: Enum.reverse(opts)
  defp parse_transform(" " <> rest, opts), do: parse_transform(rest, opts)

  defp parse_transform("scale(" <> rest, opts) do
    {scale_x, <<",", rest::binary>>} = Float.parse(rest)
    {scale_y, ")"} = Float.parse(rest)
    parse_transform(rest, [{:scale, {scale_x, scale_y}} | opts])
  end

  defp parse_transform("matrix(" <> rest, opts) do
    # https://developer.mozilla.org/en-US/docs/Web/SVG/Attribute/transform
    [args, rest] = String.split(rest, ")")

    [a, b, c, d, e, f] = parse_floats(args)

    matrix =
      [
        [a, c, e, 0],
        [b, d, f, 0],
        [0, 0, 1, 0],
        [0, 0, 0, 0]
      ]
      |> Enum.flat_map(fn x -> x end)
      |> Scenic.Math.Matrix.Utils.to_binary()

    parse_transform(rest, [{:matrix, matrix} | opts])
  end

  defp parse_transform("translate(" <> rest, opts) do
    [args, rest] = String.split(rest, ")")

    [x, y] = parse_floats(args)

    parse_transform(rest, [{:t, {x, y}} | opts])
  end

  defp parse_floats(s) do
    s
    |> String.split([" ", ","], trim: true)
    |> Enum.map(&Float.parse/1)
    |> Enum.map(fn {num, ""} -> num end)
  end

  defp parse_style(node) do
    (xpath(node, ~x"./@style"so) || "")
    |> String.split(";", trim: true)
    |> Enum.map(fn s ->
      [k, v] = String.split(s, ":", parts: 2) |> Enum.map(&String.trim/1)
      {k, v}
    end)
    |> Enum.into(%{})
    |> put_style("stroke", xpath(node, ~x"./@stroke"so))
    |> put_style("fill", xpath(node, ~x"./@fill"so))
    |> put_style("fill-rule", xpath(node, ~x"./@fill-rule"so))
  end

  defp put_style(map, _key, nil), do: map
  defp put_style(map, _key, ""), do: map
  defp put_style(map, key, value), do: Map.put(map, key, value |> String.trim())

  defp fill_from_style(style) do
    case {fill_color(style), fill_opacity(style)} do
      {nil, _} -> nil
      {{r, g, b}, opacity} -> {:fill, {r, g, b, opacity}}
    end
  end

  defp fill_color(style), do: parse_color(style["fill"] || "none")

  defp fill_opacity(%{"fill-opacity" => opacity}) do
    {opacity, ""} = Float.parse(opacity)
    trunc(opacity * 255)
  end

  defp fill_opacity(_style), do: 255

  defp stroke_from_style(style) do
    stroke = style["stroke"] |> parse_color()
    stroke_opacity = style["stroke-opacity"] |> parse_float()
    stroke_width = style["stroke-width"] |> parse_float()

    case {stroke, stroke_opacity, stroke_width} do
      {{r, g, b}, nil, width} when is_float(width) ->
        {:stroke, {trunc(width), {r, g, b}}}

      {{r, g, b}, opacity, width} when is_float(width) ->
        {:stroke, {trunc(width), {r, g, b, trunc(opacity * 255)}}}

      _ ->
        nil
    end
  end

  defp parse_float(nil), do: nil

  defp parse_float(s) do
    case Float.parse(s) do
      {value, ""} -> value
      _ -> nil
    end
  end

  defp font_size_from_style(%{"font-size" => font_size}) do
    {font_size_in_px, "px"} = Float.parse(font_size)
    {:font_size, trunc(font_size_in_px)}
  end

  defp parse_color("none"), do: nil
  defp parse_color("black"), do: {0, 0, 0}
  defp parse_color("white"), do: {255, 255, 255}

  defp parse_color(<<"#", rh, rl, gh, gl, bh, bl>>) do
    {red, ""} = Integer.parse(<<rh, rl>>, 16)
    {green, ""} = Integer.parse(<<gh, gl>>, 16)
    {blue, ""} = Integer.parse(<<bh, bl>>, 16)
    {red, green, blue}
  end

  defp parse_color(_), do: nil
end

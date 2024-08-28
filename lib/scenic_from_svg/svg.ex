defmodule Scenic.FromSVG.SVG do
  @moduledoc """
  Represents a parsed SVG as returned by `Scenic.FromSVG.from_string`.
  """

  import SweetXml
  alias __MODULE__
  alias Scenic.FromSVG.Colors

  @type prim_opts :: keyword()

  @typedoc """
  Represents a primitive Scenic drawing operation.
  """
  @type prim ::
          {:rect, {Float.t(), Float.t()}, prim_opts()}
          | {:circle, Float.t(), prim_opts()}
          | {:ellipse, {Float.t(), Float.t()}, prim_opts()}
          | {:text, String.t(), prim_opts()}
          | {:path, [Scenic.Primitive.Path.cmd()], prim_opts()}
          | {:group, [prim()], prim_opts()}

  @type t :: %SVG{
          width: integer(),
          height: integer(),
          root_prim: prim()
        }

  defstruct [:width, :height, :root_prim]

  @spec from_string(String.t()) :: t()

  @doc """
  Parses a SVG into a struct `Scenic.FromSVG.SVG`.

  ## Examples

      iex> ~s(
      ...>     <svg width="100" height"100">
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
      ...> |> Scenic.FromSVG.SVG.from_string()
      %Scenic.FromSVG.SVG{
        width: 100,
        height: 100,
        root_prim: 
          {:group,
           [
             {:rect, {100.0, 100.0}, [fill: {255, 0, 0, 255}, t: {10.0, 10.0}]},
             {:group,
              [
                {:text, "Hello",
                 [fill: {0, 0, 0}, font: :roboto, font_size: 64, t: {80, 80}, text_align: :left]}
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
              ], [{:fill, {255, 255, 255}}, {:stroke, {2, {0, 0, 0}}}]}
           ], []}}
  """
  def from_string(svgstr) when is_binary(svgstr) do
    svgdoc = svgstr |> parse()

    width = svgdoc |> xpath(~x"///svg/@width"i)
    height = svgdoc |> xpath(~x"///svg/@height"i)

    {:xmlElement, :svg, :svg, _, _, _, _, _attrs, children, _, _, _} =
      svgdoc |> xpath(~x"///svg"e)

    prims =
      children
      |> Enum.map(&node_to_prim/1)
      |> Enum.filter(& &1)

    %SVG{
      width: width,
      height: height,
      root_prim: {:group, prims, []}
    }
  end

  @spec to_spec(t()) :: Scenic.Graph.deferred()

  @doc """
  Converts the parsed SVG into a deferred Scenic graph.
  """
  def to_spec(%SVG{root_prim: root_prim}) do
    root_prim |> prim_spec()
  end

  @spec prim_spec(prim()) :: Scenic.Graph.deferred()

  defp prim_spec({:rect, {w, h}, opts}),
    do: Scenic.Primitives.rect_spec({w, h}, opts_to_spec(opts))

  defp prim_spec({:circle, r, opts}), do: Scenic.Primitives.circle_spec(r, opts_to_spec(opts))

  defp prim_spec({:ellipse, {rx, ry}, opts}),
    do: Scenic.Primitives.ellipse_spec({rx, ry}, opts_to_spec(opts))

  defp prim_spec({:text, text, opts}), do: Scenic.Primitives.text_spec(text, opts_to_spec(opts))
  defp prim_spec({:path, cmds, opts}), do: Scenic.Primitives.path_spec(cmds, opts_to_spec(opts))

  defp prim_spec({:group, children, opts}),
    do: Scenic.Primitives.group_spec(Enum.map(children, &prim_spec/1), opts_to_spec(opts))

  defp opts_to_spec(opts), do: Enum.map(opts, &opt_to_spec/1)

  defp opt_to_spec({:matrix, matrix}) do
    matrix =
      matrix
      |> Enum.flat_map(& &1)
      |> Scenic.Math.Matrix.Utils.to_binary()

    {:matrix, matrix}
  end

  defp opt_to_spec(opt), do: opt

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
      |> normalize_opts

    {:rect, {width, height}, opts}
  end

  defp node_to_prim({:xmlElement, :circle, :circle, _, _, _, _, _, [], _, _, _} = node) do
    style = get_style(node)
    _id = node |> xpath(~x"./@id"so)
    cx = node |> xpath(~x"./@cx"f)
    cy = node |> xpath(~x"./@cy"f)
    r = node |> xpath(~x"./@r"f)

    # XXX: what if both cx/cy and transform is specified? Do they add up?

    opts =
      [
        fill_from_style(style),
        stroke_from_style(style),
        parse_transform(node),
        t: {cx, cy}
      ]
      |> normalize_opts

    {:circle, r, opts}
  end

  defp node_to_prim({:xmlElement, :ellipse, :ellipse, _, _, _, _, _, [], _, _, _} = node) do
    style = get_style(node)
    _id = node |> xpath(~x"./@id"so)
    cx = node |> xpath(~x"./@cx"f)
    cy = node |> xpath(~x"./@cy"f)
    rx = node |> xpath(~x"./@rx"f)
    ry = node |> xpath(~x"./@ry"f)

    # XXX: what if both cx/cy and transform is specified?

    opts =
      [
        fill_from_style(style),
        stroke_from_style(style),
        parse_transform(node),
        t: {cx, cy}
      ]
      |> normalize_opts

    {:ellipse, {rx, ry}, opts}
  end

  defp node_to_prim({:xmlElement, :text, :text, _, _, _, _, _, _, _, _, _} = node) do
    node_style = get_style(node)
    _id = node |> xpath(~x"./@id"so)
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

    tspans = node |> xpath(~x"./tspan"el)

    children =
      tspans
      |> Enum.map(fn
        tspan ->
          style = Map.merge(node_style, get_style(tspan))
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
            |> normalize_opts

          {:text, text_value, opts}
      end)

    case children do
      [] ->
        x = (scale_x * xpath(node, ~x"./@x"f)) |> trunc
        y = (scale_y * xpath(node, ~x"./@y"f)) |> trunc
        text_value = node |> xpath(~x"./text()"s)

        opts =
          [
            fill_from_style(node_style),
            stroke_from_style(node_style),
            font_size_from_style(node_style),
            text_align: :left,
            # XXX
            font: :roboto,
            t: {x, y}
          ]
          |> normalize_opts

        {:text, text_value, opts}

      children ->
        {:group, children, []}
    end
  end

  defp node_to_prim({:xmlElement, :g, :g, _, _, _, _, _, children, _, _, _} = node) do
    style = get_style(node)

    children =
      children
      |> Enum.map(&node_to_prim/1)
      |> Enum.filter(& &1)

    opts =
      [
        fill_from_style(style),
        stroke_from_style(style),
        parse_transform(node)
      ]
      |> normalize_opts

    {:group, children, opts}
  end

  defp node_to_prim({:xmlElement, :path, :path, _, _, _, _, _, _, _, _, _} = node) do
    style = get_style(node)
    _id = node |> xpath(~x"./@id"so)
    d = node |> xpath(~x"./@d"s)

    path_cmds =
      Scenic.FromSVG.Path.parse(d)

    opts =
      [
        fill_from_style(style),
        stroke_from_style(style),
        parse_transform(node)
      ]
      |> normalize_opts

    {:path, path_cmds, opts}
  end

  defp node_to_prim(_node), do: nil

  defp normalize_opts(opts) do
    # order in which opts are specified does not matter for Scenic!

    opts
    |> List.flatten()
    |> Enum.filter(& &1)
    |> Enum.group_by(fn {k, _} -> k end)
    |> Enum.map(fn {k, optlist} -> merge_opts(k, optlist) end)
    |> Enum.sort_by(fn {k, _} -> k end)
    |> Enum.to_list()
  end

  defp merge_opts(:t, transforms) do
    # :t transformations add up
    tx = transforms |> Enum.map(fn {:t, {x, _y}} -> x end) |> Enum.sum()
    ty = transforms |> Enum.map(fn {:t, {_x, y}} -> y end) |> Enum.sum()
    {:t, {tx, ty}}
  end

  defp merge_opts(_key, [opt]) do
    # All other options should be non-duplicated
    opt
  end

  defp get_style(node) do
    parse_style(node)
    |> Map.merge(parse_style_attrs(node))
  end

  defp parse_style_attrs(node) do
    [
      {"fill", xpath(node, ~x"./@fill"so)},
      {"stroke", xpath(node, ~x"./@stroke"so)},
      {"font-size", xpath(node, ~x"./@font-size"so)},
      {"font-family", xpath(node, ~x"./@font-family"so)},
      {"font-weight", xpath(node, ~x"./@font-weight"so)},
      {"text-anchor", xpath(node, ~x"./@text-anchor"so)}
    ]
    |> Enum.flat_map(fn
      {_attr, nil} -> []
      {_attr, ""} -> []
      kv -> [kv]
    end)
    |> Enum.into(%{})
  end

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

  defp parse_transform("rotate(" <> rest, opts) do
    {rotate, <<")", rest::binary>>} = Float.parse(rest)
    parse_transform(rest, [{:rotate, rotate} | opts])
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
    fill_color(style)
    |> put_opacity(fill_opacity(style))
    |> simplify_color()
    |> then(fn
      nil -> nil
      color -> {:fill, color}
    end)
  end

  defp fill_color(style), do: parse_color(style["fill"] || "none")

  defp fill_opacity(%{"fill-opacity" => opacity}) do
    {opacity, ""} = Float.parse(opacity)
    trunc(opacity * 255)
  end

  defp fill_opacity(_style), do: nil

  defp stroke_from_style(style) do
    stroke = style["stroke"] |> parse_color()
    stroke_opacity = style["stroke-opacity"] |> parse_float()
    stroke_width = style["stroke-width"] |> parse_float()

    stroke_color = stroke |> put_opacity(stroke_opacity) |> simplify_color()

    case {stroke_color, stroke_width} do
      {color, width} when is_float(width) ->
        {:stroke, {trunc(width), color}}

      _ ->
        nil
    end
  end

  defp put_opacity(nil, _opacity), do: nil
  defp put_opacity(color, nil), do: color

  defp put_opacity(color, opacity) when is_float(opacity),
    do: put_opacity(color, trunc(opacity * 255))

  defp put_opacity({r, g, b, _a}, opacity) when is_integer(opacity), do: {r, g, b, opacity}

  defp simplify_color(nil), do: nil
  defp simplify_color({r, g, b, 255}), do: {r, g, b}
  defp simplify_color({r, g, b, a}), do: {r, g, b, a}

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

  defp parse_color(nil), do: nil
  defp parse_color("none"), do: nil

  defp parse_color(<<"#", r::binary-size(2), g::binary-size(2), b::binary-size(2)>>) do
    {red, ""} = Integer.parse(r, 16)
    {green, ""} = Integer.parse(g, 16)
    {blue, ""} = Integer.parse(b, 16)
    {red, green, blue, 255}
  end

  defp parse_color(
         <<"#", r::binary-size(2), g::binary-size(2), b::binary-size(2), a::binary-size(2)>>
       ) do
    {red, ""} = Integer.parse(r, 16)
    {green, ""} = Integer.parse(g, 16)
    {blue, ""} = Integer.parse(b, 16)
    {alpha, ""} = Integer.parse(a, 16)
    {red, green, blue, alpha}
  end

  defp parse_color(<<"#", r::binary-size(1), g::binary-size(1), b::binary-size(1)>>) do
    # trunc(255.0 / 0xF)
    coeff = 17
    {red, ""} = Integer.parse(r, 16)
    {green, ""} = Integer.parse(g, 16)
    {blue, ""} = Integer.parse(b, 16)
    {red * coeff, green * coeff, blue * coeff, 255}
  end

  defp parse_color(
         <<"#", r::binary-size(1), g::binary-size(1), b::binary-size(1), a::binary-size(1)>>
       ) do
    # trunc(255.0 / 0xF)
    coeff = 17
    {red, ""} = Integer.parse(r, 16)
    {green, ""} = Integer.parse(g, 16)
    {blue, ""} = Integer.parse(b, 16)
    {alpha, ""} = Integer.parse(a, 16)
    {red * coeff, green * coeff, blue * coeff, alpha * coeff}
  end

  defp parse_color(name) when is_binary(name) do
    normalized_name = name |> String.replace(" ", "") |> String.downcase()

    Colors.colors()
    |> Map.get(normalized_name)
    |> then(fn
      {r, g, b} -> {r, g, b, 255}
      nil -> nil
    end)
  end
end

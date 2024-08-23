defmodule Scenic.FromSVG do
  @moduledoc """
  Derives `Scenic.Primitives` from Scalable Vector Graphics (SVG).
  """

  import SweetXml

  @spec svg_to_mfas(binary()) :: [mfa()]

  @doc """
  Parses the SVG into a list of MFAs (Module, Function, Arguments), each
  representing a Scenic primitive. We use MFAs in order to make testing and serialization
  trivial.

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
      ...> |> Scenic.FromSVG.svg_to_mfas()
      [
        {Scenic.Primitives, :rect, [{100.0, 100.0}, [fill: {255, 0, 0, 255}, t: {10.0, 10.0} ]]},
        {Scenic.Primitives, :text, ["Hello", [fill: {0, 0, 0, 255}, font_size: 64, text_align: :left, font: :roboto, t: {80, 80}]]},
        {Scenic.Primitives, :circle, [20.0, [fill: {173, 28, 28, 181}, t: {180.0, 180.0}]]},
        {Scenic.Primitives, :path, [[:begin, {:move_to, 458.94046, 243.85936}, {:line_to, 498.94046, 243.85936}, {:line_to, 518.94046, 278.49936}, {:line_to, 498.94046000000003, 313.13936}, {:line_to, 458.94046000000003, 313.13936}, {:line_to, 438.94046000000003, 278.49936}, :close_path], [{:fill, {255, 255, 255, 255}}]]},
        {Scenic.Primitives, :path, [[:begin, {:move_to, 218.94046, 243.85936}, {:line_to, 258.94046000000003, 243.85936}, {:line_to, 278.94046000000003, 278.49936}, {:line_to, 258.94046000000003, 313.13936}, {:line_to, 218.94046000000003, 313.13936}, {:line_to, 198.94046000000003, 278.49936}, :close_path], [{:fill, {255, 255, 255, 255}}]]}
      ]

  """

  def svg_to_mfas(svg) when is_binary(svg) do
    {:xmlElement, :svg, :svg, _, _, _, _, _attrs, children, _, _, _} =
      svg |> parse() |> xpath(~x"///svg"e)

    children
    |> Enum.flat_map(&node_to_mfa/1)
  end

  @spec draw_svg(Scenic.Graph.t(), binary()) :: Scenic.Graph.t()

  @doc """
  Draws all supported primitives of a SVG to a `Scenic.Graph`.
  """

  def draw_svg(graph, svg) do
    svg
    |> svg_to_mfas()
    |> Enum.reduce(graph, fn {m, f, a}, graph -> apply(m, f, [graph | a]) end)
  end

  defp node_to_mfa({:xmlElement, :rect, :rect, _, _, _, _, _, [], _, _, _} = node) do
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

    [{Scenic.Primitives, :rect, [{width, height}, opts]}]
  end

  defp node_to_mfa({:xmlElement, :circle, :circle, _, _, _, _, _, [], _, _, _} = node) do
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

    [{Scenic.Primitives, :circle, [r, opts]}]
  end

  defp node_to_mfa({:xmlElement, :text, :text, _, _, _, _, _, _, _, _, _} = node) do
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

        {Scenic.Primitives, :text, [text_value, opts]}
    end)
  end

  defp node_to_mfa({:xmlElement, :path, :path, _, _, _, _, _, _, _, _, _} = node) do
    [path_to_mfa(node, %{})]
  end

  defp node_to_mfa({:xmlElement, :g, :g, _, _, _, _, _, _, _, _, _} = node) do
    node_style = parse_style(node)

    node
    |> xpath(~x"./path"el)
    |> Enum.map(&path_to_mfa(&1, node_style))
  end

  defp node_to_mfa(_node), do: []

  defp path_to_mfa(path, node_style) do
    style = Map.merge(node_style, parse_style(path))
    _id = path |> xpath(~x"./@id"so)
    d = path |> xpath(~x"./@d"s)

    path_cmds =
      Scenic.FromSVG.Path.tokenize(d)
      |> Scenic.FromSVG.Path.reduce_tokens()

    opts =
      [
        fill_from_style(style),
        stroke_from_style(style)
      ]
      |> Enum.filter(& &1)

    {Scenic.Primitives, :path, [path_cmds, opts]}
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

  defp stroke_from_style(%{"stroke" => "none"}), do: nil

  defp stroke_from_style(
         %{"stroke" => stroke, "stroke-opacity" => stroke_opacity, "stroke-width" => stroke_width} =
           _style
       ) do
    case parse_color(stroke) do
      nil ->
        nil

      {r, g, b} ->
        {opacity, ""} = Float.parse(stroke_opacity)
        {width, ""} = Float.parse(stroke_width)
        {:stroke, {trunc(width), {r, g, b, trunc(opacity * 255)}}}
    end
  end

  defp stroke_from_style(_style), do: nil

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
end

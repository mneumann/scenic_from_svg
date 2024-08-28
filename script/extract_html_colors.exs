#!/usr/bin/env elixir

Mix.install([
  {:req, "~> 0.5.6"},
  {:floki, "~> 0.36.0"}
])

doc =
  File.read("css-color.html")
  |> then(fn
    {:ok, data} ->
      data

    _ ->
      data = Req.get!("https://drafts.csswg.org/css-color").body
      File.write!("css-color.html", data)
      data
  end)
  |> Floki.parse_document!()

colornames =
  doc
  |> Floki.find("table.named-color-table tbody th[scope=row] > dfn")
  |> Enum.map(fn node -> node |> Floki.text() |> String.trim() end)

colorvalues =
  doc
  |> Floki.find("table.named-color-table tbody th[scope=row] > td")
  |> Enum.map(fn {"td", _, [fst | _]} -> fst |> String.trim() end)
  |> Enum.map(fn <<"#", rh, rl, gh, gl, bh, bl>> ->
    {r, ""} = Integer.parse(<<rh, rl>>, 16)
    {g, ""} = Integer.parse(<<gh, gl>>, 16)
    {b, ""} = Integer.parse(<<bh, bl>>, 16)
    {r, g, b}
  end)

IO.puts("defmodule Scenic.FromSVG.Colors do")
IO.puts("  @colors %{")

Enum.zip(colornames, colorvalues)
|> Enum.each(fn {colorname, value} ->
  IO.puts("    #{inspect(colorname)} => #{inspect(value)},")
end)

IO.puts("  }")
IO.puts("")
IO.puts("  def colors(), do: @colors")
IO.puts("end")

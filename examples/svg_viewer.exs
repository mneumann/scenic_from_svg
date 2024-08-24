#!/usr/bin/env elixir

Mix.install([
  {:scenic_driver_local, "~> 0.12.0-rc.0"},
  {:scenic_from_svg, github: "mneumann/scenic_from_svg"}
])

Application.put_env(:scenic, :assets, module: Example.Assets)

defmodule Example.Assets do
  use Scenic.Assets.Static, otp_app: :scenic_from_svg
end

defmodule Example.Scene.Main do
  use Scenic.Scene
  alias Scenic.Graph
  import Scenic.Primitives

  def init(scene, svgfile, _opts) do
    svg_spec =
      svgfile
      |> File.read!()
      |> Scenic.FromSVG.svg_to_prim()
      |> Scenic.FromSVG.prim_spec()

    graph =
      Graph.build()
      |> rect(scene.viewport.size, fill: {255, 255, 255, 255})
      |> then(svg_spec)

    scene =
      scene
      |> push_graph(graph)

    {:ok, scene}
  end
end

defmodule Main do
  def main([svgfile]) do
    size = Scenic.FromSVG.svg_size(svgfile)

    main_viewport_config = [
      name: :main_viewport,
      size: {size.width, size.height},
      theme: :dark,
      default_scene: {Example.Scene.Main, svgfile},
      drivers: [
        [
          module: Scenic.Driver.Local,
          name: :local,
          window: [resizeable: true, title: "Scenic SVG Viewer"],
          on_close: :stop_system,
          cursor: true
        ]
      ]
    ]

    children = [
      {Scenic, [main_viewport_config]}
    ]

    {:ok, _} = Supervisor.start_link(children, strategy: :one_for_one)

    Process.sleep(:infinity)
  end
end

Main.main(System.argv)

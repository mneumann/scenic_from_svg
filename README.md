# Scenic.FromSVG - Derive Scenic primitives from SVG

* This library derives [Scenic][scenic] primitives from Scalable Vector
  Graphics (SVG), either at runtime or compile-time. To put in other
  words: It converts SVG into Scenic drawing primitives.

* SVG is used to leverage wide-spread and open-source tools like [Inkscape][inkscape].

* [Scenic][scenic] is a UI framework for [Elixir][elixir], mainly targeting embedded
  and fault-tolerant systems.

* [Elixir][elixir] is a language running on top of the
  [Erlang/OTP][erlang] platform, the latter of which is "used to build
  massively scalable soft real-time systems with requirements on high
  availability", quoting it's website.

* [Scenic primitives][scenic-primitives] are the drawing primitives
  offered by the Scenic framework. Examples for such primitives are:
  `circle`, `rect` or `text`. They more or less directly map to SVG
  primitives like `<circle>`, `<rect>` or `<text>`.

## Limitations

* This library is a quick-and-dirty, half-night-long proof-of-concept,
  implemented by looking at some Inkscape-generated SVGs and deriving some
  Elixir code from it, without ever having read the SVG spec thoughtfully
  myself. Though, the "concept" looks promising.

* Only `<circle>`, `<rect>`, `<text>`, `<g>` and `<path>` are somewhat
  implemented.

* `<text>` does not properly map font names (yet).

* Only tested with Inkscape-generated SVG.

## Use Cases

* This is *NOT* a general-purpose SVG viewer for Scenic!!!

* Rapid UI prototyping for Scenic. "Wireframing-Tool".

* Generate Elixir code from SVG, then hand-modify the generated code.

* My intended use case: Customers can use existing SVG-editors like
  Inkscape or web-based ones to design 80% of the scenes of their
  infotainment screens, either themselves or with the help of graphic
  artists. Based on these SVGs and this underlying library, deriving
  Elixir code becomes a lot easier and let's me concentrate on logic and
  dynamic functionality. It's a *tool*, not a 100% feature-full solution
  with shiny marketing brochures and mandatory training courses.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `scenic_from_svg` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:scenic_from_svg, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/scenic_from_svg>.

[inkscape]: https://inkscape.org/
[scenic]: https://hexdocs.pm/scenic/welcome.html
[scenic-primitives]: https://hexdocs.pm/scenic/0.12.0-rc.0/Scenic.Primitives.html
[elixir]: https://elixir-lang.org/
[erlang]: https://erlang.org/


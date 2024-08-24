defmodule ScenicFromSvg.MixProject do
  use Mix.Project

  def project do
    [
      app: :scenic_from_svg,
      version: "0.1.0-rc.0",
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      # build_embedded: true,
      description: description(),
      package: package(),
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: []
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:scenic, "~> 0.12.0-rc.0"},
      {:sweet_xml, "~> 0.7.2"},
      {:ex_doc, "~> 0.31.0", only: :dev},
      {:scenic_driver_local, "~> 0.12.0-rc.0", only: [:dev, :test]},
      # This override fixes "gmake" vs "make" on DragonFlyBSD
      {:elixir_make, "~> 0.8.4", override: true, only: [:dev, :test]}
    ]
  end

  defp description() do
    """
    Derive Scenic drawing primitives from Scalable Vector Graphics (SVG).
    """
  end

  defp package() do
    [
      files: ["lib", "mix.exs", "README.md", "CHANGELOG.md", "LICENSE"],
      maintainers: ["Michael Neumann"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/mneumann/scenic_from_svg"}
    ]
  end
end

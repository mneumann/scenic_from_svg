defmodule ScenicFromSvgTest do
  use ExUnit.Case
  doctest Scenic.FromSVG

  @commit_fixtures true

  test "it converts example/input.svg" do
    test_fixture("example")
    test_fixture("simple")
  end

  defp test_fixture(fixture) do
    input_svg_file = Path.join(["test", "fixtures", fixture, "input.svg"])
    expected_prim_file = Path.join(["test", "fixtures", fixture, "expected.prim"])

    given_prim =
      File.read!(input_svg_file)
      |> Scenic.FromSVG.svg_to_prim()
      |> inspect(pretty: true, limit: :infinity)

    expected_prim = File.read!(expected_prim_file)

    if @commit_fixtures and given_prim != expected_prim do
      File.write!(expected_prim_file, given_prim)
    end

    assert given_prim == expected_prim
  end
end

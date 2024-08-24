defmodule ScenicFromSvgTest do
  use ExUnit.Case
  doctest Scenic.FromSVG

  @commit_fixtures true

  test "it converts fixtures" do
    Path.wildcard("test/fixtures/*")
    |> Enum.each(&test_fixture/1)
  end

  defp test_fixture(fixture_path) do
    input_svg_file = Path.join([fixture_path, "input.svg"])
    expected_prim_file = Path.join([fixture_path, "expected.prim"])

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

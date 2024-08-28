defmodule ScenicFromSvgTest do
  use ExUnit.Case
  doctest Scenic.FromSVG

  @commit_fixtures true

  test "it converts fixtures" do
    Path.wildcard("test/fixtures/*")
    |> Enum.map(&test_fixture/1)
    |> Enum.each(fn {given, expected} -> assert given == expected end)
  end

  defp test_fixture(fixture_path) do
    input_svg_file = Path.join([fixture_path, "input.svg"])
    expected_ex_file = Path.join([fixture_path, "expected.ex"])

    given_ex =
      File.read!(input_svg_file)
      |> Scenic.FromSVG.SVG.from_string()
      |> inspect(pretty: true, limit: :infinity)

    expected_ex = File.read!(expected_ex_file)

    if @commit_fixtures and given_ex != expected_ex do
      File.write!(expected_ex_file, given_ex)
    end

    {given_ex, expected_ex}
  end
end

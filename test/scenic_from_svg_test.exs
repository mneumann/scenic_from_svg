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
    expected_txt_file = Path.join([fixture_path, "expected.txt"])

    given_txt =
      File.read!(input_svg_file)
      |> Scenic.FromSVG.SVG.from_string()
      |> inspect(pretty: true, limit: :infinity)

    expected_txt = File.read!(expected_txt_file)

    if @commit_fixtures and given_txt != expected_txt do
      File.write!(expected_txt_file, given_txt)
    end

    {given_txt, expected_txt}
  end
end

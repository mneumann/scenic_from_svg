defmodule ScenicFromSvgTest do
  use ExUnit.Case
  doctest Scenic.FromSVG

  @commit_fixtures false

  test "it converts example/input.svg" do
    test_fixture "test/fixtures/example/input.svg", "test/fixtures/example/expected.mfa"
  end

  defp test_fixture(input_svg_file, expected_mfa_file) do
    given_mfa = File.read!(input_svg_file) |> Scenic.FromSVG.svg_to_mfas() |> inspect
    expected_mfa = File.read!(expected_mfa_file)
    if @commit_fixtures and given_mfa != expected_mfa do
      File.write!(expected_mfa_file, given_mfa)
    end
    assert given_mfa == expected_mfa
  end
end

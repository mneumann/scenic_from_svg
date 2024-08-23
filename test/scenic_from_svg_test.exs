defmodule ScenicFromSvgTest do
  use ExUnit.Case
  doctest Scenic.FromSVG

  test "it converts example/input.svg" do
    mfa = File.read!("test/fixtures/example/input.svg") |> Scenic.FromSVG.svg_to_mfas()
    assert inspect(mfa) == File.read!("test/fixtures/example/expected.mfa")
  end
end

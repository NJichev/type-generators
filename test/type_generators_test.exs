defmodule TypeGeneratorsTest do
  use ExUnit.Case
  doctest TypeGenerators

  test "greets the world" do
    assert TypeGenerators.hello() == :world
  end
end

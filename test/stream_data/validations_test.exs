defmodule StreamData.ValidationsTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  import StreamDataTypes
  alias StreamDataTest.Functions

  describe "function validation" do
    test "simple functions" do
      assert {:ok, _} = validate(Kernel, :is_integer, 1)
    end

    test "passes when function has no_return" do
      assert {:ok, _} = validate(Functions, :test_no_return, 1)
    end
  end
end

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

    test "type names" do
      assert {:ok, _} = validate(Functions, :test_names, 3)
    end

    test "type guards" do
      assert {:ok, _} = validate(Functions, :test_guards, 1)
      assert {:ok, _} = validate(Functions, :test_multiple_guards, 3)
    end

    test "overloaded specs" do
      assert {:ok, results} = validate(Functions, :test_overloaded_spec, 1)
      assert length(results) == 2
    end

    test "catches functions without no_return" do
      assert {:error, [%{original_failure: :unspecified_no_return}]} =
               validate(Functions, :test_missing_no_return, 1)
    end

    test "catches functions with wrong return type" do
      assert {:error, [%{original_failure: {_args, return}}]} =
               validate(Functions, :test_wrong_return, 1)

      assert :foo = return
    end

    test "overloaded with variables" do
      assert {:ok, results} = validate(Functions, :test_overloaded_with_var, 2)
      assert length(results) == 2
    end
  end

  test "missing function spec" do
    assert_raise(ArgumentError, ~r/Missing type specification for function/, fn ->
      validate(Functions, :does_not_exist, 0)
    end)
  end

  test "missing module" do
    assert_raise(ArgumentError, ~r/Could not find .beam file for/, fn ->
      validate(DoesNotExist, :function, 1)
    end)
  end
end

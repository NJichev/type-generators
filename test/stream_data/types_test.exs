defmodule StreamData.TypesTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias StreamDataTypes, as: Types

  test "when missing a type" do
    assert_raise(
      ArgumentError,
      "Module StreamDataTest.TypesList does not define a type called does_not_exist.\n",
      fn -> generate_data(:does_not_exist) end
    )
  end

  test "when missing a module" do
    assert_raise(
      ArgumentError,
      """
      Could not find .beam file for Module DoesNotExist.
      Are you sure you have passed in the correct module name?
      """,
      fn ->
        Types.from_type(DoesNotExist, :some_type)
      end
    )
  end

  test "a type is returned" do
    assert {:basic_atom, {:type, _line, :atom, []}} = generate_data(:basic_atom)
  end

  defp generate_data(name, args \\ []) do
    Types.from_type(StreamDataTest.TypesList, name, args)
  end
end

defmodule StreamData.TypesTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias StreamDataTypes, as: Types

  test "raises when missing a type" do
    assert_raise(
      ArgumentError,
      "Module StreamDataTest.TypesList does not define type does_not_exist/0.\n",
      fn -> generate_data(:does_not_exist) end
    )
  end

  test "raises when missing a module" do
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

  test "raises when wrong number of arguments given" do
    assert_raise(ArgumentError, "Wrong amount of arguments passed.", fn ->
      generate_data(:basic_atom, v: :integer)
    end)
  end

  describe "basic types" do
    test "any" do
      data = generate_data(:basic_any)

      check all term <- data, max_runs: 25 do
        assert is_term(term)
      end
    end

    test "atom" do
      data = generate_data(:basic_atom)

      check all x <- data, do: assert(is_atom(x))
    end

    # Numbers
    test "float" do
      data = generate_data(:basic_float)

      check all x <- data do
        assert is_float(x)
      end
    end

    test "integer" do
      data = generate_data(:basic_integer)

      check all x <- data, do: assert(is_integer(x))
    end

    test "pos_integer" do
      data = generate_data(:basic_pos_integer)

      check all x <- data do
        assert is_integer(x)
        assert x > 0
      end
    end

    test "non_neg_integer" do
      data = generate_data(:basic_non_neg_integer)

      check all x <- data do
        assert is_integer(x)
        assert x >= 0
      end
    end

    test "neg_integer" do
      data = generate_data(:basic_neg_integer)

      check all x <- data do
        assert is_integer(x)
        assert x < 0
      end
    end
  end

  describe "built-in" do
    test "term" do
      data = generate_data(:builtin_term)

      check all term <- data, max_runs: 25 do
        assert is_term(term)
      end
    end
  end

  defp is_term(t) do
    is_boolean(t) or is_integer(t) or is_float(t) or is_binary(t) or is_atom(t) or is_reference(t) or
      is_list(t) or is_map(t) or is_tuple(t)
  end

  defp generate_data(name, args \\ []) do
    Types.from_type(StreamDataTest.TypesList, name, args)
  end
end

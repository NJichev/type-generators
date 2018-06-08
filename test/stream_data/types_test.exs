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
    assert_raise(
      ArgumentError,
      "Wrong amount of arguments passed.",
      fn ->
        generate_data(:basic_atom, v: :integer)
      end
    )
  end

  describe "basic types" do
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

  describe "builtin" do
    test "arity" do
      data = generate_data(:builtin_arity)

      check all x <- data do
        assert is_integer(x)
        assert x in 0..255
      end
    end

    test "binary" do
      data = generate_data(:builtin_binary)

      check all x <- data, do: assert(is_binary(x))
    end

    test "bitstring" do
      data = generate_data(:builtin_bitstring)

      check all x <- data, do: assert(is_bitstring(x))
    end

    test "boolean" do
      data = generate_data(:builtin_boolean)

      check all x <- data, do: assert(is_boolean(x))
    end

    test "byte" do
      data = generate_data(:builtin_byte)

      check all x <- data do
        assert is_integer(x)
        assert x in 0..255
      end
    end

    test "char" do
      data = generate_data(:builtin_char)

      check all x <- data do
        assert is_integer(x)
        assert x in 0..0x10FFFF
      end
    end

    test "charlist" do
      data = generate_data(:builtin_charlist)

      check all x <- data do
        assert is_list(x)

        assert Enum.all?(x, &(&1 in 0..0x10FFFF))
      end
    end

    test "nonempty charlist" do
      data = generate_data(:builtin_nonempty_charlist)

      check all x <- data do
        assert is_list(x)
        assert x != []

        assert Enum.all?(x, &(&1 in 0..0x10FFFF))
      end
    end

    test "iodata" do
      data = generate_data(:builtin_iodata)

      check all x <- data do
        assert is_binary(x) or is_iolist(x)
      end
    end


    test "iolist" do
      data = generate_data(:builtin_iolist)

      check all x <- data do
        assert is_iolist(x)
      end
    end

    test "mfa" do
      data = generate_data(:builtin_mfa)

      check all {module, function, arity} <- data, max_runs: 25 do
        assert is_atom(module)
        assert is_atom(function)
        assert is_integer(arity)
        assert arity in 0..255
      end
    end

    test "module" do
      data = generate_data(:builtin_module)

      check all x <- data, do: assert is_atom(x)
    end

    test "node" do
      data = generate_data(:builtin_node)

      check all x <- data, do: assert is_atom(x)
    end

    test "number" do
      data = generate_data(:builtin_number)

      check all x <- data, do: assert is_number(x)
    end

    test "timeout" do
      data = generate_data(:builtin_timeout)

      check all x <- data do
        assert x == :infinity or is_integer(x)
      end
    end
  end

  defp is_iolist([]), do: true
  defp is_iolist(x) when is_binary(x), do: true
  defp is_iolist([x|xs]) when x in 0..255, do: is_iolist(xs)
  defp is_iolist([x|xs]) when is_binary(x), do: is_iolist(xs)
  defp is_iolist([x|xs]) do
    case is_iolist(x) do
      true -> is_iolist(xs)
      _ -> false
    end
  end
  defp is_iolist(_), do: false

  defp generate_data(name, args \\ []) do
    Types.from_type(StreamDataTest.TypesList, name, args)
  end
end

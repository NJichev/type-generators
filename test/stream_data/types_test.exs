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
    test "none" do
      assert_raise(ArgumentError, "Cannot generate types of the none type.", fn ->
        generate_data(:basic_none)
      end)
    end

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

    test "map" do
      data = generate_data(:basic_map)

      # Check that not all generated maps are empty
      assert Enum.take(data, 5)
             |> Enum.map(&map_size(&1))
             |> Enum.sum() > 0

      check all x <- data, max_runs: 25 do
        assert is_map(x)
      end
    end

    test "reference" do
      data = generate_data(:basic_reference)

      check all x <- data, do: assert(is_reference(x))
    end

    test "tuple" do
      data = generate_data(:basic_tuple)

      check all x <- data, max_runs: 25 do
        assert is_tuple(x)
      end
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

    test "lists" do
      data = generate_data(:basic_list_type)

      check all list <- data, max_runs: 25 do
        assert is_list(list)
        assert Enum.all?(list, fn x -> is_integer(x) end)
      end
    end

    test "basic nonempty list" do
      data = generate_data(:basic_nonempty_list_type)

      check all list <- data, max_runs: 25 do
        assert is_list(list)
        assert length(list) > 0
        assert Enum.all?(list, fn x -> is_integer(x) end)
      end
    end

    test "maybe_improper_list" do
      data = generate_data(:basic_maybe_improper_list_type)

      check all list <- data do
        each_improper_list(list, &assert(is_integer(&1)), &assert(is_float(&1) or is_integer(&1)))
      end
    end

    test "nonempty_improper_list" do
      data = generate_data(:basic_nonempty_improper_list_type)

      check all list <- data do
        assert list != []
        each_improper_list(list, &assert(is_integer(&1)), &assert(is_float(&1)))
      end
    end

    test "nonempty_maybe_improper_list" do
      data = generate_data(:basic_nonempty_maybe_improper_list_type)

      check all list <- data do
        assert list != []
        each_improper_list(list, &assert(is_integer(&1)), &assert(is_float(&1) or is_integer(&1)))
      end
    end

    test "nested lists" do
      data = generate_data(:nested_list_type)

      check all list <- data, max_runs: 25 do
        assert is_list(list)

        Enum.each(list, fn x ->
          assert is_list(x)
          assert Enum.all?(x, &is_integer(&1))
        end)
      end
    end

    test "nested nonempty list" do
      data = generate_data(:nested_nonempty_list_type)

      check all list <- data, max_runs: 25 do
        assert is_list(list)
        assert length(list) > 0

        Enum.each(list, fn x ->
          assert is_list(x)
          assert Enum.all?(x, &is_integer(&1))
        end)
      end
    end
  end

  describe "builtin" do
    test "list" do
      data = generate_data(:builtin_list)

      check all x <- data, max_runs: 25 do
        assert is_list(x)
      end
    end

    test "nonempty_list" do
      data = generate_data(:builtin_nonempty_list)

      check all x <- data, max_runs: 25 do
        assert is_list(x)
        assert x != []
      end
    end

    test "maybe_improper_list" do
      data = generate_data(:builtin_maybe_improper_list)

      check all list <- data, max_runs: 25 do
        each_improper_list(list, &assert(is_term(&1)), &assert(is_term(&1)))
      end
    end

    test "nonempty_maybe_improper_list" do
      data = generate_data(:builtin_nonempty_maybe_improper_list)

      check all list <- data, max_runs: 25 do
        assert list != []
        each_improper_list(list, &assert(is_term(&1)), &assert(is_term(&1)))
      end
    end
  end

  describe "literals" do
    test "list type" do
      data = generate_data(:literal_list_type)

      check all x <- data do
        assert is_list(x)
        assert Enum.all?(x, &is_integer(&1))
      end
    end

    test "empty list" do
      data = generate_data(:literal_empty_list)

      check all x <- data do
        assert x == []
      end
    end

    test "nonempty list" do
      data = generate_data(:literal_list_nonempty)

      check all x <- data, max_runs: 25 do
        assert is_list(x)
        assert x != []
      end
    end

    test "nonempty list with type" do
      data = generate_data(:literal_nonempty_list_type)

      check all x <- data, max_runs: 25 do
        assert is_list(x)
        assert x != []
        assert Enum.all?(x, &is_float(&1))
      end
    end

    test "empty map" do
      data = generate_data(:literal_empty_map)

      check all x <- data do
        assert x == %{}
      end
    end

    test "map with fixed key" do
      data = generate_data(:literal_map_with_key)

      check all x <- data, max_runs: 25 do
        assert is_map(x)
        %{key: int} = x
        assert is_integer(int)
      end
    end

    test "map with optional key" do
      data = generate_data(:literal_map_with_optional_key)

      check all x <- data, max_runs: 25 do
        assert is_map(x)

        assert Map.keys(x) |> Enum.all?(fn k -> is_float(k) end)
        assert Map.values(x) |> Enum.all?(fn v -> is_integer(v) end)
      end
    end

    test "map with required keys" do
      data = generate_data(:literal_map_with_required_key)

      check all x <- data, max_runs: 25 do
        assert is_map(x)
        assert x != %{}

        assert Map.keys(x) |> Enum.all?(fn k -> is_float(k) end)
        assert Map.values(x) |> Enum.all?(fn v -> is_integer(v) end)
      end
    end

    test "map with required and optional key" do
      data = generate_data(:literal_map_with_required_and_optional_key)

      check all x <- data, max_runs: 25 do
        assert is_map(x)

        %{key: int} = x
        map = Map.delete(x, :key)
        assert is_integer(int)

        assert Map.keys(map) |> Enum.all?(fn k -> is_float(k) end)
        assert Map.values(map) |> Enum.all?(fn v -> is_integer(v) end)
      end
    end

    test "empty tuple" do
      data = generate_data(:literal_empty_tuple)

      check all x <- data, do: assert(x == {})
    end

    test "2 element tuple with fixed and random type" do
      data = generate_data(:literal_2_element_tuple)

      check all {int, float} <- data do
        assert is_integer(int)
        assert is_float(float)
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

    test "no_return" do
      assert_raise(ArgumentError, "Cannot generate types of the none type.", fn ->
        generate_data(:builtin_no_return)
      end)
    end

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

      check all x <- data, do: assert(is_atom(x))
    end

    test "node" do
      data = generate_data(:builtin_node)

      check all x <- data, do: assert(is_atom(x))
    end

    test "number" do
      data = generate_data(:builtin_number)

      check all x <- data, do: assert(is_number(x))
    end

    test "timeout" do
      data = generate_data(:builtin_timeout)

      check all x <- data do
        assert x == :infinity or is_integer(x)
      end
    end
  end

  defp each_improper_list([], _head_fun, _tail_fun), do: :ok

  defp each_improper_list([elem], _head_fun, tail_fun) do
    tail_fun.(elem)
  end

  defp each_improper_list([head | tail], head_fun, tail_fun) do
    head_fun.(head)

    if is_list(tail) do
      each_improper_list(tail, head_fun, tail_fun)
    else
      tail_fun.(tail)
    end
  end

  defp is_term(t) do
    is_boolean(t) or is_integer(t) or is_float(t) or is_binary(t) or is_atom(t) or is_reference(t) or
      is_list(t) or is_map(t) or is_tuple(t)
  end

  defp is_iolist([]), do: true
  defp is_iolist(x) when is_binary(x), do: true
  defp is_iolist([x | xs]) when x in 0..255, do: is_iolist(xs)
  defp is_iolist([x | xs]) when is_binary(x), do: is_iolist(xs)

  defp is_iolist([x | xs]) do
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

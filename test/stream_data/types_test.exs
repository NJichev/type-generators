defmodule StreamData.TypesTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias StreamDataTest.TypesList
  import StreamDataTypes

  test "raises when missing a type" do
    assert_raise(
      ArgumentError,
      "Module StreamDataTest.TypesList does not define type does_not_exist/0.",
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
        from_type(DoesNotExist, :some_type)
      end
    )
  end

  test "raises when wrong number of arguments given" do
    assert_raise(ArgumentError, ~r/Could not find type with/, fn ->
      generate_data(:basic_atom, [{StreamData.integer(), &is_integer/1}])
    end)
  end

  describe "basic types" do
    test "none" do
      assert_raise(ArgumentError, "Cannot generate types of the none type.", fn ->
        generate_data(:basic_none)
      end)
    end

    test "any" do
      {generator, member} = generate_data(:basic_any)

      check all term <- generator, max_runs: 25 do
        assert is_term(term)
        assert member.(term)
      end
    end

    test "atom" do
      {generator, member} = generate_data(:basic_atom)

      check all x <- generator,
                y <- term(),
                !is_atom(y),
                max_runs: 25 do
        assert is_atom(x)
        assert member.(x)
        refute member.(y)
      end
    end

    test "map" do
      {generator, member} = generate_data(:basic_map)

      # Check that not all generated maps are empty
      assert Enum.take(generator, 5)
             |> Enum.map(&map_size(&1))
             |> Enum.sum() > 0

      check all x <- generator,
                y <- term(),
                !is_map(y),
                max_runs: 25 do
        assert is_map(x)
        assert member.(x)
        refute member.(y)
      end
    end

    test "struct" do
      {generator, member} = generate_data(:basic_struct)

      refute member.(%{key: :bar})

      check all x <- generator,
                y <- term(),
                !is_map(y),
                max_runs: 25 do
        assert %_{} = x
        assert member.(x)
        refute member.(y)
      end
    end

    test "reference" do
      {generator, member} = generate_data(:basic_reference)

      check all x <- generator do
        assert is_reference(x)
        assert member.(x)
      end

      check all x <- term(), !is_reference(x) do
        refute member.(x)
      end
    end

    test "tuple" do
      {generator, member} = generate_data(:basic_tuple)

      check all x <- generator,
                y <- term(),
                !is_tuple(y),
                max_runs: 25 do
        assert is_tuple(x)
        assert member.(x)
        refute member.(y)
      end
    end

    test "pid" do
      assert_raise(ArgumentError, ~r/Pid\/Port types are not supported./, fn ->
        generate_data(:basic_pid)
      end)
    end

    test "port" do
      assert_raise(ArgumentError, ~r/Pid\/Port types are not supported./, fn ->
        generate_data(:basic_port)
      end)
    end

    # Numbers
    test "float" do
      {generator, member} = generate_data(:basic_float)

      check all x <- generator,
                y <- term(),
                !is_float(y),
                max_runs: 25 do
        assert is_float(x)
        assert member.(x)
        refute member.(y)
      end
    end

    test "integer" do
      {generator, member} = generate_data(:basic_integer)

      check all x <- generator,
                y <- term(),
                !is_integer(y) do
        assert is_integer(x)
        assert member.(x)
        refute member.(y)
      end
    end

    test "pos_integer" do
      {generator, member} = generate_data(:basic_pos_integer)

      check all x <- generator,
                y <- term(),
                !(is_integer(y) && y > 0) do
        assert is_integer(x)
        assert x > 0
        assert member.(x)
        refute member.(y)
      end
    end

    test "non_neg_integer" do
      {generator, member} = generate_data(:basic_non_neg_integer)

      check all x <- generator,
                y <- term(),
                !(is_integer(y) && y >= 0) do
        assert is_integer(x)
        assert x >= 0
        assert member.(x)
        refute member.(y)
      end
    end

    test "neg_integer" do
      {generator, member} = generate_data(:basic_neg_integer)

      check all x <- generator,
                y <- term(),
                !(is_integer(y) && y < 0) do
        assert is_integer(x)
        assert x < 0
        assert member.(x)
        refute member.(y)
      end
    end

    test "lists" do
      {generator, member} = generate_data(:basic_list_type)

      refute member.([:a])

      check all list <- generator,
                y <- term(),
                !is_list(y),
                max_runs: 25 do
        assert is_list(list)
        assert Enum.all?(list, fn x -> is_integer(x) end)
        assert member.(list)
        refute member.(y)
      end
    end

    test "basic nonempty list" do
      {generator, member} = generate_data(:basic_nonempty_list_type)

      refute member.([])
      refute member.([:a])

      check all list <- generator,
                y <- term(),
                !is_list(y),
                max_runs: 25 do
        assert is_list(list)
        assert length(list) > 0
        assert Enum.all?(list, fn x -> is_integer(x) end)
        assert member.(list)
        refute member.(y)
      end
    end

    test "maybe_improper_list" do
      {generator, member} = generate_data(:basic_maybe_improper_list_type)

      check all list <- generator,
                y <- term(),
                !is_list(y) do
        each_improper_list(list, &assert(is_integer(&1)), &assert(is_float(&1) or is_integer(&1)))
        assert member.(list)
        refute member.(y)
        refute member.([1.0 | 1.0])
      end
    end

    test "nonempty_improper_list" do
      {generator, member} = generate_data(:basic_nonempty_improper_list_type)

      check all list <- generator,
                y <- term(),
                !is_list(y) do
        assert list != []
        each_improper_list(list, &assert(is_integer(&1)), &assert(is_float(&1)))
        assert member.(list)
        refute member.(y)
        refute member.([1.0 | 1.0])
      end
    end

    test "nonempty_maybe_improper_list" do
      {generator, member} = generate_data(:basic_nonempty_maybe_improper_list_type)

      check all list <- generator,
                y <- term(),
                !is_list(y) do
        assert list != []
        each_improper_list(list, &assert(is_integer(&1)), &assert(is_float(&1) or is_integer(&1)))
        assert member.(list)
        refute member.(y)
        refute member.([1.0 | 1.0])
      end
    end

    test "nested lists" do
      {generator, member} = generate_data(:nested_list_type)

      refute member.([1])
      refute member.([[1.0]])

      check all list <- generator,
                y <- term(),
                !is_list(y),
                max_runs: 25 do
        assert is_list(list)

        Enum.each(list, fn x ->
          assert is_list(x)
          assert Enum.all?(x, &is_integer(&1))
        end)

        assert member.(list)
        refute member.(y)
      end
    end

    test "nested nonempty list" do
      {generator, member} = generate_data(:nested_nonempty_list_type)

      refute member.([1])
      refute member.([[1.0]])

      check all list <- generator,
                y <- term(),
                !is_list(y),
                max_runs: 25 do
        assert is_list(list)
        assert length(list) > 0

        Enum.each(list, fn x ->
          assert is_list(x)
          assert Enum.all?(x, &is_integer(&1))
        end)

        assert member.(list)
        refute member.(y)
      end
    end
  end

  describe "builtin" do
    test "list" do
      {generator, member} = generate_data(:builtin_list)

      check all x <- generator,
                y <- term(),
                !is_list(y),
                max_runs: 25 do
        assert is_list(x)
        assert member.(x)
        refute member.(y)
      end
    end

    test "nonempty_list" do
      {generator, member} = generate_data(:builtin_nonempty_list)

      check all x <- generator,
                y <- term(),
                !(is_list(y) && y != []),
                max_runs: 25 do
        assert is_list(x)
        assert length(x) > 0
        assert member.(x)
        refute member.(y)
      end
    end

    test "maybe_improper_list" do
      {generator, member} = generate_data(:builtin_maybe_improper_list)

      check all list <- generator,
                y <- term(),
                !is_list(y),
                max_runs: 25 do
        each_improper_list(list, &assert(is_term(&1)), &assert(is_term(&1)))
        assert member.(list)
        refute member.(y)
      end
    end

    test "nonempty_maybe_improper_list" do
      {generator, member} = generate_data(:builtin_nonempty_maybe_improper_list)

      check all list <- generator,
                y <- term(),
                !is_list(y),
                max_runs: 25 do
        assert list != []
        each_improper_list(list, &assert(is_term(&1)), &assert(is_term(&1)))
        assert member.(list)
        refute member.(y)
      end
    end
  end

  describe "literals" do
    test "list type" do
      {generator, member} = generate_data(:literal_list_type)

      refute member.([1, -1.0])

      check all x <- generator,
                y <- term(),
                !is_list(y) do
        assert is_list(x)
        assert Enum.all?(x, &is_integer(&1))
        assert member.(x)
        refute member.(y)
      end
    end

    test "empty list" do
      {generator, member} = generate_data(:literal_empty_list)

      assert member.([])

      check all x <- generator,
                y <- term(),
                !(y == []) do
        assert x == []
        refute member.(y)
      end
    end

    test "nonempty list" do
      {generator, member} = generate_data(:literal_list_nonempty)

      check all x <- generator,
                y <- term(),
                !is_list(y),
                max_runs: 25 do
        assert is_list(x)
        assert x != []
        assert member.(x)
        refute member.([])
        refute member.(y)
      end
    end

    test "nonempty list with type" do
      {generator, member} = generate_data(:literal_nonempty_list_type)

      check all x <- generator,
                y <- term(),
                !is_list(y),
                max_runs: 25 do
        assert is_list(x)
        assert x != []
        assert Enum.all?(x, &is_float(&1))
        assert member.(x)
        refute member.([1])
        refute member.(y)
      end
    end

    test "empty map" do
      {generator, member} = generate_data(:literal_empty_map)

      assert member.(%{})

      check all x <- generator,
                y <- term(),
                !(y == %{}) do
        assert x == %{}
        refute member.(y)
      end
    end

    test "map with fixed key" do
      {generator, member} = generate_data(:literal_map_with_key)

      refute member.(%{key: :foo})

      check all x = %{key: int} <- generator,
                y <- term(),
                !is_map(y),
                max_runs: 25 do
        assert is_integer(int)
        assert member.(x)
        refute member.(y)
      end
    end

    test "map with optional key" do
      {generator, member} = generate_data(:literal_map_with_optional_key)

      refute member.(%{1.0 => :foo})
      refute member.(%{:foo => -1})

      check all x <- generator,
                y <- term(),
                !is_map(y),
                max_runs: 25 do
        assert is_map(x)

        assert Enum.all?(x, fn {k, v} ->
                 is_float(k) && is_integer(v)
               end)

        assert member.(x)
        refute member.(y)
      end
    end

    test "map with required keys" do
      {generator, member} = generate_data(:literal_map_with_required_key)

      refute member.(%{})
      refute member.(%{1.0 => :foo})
      refute member.(%{:foo => -1})

      check all x <- generator, max_runs: 25 do
        assert is_map(x)
        assert x != %{}

        assert Enum.all?(x, fn {k, v} ->
                 is_float(k) && is_integer(v)
               end)

        assert member.(x)
      end
    end

    test "map with required and optional key" do
      {generator, member} = generate_data(:literal_map_with_required_and_optional_key)

      refute member.(%{1.0 => 1})

      check all x <- generator,
                y <- term(),
                !is_map(y),
                max_runs: 25 do
        assert is_map(x)

        %{key: int} = x
        map = Map.delete(x, :key)
        assert is_integer(int)

        assert Enum.all?(map, fn {k, v} ->
                 is_float(k) && is_integer(v)
               end)

        assert member.(x)
        refute member.(y)
      end
    end

    test "struct with all fields any type" do
      {generator, member} = generate_data(:literal_struct_all_fields_any_type)

      refute member.(%{key: :bar})

      check all x <- generator,
                y <- term(),
                !is_map(y),
                max_runs: 25 do
        assert %StreamDataTest.TypesList.SomeStruct{key: value} = x
        assert is_term(value)
        assert member.(x)
        refute member.(y)
      end
    end

    test "struct with all fields key type" do
      {generator, member} = generate_data(:literal_struct_all_fields_key_type)

      check all x <- generator,
                y <- term(),
                !is_map(y),
                max_runs: 25 do
        assert %StreamDataTest.TypesList.SomeStruct{key: value} = x
        assert is_integer(value)
        assert member.(x)
        refute member.(y)
      end
    end

    test "empty tuple" do
      {generator, member} = generate_data(:literal_empty_tuple)

      assert member.({})

      check all x <- generator,
                y <- term(),
                !(y == {}) do
        assert x == {}
        refute member.(y)
      end
    end

    test "2 element tuple with fixed and random type" do
      {generator, member} = generate_data(:literal_2_element_tuple)

      check all x = {int, float} <- generator,
                y <- term(),
                !(is_tuple(y) && tuple_size(y) == 2) do
        assert is_integer(int)
        assert is_float(float)
        assert member.(x)
        refute member.(y)
      end
    end

    test "atom" do
      {generator, member} = generate_data(:literal_atom)

      assert member.(:atom)

      check all x <- generator,
                y <- term(),
                !(y == :atom) do
        assert x == :atom
        refute member.(y)
      end
    end

    test "special atom" do
      {generator, member} = generate_data(:literal_special_atom)

      assert member.(false)

      check all x <- generator,
                y <- term(),
                !(y == false) do
        assert x == false
        refute member.(y)
      end
    end

    test "integer" do
      {generator, member} = generate_data(:literal_integer)

      assert member.(1)

      check all x <- generator,
                y <- term(),
                !(y == 1) do
        assert x == 1
        refute member.(y)
      end
    end

    test "range" do
      {generator, member} = generate_data(:literal_integers)

      check all x <- generator,
                y <- term(),
                !(is_integer(y) && y in 0..10) do
        assert is_integer(x)
        assert x in 0..10
        assert member.(x)
        refute member.(y)
      end
    end

    test "bitstrings" do
      {generator, member} = generate_data(:literal_empty_bitstring)

      assert member.("")

      check all x <- generator,
                y <- term(),
                y != "" do
        assert x == ""
        refute member.(y)
      end
    end

    test "bitstrings with size 0" do
      {generator, member} = generate_data(:literal_size_0)

      check all x <- generator,
                y <- term(),
                !(y == "") do
        assert "" == x
        assert member.(x)
        refute member.(y)
      end
    end

    test "bitstrings with unit 1" do
      {generator, member} = generate_data(:literal_unit_1)

      check all x <- generator,
                y <- term(),
                !is_bitstring(y) do
        assert is_bitstring(x)
        assert member.(x)
        refute member.(y)
      end
    end

    test "bitstrings with size 1 and unit 8" do
      {generator, member} = generate_data(:literal_size_1_unit_8)

      refute member.(<<209, 48, 176, 36>>)

      check all x <- generator,
                y <- term(),
                !is_bitstring(y) do
        size = bit_size(x)
        assert rem(size, 8) == 1
        assert member.(x)
        refute member.(y)
      end
    end
  end

  describe "built-in" do
    test "term" do
      {generator, member} = generate_data(:builtin_term)

      check all term <- generator, max_runs: 25 do
        assert is_term(term)
        assert member.(term)
      end
    end

    test "no_return" do
      assert_raise(ArgumentError, "Cannot generate types of the none type.", fn ->
        generate_data(:builtin_no_return)
      end)
    end

    test "arity" do
      {generator, member} = generate_data(:builtin_arity)

      check all x <- generator,
                y <- term(),
                !(is_integer(y) && y in 0..255) do
        assert is_integer(x)
        assert x in 0..255
        assert member.(x)
        refute member.(y)
      end
    end

    test "binary" do
      {generator, member} = generate_data(:builtin_binary)

      check all x <- generator,
                y <- term(),
                !is_binary(y) do
        assert is_binary(x)
        assert member.(x)
        refute member.(y)
      end
    end

    test "bitstring" do
      {generator, member} = generate_data(:builtin_bitstring)

      check all x <- generator,
                y <- term(),
                !is_bitstring(y) do
        assert is_bitstring(x)
        assert member.(x)
        refute member.(y)
      end
    end

    test "boolean" do
      {generator, member} = generate_data(:builtin_boolean)

      check all x <- generator,
                y <- term(),
                !is_boolean(y) do
        assert is_boolean(x)
        assert member.(x)
        refute member.(y)
      end
    end

    test "byte" do
      {generator, member} = generate_data(:builtin_byte)

      check all x <- generator,
                y <- term(),
                !(is_integer(y) && y in 0..255) do
        assert is_integer(x)
        assert x in 0..255
        assert member.(x)
        refute member.(y)
      end
    end

    test "char" do
      {generator, member} = generate_data(:builtin_char)

      check all x <- generator,
                y <- term(),
                !(is_integer(y) && y in 0..0x10FFFF) do
        assert is_integer(x)
        assert x in 0..0x10FFFF
        assert member.(x)
        refute member.(y)
      end
    end

    test "charlist" do
      {generator, member} = generate_data(:builtin_charlist)

      refute member.([-1, 5])

      check all x <- generator,
                y <- term(),
                !is_list(y) do
        assert is_list(x)
        assert Enum.all?(x, &(&1 in 0..0x10FFFF))
        assert member.(x)
        refute member.(y)
      end
    end

    test "nonempty charlist" do
      {generator, member} = generate_data(:builtin_nonempty_charlist)

      refute member.([-1, 5])

      check all x <- generator,
                y <- term(),
                !is_list(y) do
        assert is_list(x)
        assert x != []

        assert Enum.all?(x, &(&1 in 0..0x10FFFF))
        assert member.(x)
        refute member.(y)
      end
    end

    test "iodata" do
      {generator, member} = generate_data(:builtin_iodata)

      check all x <- generator,
                y <- term(),
                !(is_binary(y) or is_iolist(y)) do
        assert is_binary(x) or is_iolist(x)
        assert member.(x)
        refute member.(y)
      end
    end

    test "iolist" do
      {generator, member} = generate_data(:builtin_iolist)

      check all x <- generator,
                y <- term(),
                !is_iolist(y) do
        assert is_iolist(x)
        assert member.(x)
        refute member.(y)
      end
    end

    test "mfa" do
      {generator, member} = generate_data(:builtin_mfa)

      refute member.({:foo, :bar, :baz})

      check all x = {module, function, arity} <- generator,
                y <- term(),
                !(is_tuple(y) && tuple_size(y) == 3),
                max_runs: 25 do
        assert is_atom(module)
        assert is_atom(function)
        assert arity in 0..255
        assert member.(x)
        refute member.(y)
      end
    end

    test "module" do
      {generator, member} = generate_data(:builtin_module)

      check all x <- generator,
                y <- term(),
                !is_atom(y) do
        assert is_atom(x)
        assert member.(x)
        refute member.(y)
      end
    end

    test "node" do
      {generator, member} = generate_data(:builtin_node)

      check all x <- generator,
                y <- term(),
                !is_atom(y) do
        assert is_atom(x)
        assert member.(x)
        refute member.(y)
      end
    end

    test "number" do
      {generator, member} = generate_data(:builtin_number)

      check all x <- generator,
                y <- term(),
                !is_number(y) do
        assert is_number(x)
        assert member.(x)
        refute member.(y)
      end
    end

    test "timeout" do
      {generator, member} = generate_data(:builtin_timeout)

      check all x <- generator,
                y <- term(),
                !(y == :infinity or is_integer(y)) do
        assert x == :infinity or is_integer(x)
        assert member.(x)
        refute member.(y)
      end
    end
  end

  describe "remote types" do
    test "without parameters" do
      {generator, member} = generate_data(:remote_string)

      check all x <- generator,
                y <- term(),
                !is_bitstring(y) do
        assert is_bitstring(x)
        assert member.(x)
        refute member.(y)
      end
    end

    test "remote types with a passed in compile time parameter" do
      {generator, member} = generate_data(:remote_keyword_list)

      refute member.([1, 2, 3])

      check all keyword_list <- generator,
                y <- term(),
                !is_list(y) do
        assert is_list(keyword_list)

        Enum.each(keyword_list, fn {atom, integer} ->
          assert is_atom(atom)
          assert is_integer(integer)
        end)

        assert member.(keyword_list)
        refute member.(y)
      end
    end
  end

  describe "union types" do
    test "with two types" do
      {generator, member} = generate_data(:union_with_two)

      check all x <- generator,
                y <- term(),
                !(is_atom(y) or is_integer(y)) do
        assert is_atom(x) or is_integer(x)
        assert member.(x)
        refute member.(y)
      end
    end

    test "with three types" do
      {generator, member} = generate_data(:union_with_three)

      check all x <- generator,
                y <- term(),
                !(is_atom(y) or is_integer(y) or y == true) do
        assert is_atom(x) or is_integer(x) or x == true
        assert member.(x)
        refute member.(y)
      end
    end

    test "all basic types union" do
      {generator, member} = generate_data(:union_basic_types)

      check all x <- generator,
                y <- term(),
                !(is_atom(y) or is_reference(y) or is_integer(y) or is_float(y)) do
        assert is_atom(x) or is_reference(x) or is_integer(x) or is_float(x)
        assert member.(x)
        refute member.(y)
      end
    end

    test "with user defined type" do
      {generator, member} = generate_data(:union_with_user_defined_atom)

      check all x <- generator,
                y <- term(),
                !(is_atom(y) or is_integer(y)) do
        assert is_atom(x) or is_integer(x)
        assert member.(x)
        refute member.(y)
      end
    end

    test "with remote types" do
      {generator, member} = generate_data(:union_with_remote_types)

      check all x <- generator,
                y <- term(),
                !(is_integer(y) or is_bitstring(y)) do
        assert is_integer(x) or is_bitstring(x)
        assert member.(x)
        refute member.(y)
      end
    end
  end

  # Test that user defined types are inlined correctly
  describe "user defined types" do
    test "lists" do
      {generator, member} = generate_data(:user_defined_list)

      refute member.([1])

      check all list <- generator,
                y <- term(),
                !is_list(y),
                max_runs: 25 do
        assert is_list(list)
        assert Enum.all?(list, &is_atom(&1))
        assert member.(list)
        refute member.(y)
      end
    end

    test "map" do
      {generator, member} = generate_data(:user_defined_map)

      refute member.(%{atom: 1})

      check all map <- generator,
                y <- term(),
                !is_map(y),
                max_runs: 25 do
        assert %{atom: atom} = map
        assert is_atom(atom)
        assert member.(map)
        refute member.(y)
      end

      # Take 100 maps and check at least one has gotten a string: string key
      assert generator
             |> Enum.take(100)
             |> Enum.any?(fn %{string: string} ->
               is_bitstring(string)
             end)
    end

    test "tuples" do
      {generator, member} = generate_data(:user_defined_tuple)

      check all x = {:atom, atom} <- generator,
                y <- term(),
                !(is_tuple(y) && tuple_size(y) == 2) do
        assert is_atom(atom)
        assert member.(x)
        refute member.(y)
      end
    end
  end

  describe "recursive type" do
    test "list with tuples" do
      {generator, member} = generate_data(:recursive_tuple)

      refute member.({0, false})

      check all x <- generator,
                y <- term(),
                !is_recursive_tuple(y) do
        assert is_recursive_tuple(x)
        assert member.(x)
        refute member.(y)
      end
    end

    test "expressions" do
      {generator, member} = generate_data(:recursive_expression)

      check all x <- generator,
                y <- term(),
                !is_expression(y) do
        assert is_expression(x)
        assert member.(x)
        refute member.(y)
      end
    end

    test "integers with map container" do
      {generator, member} = generate_data(:recursive_integers)

      check all x <- generator,
                y <- term(),
                !is_recursive_integer(y) do
        assert is_recursive_integer(x)
        assert member.(x)
        refute member.(y)
      end
    end

    test "forests" do
      {generator, member} = generate_data(:recursive_forest)

      refute member.({0, [-1.0]})

      check all x <- generator,
                y <- term(),
                !is_forest(y) do
        assert is_forest(x)
        assert member.(x)
        refute member.(y)
      end
    end

    test "forest with maps" do
      {generator, member} = generate_data(:recursive_map_forest)

      # TODO: Figure out why maps generate so much duplicates
      check all x <- generator,
                y <- term(),
                !is_map_forest(y),
                max_runs: 1 do
        assert is_map_forest(x)
        assert member.(x)
        refute member.(y)
      end
    end
  end

  describe "protocols" do
    test "protocols are not to be generated" do
      assert_raise(
        ArgumentError,
        """
        You have specified a type which relies or is the protocol #{Enumerable}.
        Protocols are currently unsupported, instead try generating for the type which implements the protocol.
        """,
        fn -> generate_data(:protocol_enumerable) end
      )
    end

    test "types that expand to protocols are not to be generated" do
      assert_raise(
        ArgumentError,
        """
        You have specified a type which relies or is the protocol #{Enumerable}.
        Protocols are currently unsupported, instead try generating for the type which implements the protocol.
        """,
        fn -> generate_data(:protocol_enum) end
      )
    end
  end

  describe "parameterized types" do
    test "accepts only generators with a member function as arguments" do
      assert_raise(ArgumentError, ~r/Expected a StreamData generator/, fn ->
        generate_data(:parameterized_simple, [:integer])
      end)
    end

    test "you can pass in basic generators as arguments" do
      {generator, member} = generate_data(:parameterized_simple, [generate_data(:basic_atom)])

      check all atom <- generator,
                y <- term(),
                !is_atom(y) do
        assert is_atom(atom)
        assert member.(atom)
        refute member.(y)
      end
    end

    test "list arguments are passed in" do
      {generator, member} = generate_data(:parameterized_list, [generate_data(:basic_integer)])

      refute member.([:foo])

      check all list <- generator,
                y <- term(),
                !is_list(y) do
        assert is_list(list)
        assert Enum.all?(list, &is_integer/1)
        assert member.(list)
        refute member.(y)
      end
    end

    test "tuple container need correct size of arguments" do
      {generator, member} =
        generate_data(:parameterized_tuple, [
          generate_data(:basic_integer),
          generate_data(:basic_atom),
          {StreamData.constant(:key), &(&1 == :key)}
        ])

      check all x = {int, atom, :key} <- generator,
                y <- term(),
                !(is_tuple(y) && tuple_size(y) == 3) do
        assert is_integer(int)
        assert is_atom(atom)
        assert member.(x)
        refute member.(y)
      end
    end

    test "map container can be parameterized" do
      {generator, member} =
        generate_data(:parameterized_map, [
          generate_data(:basic_list_type)
        ])

      check all x = %{key: list} <- generator,
                y <- term(),
                !is_map(y) do
        assert is_list(list)
        assert Enum.all?(list, &is_integer/1)
        assert member.(x)
        refute member.(y)
      end
    end

    test "nested containers are parameterized" do
      {generator, member} =
        generate_data(:parameterized_dict, [
          generate_data(:basic_atom),
          generate_data(:basic_integer)
        ])

      check all x <- generator,
                y <- term(),
                !Keyword.keyword?(y) do
        assert is_list(x)

        Enum.each(x, fn {atom, int} ->
          assert is_atom(atom)
          assert is_integer(int)
        end)

        assert member.(x)
        refute member.(y)
      end
    end

    test "parameterized recursive types" do
      integers = generate_data(:basic_integer)
      {generator, member} = generate_data(:parameterized_recursive_tuple, [integers, integers])

      refute member.({0, 1.0})

      check all x <- generator,
                y <- term(),
                !is_recursive_tuple(y) do
        assert is_recursive_tuple(x)
        assert member.(x)
        refute member.(y)
      end
    end

    test "parameterized recursive types with map or list containers" do
      integers = generate_data(:basic_integer)
      {generator, member} = generate_data(:parameterized_recursive_forest, [integers, integers])

      refute member.({0, [<<90, 224, 68, 77, 88, 65, 12, 6, 163>>]})

      check all x <- generator,
                y <- term(),
                !is_forest(y) do
        assert is_forest(x)
        assert member.(x)
        refute member.(y)
      end
    end

    test "using remote types as arguments" do
      {generator, member} =
        generate_data(:parameterized_simple, [from_type_with_validator(String, :t)])

      check all x <- generator,
                y <- term(),
                !is_binary(y) do
        assert is_binary(x)
        assert member.(x)
        refute member.(y)
      end
    end

    test "using parameterized remote types" do
      {generator, member} = generate_data(:parameterized_keyword, [generate_data(:basic_float)])

      refute member.([1])

      check all list <- generator,
                y <- term(),
                !is_list(y) do
        assert is_list(list)

        Enum.each(list, fn {atom, float} ->
          assert is_atom(atom)
          assert is_float(float)
        end)

        assert member.(list)
        refute member.(y)
      end
    end

    test "using parameterized remote types with remote type arguments" do
      {generator, member} =
        generate_data(:parameterized_keyword, [
          from_type_with_validator(Keyword, :t, [{StreamData.integer(), &is_integer/1}])
        ])

      check all x <- generator,
                y <- term(),
                !Keyword.keyword?(y),
                max_runs: 25 do
        assert is_list(x)

        Enum.each(x, fn {atom, keyword_list} ->
          assert is_atom(atom)
          assert is_list(keyword_list)

          Enum.each(keyword_list, fn {atom, integer} ->
            assert is_atom(atom)
            assert is_integer(integer)
          end)
        end)

        assert member.(x)
        refute member.(y)
      end
    end
  end

  test "pid type validation" do
    member = type_validator_for(TypesList, :basic_pid)

    Process.list()
    |> Enum.each(&assert(member.(&1)))

    check all y <- term(), do: refute(member.(y))
  end

  test "port type validation" do
    member = type_validator_for(TypesList, :basic_port)

    Port.list()
    |> Enum.each(&assert(member.(&1)))

    check all y <- term(), do: refute(member.(y))
  end

  defp is_forest({x, forests}) when is_integer(x) and is_list(forests) do
    Enum.all?(forests, &is_forest/1)
  end

  defp is_forest(_), do: false

  defp is_map_forest(%{int: x, forests: forests}) when is_integer(x) and is_list(forests) do
    Enum.all?(forests, &is_map_forest/1)
  end

  defp is_map_forest(%{int: x}) when is_integer(x), do: true
  defp is_map_forest(_), do: false

  defp is_recursive_integer(:zero), do: true
  defp is_recursive_integer(%{succ: x}), do: is_recursive_integer(x)
  defp is_recursive_integer(_), do: false

  defp is_expression(x) when is_integer(x), do: true

  defp is_expression({exp1, operator, exp2}) when operator in [:*, :/, :+, :-] do
    is_expression(exp1) && is_expression(exp2)
  end

  defp is_expression(_), do: false

  defp is_recursive_tuple(nil), do: true
  defp is_recursive_tuple({a, b}) when is_integer(a), do: is_recursive_tuple(b)
  defp is_recursive_tuple(_), do: false

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
    is_iolist(x) && is_iolist(xs)
  end

  defp is_iolist(_), do: false

  defp generate_data(name, args \\ []) do
    from_type_with_validator(TypesList, name, args)
  end
end

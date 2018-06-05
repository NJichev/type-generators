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

  describe "literals" do
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
  end

  defp generate_data(name, args \\ []) do
    Types.from_type(StreamDataTest.TypesList, name, args)
  end
end

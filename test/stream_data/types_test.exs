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
    test "function with any arity" do
      data = generate_data(:literal_function_arity_any)

      check all f <- data, i <- integer() do
        assert is_function(f)

        {:arity, arity} = :erlang.fun_info(f, :arity)
        args = List.duplicate(i, arity)

        ast = quote do
          var!(f).(unquote_splicing(args))
        end
        {int, _} = Code.eval_quoted(ast, f: f)

        assert is_float(int)
      end
    end

    test "function literal with 0 arguments" do
      data = generate_data(:literal_function_arity_0)

      check all f <- data do
        assert is_function(f, 0)
        assert f.() == f.() # The function is pure
        int = f.()
        assert is_integer(int)
        assert int < 0
      end
    end

    test "function literal with 1 argument" do
      data = generate_data(:literal_function_arity_1)

      check all f <- data, i <- integer() do
        assert is_function(f, 1)
        assert is_integer(f.(i))
      end
    end

    test "function literal with 2 arguments" do
      data = generate_data(:literal_function_arity_2)

      check all f <- data, a <- integer(), b <- integer() do
        assert is_function(f, 2)
        assert is_integer(f.(a, b))
      end
    end
  end

  defp generate_data(name, args \\ []) do
    Types.from_type(StreamDataTest.TypesList, name, args)
  end
end

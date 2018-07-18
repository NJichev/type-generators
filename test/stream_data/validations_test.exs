defmodule StreamData.ValidationsTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  import StreamDataValidations

  alias StreamDataValidationsList, as: Validations

  defmacro is_oracle(original, oracle) do
    quote do
      :ok == check all x <- term(), max_runs: 25 do
        assert unquote(original).(x) == unquote(oracle).(x)
      end
    end
  end

  describe "spec validation" do
    test "it reads types" do
      validate(Validations.foo/1)
    end

    test "it runs" do

    end

    test "it reads options" do

    end
  end

  describe "validator_for" do
    test "returns validator for the function return type" do
      # foo returns a boolean
      member_function = validator_for(Validations, :foo, 1)

      check all x <- boolean() do
        assert member_function.(x)
      end

      check all x <- term(), x != true, x != false do
        refute member_function.(x)
      end
    end
  end

  describe "basic types" do
    test "none" do
      #This should be tested in the API function probably
    end

    test "any" do
      member_function = validator(:basic_any)

      check all x <- term(), max_runs: 25 do
        assert member_function.(x)
      end
    end

    test "atom" do
      member_function = validator(:basic_atom)

      assert is_oracle(member_function, &is_atom/1)

      # Versus

      check all x <- atom(:alphanumeric), do: assert(member_function.(x))
      check all x <- term(), !is_atom(x), do: refute(member_function.(x))
    end

    test "map" do
      member_function = validator(:basic_map)
      data = generate_data(:basic_map)

      check all x <- data, max_runs: 25 do
        assert member_function.(x)
      end

      check all x <- term(), !is_map(x), max_runs: 25 do
        refute member_function.(x)
      end
    end

    # test "struct" do
    #   member_function = validator(:basic_struct)
    #   data = generate_data(:basic_struct)
    #
    #   check all x <- data, max_runs: 25 do
    #     assert member_function.(x)
    #   end
    # end

    test "reference" do
      member_function = validator(:basic_reference)
      data = generate_data(:basic_reference)

      check all x <- data, max_runs: 25 do
        assert member_function.(x)
      end

      check all x <- term(), !is_reference(x), max_runs: 25 do
        refute member_function.(x)
      end
    end

    test "tuple" do
      member_function = validator(:basic_tuple)
      data = generate_data(:basic_tuple)

      check all x <- data, max_runs: 25 do
        assert member_function.(x)
      end

      check all x <- term(), !is_tuple(x), max_runs: 25 do
        refute member_function.(x)
      end
    end

    test "pid" do
      member_function = validator(:basic_pid)

      Process.list()
      |> Enum.each(fn port ->
        assert member_function.(port)
      end)

      # term() does not generate pid/port types
      check all x <- term() do
        refute member_function.(x)
      end
    end

    test "port" do
      member_function = validator(:basic_port)

      Port.list()
      |> Enum.each(fn port ->
        assert member_function.(port)
      end)

      # term() does not generate pid/port types
      check all x <- term() do
        refute member_function.(x)
      end
    end

    # Numbers
    test "float" do
      member_function = validator(:basic_float)
      data = generate_data(:basic_float)

      check all x <- data, max_runs: 25 do
        assert member_function.(x)
      end

      check all x <- term(), !is_float(x), max_runs: 25 do
        refute member_function.(x)
      end
    end

    test "integer" do
      member_function = validator(:basic_integer)
      data = generate_data(:basic_integer)

      check all x <- data, max_runs: 25 do
        assert member_function.(x)
      end

      check all x <- term(), !is_integer(x), max_runs: 25 do
        refute member_function.(x)
      end
    end

    test "pos_integer" do
      member_function = validator(:basic_pos_integer)
      data = generate_data(:basic_pos_integer)

      check all x <- data, max_runs: 25 do
        assert member_function.(x)
      end

      check all x <- term(), !(is_integer(x) && x > 0), max_runs: 25 do
        refute member_function.(x)
      end
    end

    test "non_neg_integer" do
      member_function = validator(:basic_non_neg_integer)
      data = generate_data(:basic_non_neg_integer)

      check all x <- data, max_runs: 25 do
        assert member_function.(x)
      end

      check all x <- term(), !(is_integer(x) && x >= 0), max_runs: 25 do
        refute member_function.(x)
      end
    end

    test "neg_integer" do
      member_function = validator(:basic_neg_integer)
      data = generate_data(:basic_neg_integer)

      check all x <- data, max_runs: 25 do
        assert member_function.(x)
      end

      check all x <- term(), !(is_integer(x) && x < 0), max_runs: 25 do
        refute member_function.(x)
      end
    end
    #
    # test "lists" do
    #   member_function = validator(:basic_list_type)
    #   data = generate_data(:basic_list_type)
    #
    #   check all list <- data, max_runs: 25 do
    #     # assert member_function()
    #     #
    #   end
    # end
    #
    # test "basic nonempty list" do
    #   member_function = validator(:basic_nonempty_list_type)
    #
    #   check all list <- data, max_runs: 25 do
    #     assert is_list(list)
    #     assert length(list) > 0
    #     assert Enum.all?(list, fn x -> is_integer(x) end)
    #   end
    # end
    #
    # test "maybe_improper_list" do
    #   member_function = validator(:basic_maybe_improper_list_type)
    #
    #   check all list <- data do
    #     each_improper_list(list, &assert(is_integer(&1)), &assert(is_float(&1) or is_integer(&1)))
    #   end
    # end
    #
    # test "nonempty_improper_list" do
    #   member_function = validator(:basic_nonempty_improper_list_type)
    #
    #   check all list <- data do
    #     assert list != []
    #     each_improper_list(list, &assert(is_integer(&1)), &assert(is_float(&1)))
    #   end
    # end
    #
    # test "nonempty_maybe_improper_list" do
    #   member_function = validator(:basic_nonempty_maybe_improper_list_type)
    #
    #   check all list <- data do
    #     assert list != []
    #     each_improper_list(list, &assert(is_integer(&1)), &assert(is_float(&1) or is_integer(&1)))
    #   end
    # end
    #
    # test "nested lists" do
    #   member_function = validator(:nested_list_type)
    #
    #   check all list <- data, max_runs: 25 do
    #     assert is_list(list)
    #
    #     Enum.each(list, fn x ->
    #       assert is_list(x)
    #       assert Enum.all?(x, &is_integer(&1))
    #     end)
    #   end
    # end
    #
    # test "nested nonempty list" do
    #   member_function = validator(:nested_nonempty_list_type)
    #
    #   check all list <- data, max_runs: 25 do
    #     assert is_list(list)
    #     assert length(list) > 0
    #
    #     Enum.each(list, fn x ->
    #       assert is_list(x)
    #       assert Enum.all?(x, &is_integer(&1))
    #     end)
    #   end
    # end
  end

  defp validator(name, args \\ []) do
    validator_for_type(StreamDataTest.TypesList, name, args)
  end

  defp generate_data(name, args \\ []) do
    StreamDataTypes.from_type(StreamDataTest.TypesList, name, args)
  end
end

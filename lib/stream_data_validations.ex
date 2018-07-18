defmodule StreamDataValidations do
  @doc """
  TODO:
  """
  defmacro validate({:/, _, [{{:., _, [module, function]}, _, _}, arity]}) do
    quote bind_quoted: [module: module, function: function, arity: arity] do
      {argument_types, return} = read_function_spec(module, function, arity)
      IO.inspect(argument_types)
      IO.inspect(return)
    end
    # quote do
    #   vars = Macro.generate_arguments(unquote(a), Elixir)
    #   check_streams = Enum.zip(vars, argument_types)
    #   |> Enum.map(fn {var, type} ->
    #     {:<-, [], [var, StreamDataTypes.generate_public(type)]}
    #   end)
    #
    #   check all check_streams do
    #     unquote(m).unquote(f).(vars))
    #   end
    # end
  end

  def validator_for(module, function, arity) do
    {_args, return_type} = read_function_spec(module, function, arity)
    generate_member_function(return_type)
  end

  def validator_for_type(module, function, arguments) when is_atom(module) and is_atom(function) and is_list(arguments) do
    {_name, type} = StreamDataTypes.choose_type(module, function, arguments)
    generate_member_function(type)
  end

  def read_function_spec(module, function, arity) do
    type = beam_specifications(module, function)
    |> Enum.find(fn {args, _return} -> length(args) == arity end)

    if type do
      type
    else
      raise ArgumentError, "Wrong amount of arguments passed."
    end
  end

  defp beam_specifications(module, name) do
    with {^module, beam, _file} <- :code.get_object_code(module),
         {:ok, {^module, [abstract_code: {:raw_abstract_v1, abstract_code}]}} <- :beam_lib.chunks(beam, [:abstract_code]) do
      for {:attribute, _line, :spec,
           {{^name, _}, [{:type, _, :fun, [{:type, _, :product, argument_types}, result_type]}]}} <-
            abstract_code,
          do: {argument_types, result_type}
    else
      _ ->
        msg = """
        Could not find .beam file for Module #{inspect(module)}.
        Are you sure you have passed in the correct module name?
        """

        raise ArgumentError, msg
    end
  end

  defp generate_member_function({:type, _, type, _}) when type in [:any, :term] do
    &is_any/1
  end

  defp generate_member_function({:type, _, :atom, _}) do
    &is_atom/1
  end

  defp generate_member_function({:type, _, type, _}) when type in [:none, :no_return] do
    #TODO handle outside in function return in check all
  end

  defp generate_member_function({:type, _, :pid, _}) do
    &is_pid/1
  end

  defp generate_member_function({:type, _, :port, _}) do
    &is_port/1
  end

  defp generate_member_function({:type, _, :integer, _}) do
    &is_integer/1
  end

  defp generate_member_function({:type, _, :pos_integer, _}) do
    compose([&is_integer/1, &(&1 > 0)])
  end

  defp generate_member_function({:type, _, :neg_integer, _}) do
    compose([&is_integer/1, &(&1 < 0)])
  end

  defp generate_member_function({:type, _, :non_neg_integer, _}) do
    compose([&is_integer/1, &(&1 >= 0)])
  end

  defp generate_member_function({:type, _, :float, _}) do
    &is_float/1
  end

  defp generate_member_function({:type, _, :reference, _}) do
    &is_reference/1
  end

  defp generate_member_function({:type, _, :tuple, :any}) do
    &is_tuple/1
  end

  defp generate_member_function({:type, _, :tuple, types}) do
    fun = validate_multiple(types)

    compose([
      &is_tuple/1,
      fun
    ])
  end

  defp generate_member_function({:type, _, :list, []}) do
    &is_list/1
  end

  defp generate_member_function({:type, _, :list, [types]}) do
    fun = validate_multiple(types)

    compose([
      &is_list/1,
      fun
    ])
  end

  defp generate_member_function({:type, _, nil, []}) do
    &(!is_nonempty_list(&1))
  end

  defp generate_member_function({:type, _, :nonempty_list, []}) do
    &is_nonempty_list/1
  end

  defp generate_member_function({:type, _, :nonempty_list, [types]}) do
    fun = validate_multiple(types)

    compose([
      &is_nonempty_list/1,
      fun
    ])
  end

  defp generate_member_function({:type, _, :maybe_improper_list, []}) do
    fun = &is_any/1
    &(is_improper_list(&1, fun, fun))
  end

  defp generate_member_function({:type, _, :maybe_improper_list, [type1, type2]}) do
    fun1 = generate_member_function(type1)
    fun2 = generate_member_function(type2)

    &(is_improper_list(&1, fun1, fun2))
  end

  defp generate_member_function({:type, _, :nonempty_improper_list, [type1, type2]}) do
    fun1 = generate_member_function(type1)
    fun2 = generate_member_function(type2)

    compose([
      &(&1 != []),
      &(is_improper_list(&1, fun1, fun2))
    ])
  end

  defp generate_member_function({:type, _, :nonempty_maybe_improper_list, []}) do
  end

  defp generate_member_function({:type, _, :nonempty_maybe_improper_list, [type1, type2]}) do
  end

  defp generate_member_function({:type, _, :map, :any}) do
    &is_map/1
  end

  defp generate_member_function({:type, _, :map, []}) do
    fn %{} -> true
      _ -> false
    end
  end

  defp generate_member_function({:type, _, :map, field_types}) do
    field_types
    |> Enum.map(&generate_map_member_function/1)
    |> compose
  end

  defp generate_member_function({type, _, literal}) when type in [:atom, :integer] do
    &(&1 === literal)
  end

  defp generate_member_function({:type, _, :range, [{:integer, _, lower}, {:integer, _, upper}]}) do
    compose([
      &is_integer/1,
      &(&1 >= lower && &1 <= upper)
    ])
  end

  defp generate_member_function({:type, _, :binary, [{:integer, _, size}, {:integer, _, unit}]}) do
    &(unit ==
        bit_size(&1)
        |> rem(size))
  end

  ## Built-in types
  defp generate_member_function({:type, _, :arity, []}) do
    compose([
      &is_integer/1,
      &(&1 >= 0 && &1 <= 255)
    ])
  end

  defp generate_member_function({:type, _, :boolean, []}) do
    &is_boolean/1
  end

  defp generate_member_function({:type, _, :byte, []}) do
    compose([
      &is_integer/1,
      &(&1 in 0..255)
    ])
  end

  defp generate_member_function({:type, _, :char, []}) do
    compose([
      &is_integer/1,
      &(&1 in 0..0x10FFFF)
    ])
  end

  # Note: This is the type we call charlist()
  defp generate_member_function({:type, _, :string, []}) do
    compose([
      &is_list/1,
      fn x -> Enum.all?(x, &(&1 in 0..0x10FFFF)) end
    ])
  end

  defp generate_member_function({:type, _, :bitstring, []}) do
    &is_bitstring/1
  end

  defp generate_member_function({:type, _, :binary, []}) do
    &is_binary/1
  end

  defp generate_member_function({:type, _, :nonempty_string, []}) do
    compose([
      &(!is_nonempty_list(&1)),
      fn x -> Enum.all?(x, &(&1 in 0..0x10FFFF)) end
    ])
  end

  defp generate_member_function({:remote_type, _, [{:atom, _, module}, {:atom, _, type}, []]}) do
    #TODO figure this out
  end

  defp generate_member_function({:type, _, :iolist, []}) do
    # &is_iolist/1
  end

  defp generate_member_function({:type, _, :iodata, []}) do
    # &is_iodata/1
  end

  defp generate_member_function({:type, _, :mfa, []}) do
    fn
      {mod, fun, arity} when is_atom(mod) and is_atom(fun) and arity in 0..255 -> true
      _ -> false
    end
  end

  defp generate_member_function({:type, _, x, []}) when x in [:module, :node] do
    &is_atom/1
  end

  defp generate_member_function({:type, _, :number, []}) do
    one_of([
      &is_integer/1,
      &is_float/1
    ])
  end

  defp generate_member_function({:type, _, :timeout, []}) do
    one_of([
      fn x when is_integer(x) and x >= 0 -> true
        _ -> false
      end,
      &(&1 == :infinity)
    ])
  end

  defp generate_member_function({:type, _, :union, args}) do
    args
    |> Enum.map(&generate_member_function/1)
    |> one_of
  end

  defp generate_map_member_function({:type, _, :map_field_exact, [{_, _, key}, value_type]}) do
    fun = generate_member_function(value_type)
    fn
      %{^key => value} -> fun.(value)
      _ -> false
    end
  end

  defp generate_map_member_function({:type, _, :map_field_exact, [key_type, value_type]}) do
    key_fun = generate_member_function(key_type)
    value_fun = generate_member_function(value_type)
    &(Enum.all?(&1, fn {key, value} -> key_fun.(key) && value_fun.(value) end))
  end

  defp generate_map_member_function({:type, _, :map_field_assoc, [key_type, value_type]}) do
    key_fun = generate_member_function(key_type)
    value_fun = generate_member_function(value_type)
    &(&1 == %{} || Enum.all?(&1, fn {key, value} -> key_fun.(key) && value_fun.(value) end))
  end

  defp compose(functions) do
    fn x ->
      Enum.all?(functions, &(&1.(x)))
    end
  end

  defp one_of(functions) do
    fn x ->
      Enum.any?(functions, &(&1.(x)))
    end
  end

  defp validate_multiple(types) do
    validators = Enum.map(types, &generate_member_function/1)
    fn x ->
      Enum.zip(validators, x)
      |> Enum.all?(fn {validator, type} ->
        validator.(type)
      end)
    end
  end

  defp is_nonempty_list([_head | _tail]), do: true
  defp is_nonempty_list(_), do: false

  defp is_improper_list([], _head_fun, _tail_fun), do: true

  defp is_improper_list([elem], _head_fun, tail_fun) do
    tail_fun.(elem)
  end

  defp is_improper_list([head | tail], head_fun, tail_fun) when is_list(tail) do
    head_fun.(head) && is_improper_list(tail, head_fun, tail_fun)
  end

  defp is_improper_list([head | tail], head_fun, tail_fun) do
    head_fun.(head) && tail_fun.(tail)
  end

  defp is_improper_list(_, _head_fun, _tail_fun), do: false

  defp is_any(_), do: true
end

defmodule StreamDataTypes do
  import StreamData

  @doc """
  Returns any kind of generator by a given type definition.
  The function takes in a module name, function name and a keyword list
  of type arguments(defaults to []).

  ## Examples

  Say you have a simple type that is a tuple of an atom and integer,
  you can use from_type to create a generator out of it.

      defmodule MyModule do
        @type t :: {atom(), integer()}
      end

      from_type(MyModule, :t) |> Enum.take(3)
      #=> [{:asdf, 3}, {:aub, -1}, {:fae, 0}]

  ## Shrinking(TODO(njichev))
  """
  def from_type(module, name, args \\ [])
      when is_atom(module) and is_atom(name) and is_list(args) do
    type = for pair = {^name, _type} <- beam_types(module), do: pair

    # pick correct type, when multiple
    # Validate outer is list/map/tuple when having args
    # Convert args
    # put args in type tuple
    case type do
      [] ->
        msg = """
        Module #{inspect(module)} does not define type #{name}/#{length(args)}.
        """

        raise ArgumentError, msg

      types when is_list(types) ->
        pick_type(types, args)
        |> generate_from_type(args)
    end
  end

  # Read .beam file to get type information. Raise if the .beam file is not found.
  defp beam_types(module) do
    with {^module, beam, _file} <- :code.get_object_code(module),
         {:ok, {^module, [abstract_code: {:raw_abstract_v1, abstract_code}]}} <-
           :beam_lib.chunks(beam, [:abstract_code]) do
      for {:attribute, _line, :type, {name, type, _other}} <- abstract_code, do: {name, type}
    else
      _ ->
        msg = """
        Could not find .beam file for Module #{inspect(module)}.
        Are you sure you have passed in the correct module name?
        """

        raise ArgumentError, msg
    end
  end

  # There can be multiple types with different amount of arguments.
  # Pick the one that matches the amount the user gave as arguments,
  # otherwise raise an argument error.
  defp pick_type(types, args) do
    len = length(args)
    type = Enum.find(types, fn {_name, type} -> vars(type) == len end)

    if type do
      type
    else
      raise ArgumentError, "Wrong amount of arguments passed."
    end
  end

  # Recursively count the number of variables a type can be given.
  # Used to choose the correct type for a user.
  defp vars({:var, _, _}), do: 1

  defp vars({:type, _, _, types}) do
    vars(types)
  end

  defp vars(types) when is_list(types) do
    types
    |> Enum.map(&vars(&1))
    |> Enum.sum()
  end

  defp vars(_), do: 0

  # Handle type generation/recursive/union types here.
  # Maybe module name should be passed.
  defp generate_from_type({_name, type}, _args) do
    generate(type)
  end

  defp generate({:type, _, type, _}) when type in [:any, :term] do
    term()
  end

  defp generate({:type, _, :atom, _}) do
    atom(:alphanumeric)
  end

  defp generate({:type, _, bottom, _}) when bottom in [:none, :no_return] do
    raise ArgumentError, "Cannot generate types of the none type."
  end

  defp generate({:type, _, :integer, _}) do
    integer()
  end

  defp generate({:type, _, :pos_integer, _}) do
    positive_integer()
  end

  defp generate({:type, _, :neg_integer, _}) do
    non_negative_integer()
  end

  defp generate({:type, _, :non_neg_integer, _}) do
    map(integer(), &abs(&1))
  end

  defp generate({:type, _, :float, _}) do
    float()
  end

  defp generate({:type, _, :reference, _}) do
    map(constant(:unused), fn _ -> make_ref() end)
  end

  defp generate({:type, _, :tuple, :any}) do
    term()
    |> list_of()
    |> scale(fn size -> trunc(:math.pow(size, 0.5)) end)
    |> map(&List.to_tuple/1)
  end

  defp generate({:type, _, :tuple, types}) do
    types
    |> Enum.map(&generate/1)
    |> List.to_tuple()
    |> tuple()
  end

  defp generate({:type, _, :list, []}) do
    term()
    |> list_of()
  end

  defp generate({:type, _, :list, [type]}) do
    generate(type)
    |> list_of()
  end

  defp generate({:type, _, nil, []}), do: constant([])

  defp generate({:type, _, :nonempty_list, []}) do
    term()
    |> list_of(min_length: 1)
  end

  defp generate({:type, _, :nonempty_list, [type]}) do
    generate(type)
    |> list_of(min_length: 1)
  end

  defp generate({:type, _, :maybe_improper_list, []}) do
    maybe_improper_list_of(
      term(),
      term()
    )
  end

  defp generate({:type, _, :maybe_improper_list, [type1, type2]}) do
    maybe_improper_list_of(
      generate(type1),
      generate(type2)
    )
  end

  defp generate({:type, _, :nonempty_improper_list, [type1, type2]}) do
    nonempty_improper_list_of(
      generate(type1),
      generate(type2)
    )
  end

  defp generate({:type, _, :nonempty_maybe_improper_list, []}) do
    maybe_improper_list_of(
      term(),
      term()
    )
    |> nonempty()
  end

  defp generate({:type, _, :nonempty_maybe_improper_list, [type1, type2]}) do
    maybe_improper_list_of(
      generate(type1),
      generate(type2)
    )
    |> nonempty()
  end

  defp generate({:type, _, :map, :any}) do
    map_of(term(), term())
  end

  defp generate({:type, _, :map, []}) do
    constant(%{})
  end

  defp generate({:type, _, :map, field_types}) do
    field_types
    |> Enum.map(&generate_map_field/1)
    |> Enum.reduce(fn x, acc ->
      bind(acc, fn map1 ->
        bind(x, fn map2 ->
          Map.merge(map2, map1)
          |> constant()
        end)
      end)
    end)
  end

  ## Built-in types
  defp generate({:type, _, :arity, []}) do
    integer(0..255)
  end

  defp generate({:type, _, :boolean, []}) do
    boolean()
  end

  defp generate({:type, _, :byte, []}) do
    byte()
  end

  defp generate({:type, _, :char, []}) do
    char()
  end

  # Note: This is the type we call charlist()
  defp generate({:type, _, :string, []}) do
    char()
    |> list_of()
  end

  defp generate({:type, _, :bitstring, []}) do
    bitstring()
  end

  defp generate({:type, _, :binary, []}) do
    binary()
  end

  defp generate({:type, _, :nonempty_string, []}) do
    char()
    |> list_of(min_length: 1)
  end

  defp generate({:remote_type, _, [{:atom, _, module}, {:atom, _, type}, []]}) do
    from_type(module, type)
  end

  defp generate({:type, _, :iolist, []}) do
    iolist()
  end

  defp generate({:type, _, :iodata, []}) do
    iodata()
  end

  defp generate({:type, _, :mfa, []}) do
    module = one_of([atom(:alphanumeric), atom(:alias)])
    function = one_of([atom(:alphanumeric), atom(:alias)])
    arity = integer(0..255)

    tuple({module, function, arity})
  end

  defp generate({:type, _, x, []}) when x in [:module, :node] do
    one_of([atom(:alphanumeric), atom(:alias)])
  end

  defp generate({:type, _, :number, []}) do
    one_of([
      integer(),
      float()
    ])
  end

  defp generate({:type, _, :timeout, []}) do
    frequency([
      {9, non_negative_integer()},
      {1, constant(:infinity)}
    ])
  end

  defp char() do
    integer(0..0x10FFFF)
  end

  defp non_negative_integer() do
    map(positive_integer(), &(-1 * &1))
  end

  defp generate_map_field({:type, _, :map_field_exact, [{_, _, key}, value]}) do
    value = generate(value)

    fixed_map(%{key => value})
  end

  defp generate_map_field({:type, _, :map_field_exact, [key, value]}) do
    map_of(
      generate(key),
      generate(value),
      min_length: 1
    )
  end

  defp generate_map_field({:type, _, :map_field_assoc, [key, value]}) do
    map_of(
      generate(key),
      generate(value)
    )
  end
end

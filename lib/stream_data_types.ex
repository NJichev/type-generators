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
  ## Parameterized Types(TODO(njichev): Explain the API indept)

  When generating data for parameterized types you can pass in the type arguments in the third argument of `from_type`.
  The arguments can be the following:
    - any basic type(:integer, :atom, etc.)
    - literal: (1 | 2 | :my_atom | [](empty list) | {} | %{})
    - list: [arguments]
    - tuple: [arguments]
    - map: [{key, value}, {:optional, {key, value}}]
    - user_type: user_type_name(user types are types defined in the same module)
    - remote_type: {ModuleName, type_name} | {ModuleName, type_name, [arguments]}

  You can think of [arguments] as the same thing you passed in expanding recursively.

  ## Examples

      defmodule MyModule do
        @type simple(a) :: a
        @type dict(a, b) :: list({a, b})
      end

      from_type(MyModule, :simple, [:integer]) |> Enum.take(3)
      #=>  [1, 0, -1]

      from_type(MyModule, :simple, [list: [list: [:integer]]]) |> Enum.take(3)
      #=> [[], [], [[0, 2, -3], [0, 2, -1], []]]

      from_type(MyModule, :dict, [:atom, :integer]) |> Enum.take(3)
      #=> [[VE: 0], [], [h1K: 1]]


  """
  def from_type(module, name, args \\ [])
      when is_atom(module) and is_atom(name) and is_list(args) do
    args = rewrite_arguments(args)

    pick_type_from_beam(module, name, args)
    |> inline_type_parameters(args)
    |> inline_user_type(module)
    |> generate_from_type
  end

  defp pick_type_from_beam(module, name, args) do
    type = for pair = {^name, _type} <- beam_types(module), do: pair

    # pick correct type, when multiple
    # Validate outer is list/map/tuple when having args
    # Convert args
    # put args in type tuple
    case type do
      [] ->
        raise ArgumentError,
              "Module #{inspect(module)} does not define type #{name}/#{length(args)}."

      types when is_list(types) ->
        types
        |> pick_type(args)
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
        raise ArgumentError, """
        Could not find .beam file for Module #{inspect(module)}.
        Are you sure you have passed in the correct module name?
        """
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
      raise ArgumentError, """
      Could not find type with #{len} type arguments.
      """
    end
  end

  # Recursively count the number of variables a type can be given.
  # Used to choose the correct type for a user.
  defp vars({:var, _, _}), do: 1

  defp vars({:type, _, _, args}), do: vars(args)

  defp vars({:user_type, _, _, args}), do: vars(args)

  defp vars({:remote_type, _, [_module, _name, args]}), do: vars(args)

  defp vars(types) when is_list(types) do
    types
    |> Enum.map(&vars(&1))
    |> Enum.sum()
  end

  defp vars(_), do: 0

  defp rewrite_arguments(args) when is_list(args) do
    Enum.map(args, &rewrite_argument/1)
  end

  defp rewrite_argument(:map), do: {:type, 0, :map, :any}
  defp rewrite_argument(:list), do: {:type, 0, :map, :any}
  defp rewrite_argument(type) when is_atom(type), do: {:type, 0, type, []}
  defp rewrite_argument({:literal, literal}) when is_integer(literal), do: {:integer, 0, literal}
  defp rewrite_argument({:literal, literal}) when is_atom(literal), do: {:atom, 0, literal}
  defp rewrite_argument({:literal, []}), do: {:type, 0, nil, []}
  defp rewrite_argument({:literal, %{}}), do: {:type, 0, :map, []}
  defp rewrite_argument({:literal, {}}), do: {:type, 0, :tuple, []}

  defp rewrite_argument({:map, fields}) do
    rewritten_fields = Enum.map(fields, &rewrite_map_field/1)
    {:type, 0, :map, rewritten_fields}
  end

  defp rewrite_argument({type, args}) when is_list(args) do
    {:type, 0, type, rewrite_arguments(args)}
  end

  defp rewrite_argument({:user_type, user_type}) when is_atom(user_type),
    do: {:user_type, 0, user_type, []}

  defp rewrite_argument({:user_type, {user_type, arguments}})
       when is_atom(user_type) and is_list(arguments) do
    {:user_type, 0, user_type, rewrite_arguments(arguments)}
  end

  defp rewrite_argument({:remote_type, {module, name}}) when is_atom(module) and is_atom(name) do
    {:remote_type, 0, [{:atom, 0, module}, {:atom, 0, name}, []]}
  end

  defp rewrite_argument({:remote_type, {module, name, args}})
       when is_atom(module) and is_atom(name) and is_list(args) do
    {:remote_type, 0, [{:atom, 0, module}, {:atom, 0, name}, rewrite_arguments(args)]}
  end

  defp rewrite_argument(type), do: type

  defp rewrite_map_field({:optional, {key, value}}) do
    key = rewrite_argument(key)
    value = rewrite_argument(value)
    {:type, 0, :map_field_assoc, [key, value]}
  end

  defp rewrite_map_field({key, value}) do
    key = rewrite_argument(key)
    value = rewrite_argument(value)
    {:type, 0, :map_field_exact, [key, value]}
  end

  defp inline_type_parameters({name, {:var, _, _}}, [type]) do
    {name, type}
  end

  defp inline_type_parameters({_name, {_, _, _}} = type, []) do
    type
  end

  defp inline_type_parameters({name, {:type, line, container, args_with_var}}, args) do
    {args_without_var, []} = replace_var(args_with_var, args)
    {name, {:type, line, container, args_without_var}}
  end

  defp inline_type_parameters(
         {name, {:remote_type, line, [{:atom, _, module}, {:atom, _, type}, args_with_var]}},
         args
       ) do
    {args_without_var, []} = replace_var(args_with_var, args)
    {name, {:remote_type, line, [{:atom, 0, module}, {:atom, 0, type}, args_without_var]}}
  end

  # There has to be a better way.
  # Recursively go through every type argument and replace it with the head of the rewritten arguments.
  #
  def replace_var([{type, line, name, types} | tail], args) when type in [:type, :user_type] do
    {x, rest_args} = replace_var(types, args)
    {result, rest_args} = replace_var(tail, rest_args)
    {[{type, line, name, x} | result], rest_args}
  end

  def replace_var([{:var, _, _} | tail1], [type | tail2]) do
    {result, r} = replace_var(tail1, tail2)
    {[type | result], r}
  end

  def replace_var([t | tail], args) do
    {res, r} = replace_var(tail, args)
    {[t | res], r}
  end

  def replace_var(l, a), do: {l, a}

  defp inline_user_type({name, type}, module) do
    {name, inline_user_type(type, module, name)}
  end

  defp inline_user_type({:type, line, :union, types}, module, name) do
    inlined =
      types
      |> Enum.map(&inline_user_type(&1, module, name))

    {:type, line, :union, inlined}
  end

  defp inline_user_type({:user_type, _line, name, _} = type, _module, name) do
    type
  end

  defp inline_user_type({:user_type, _line, name, args}, module, _original_name) do
    {^name, type} = pick_type_from_beam(module, name, args)
    type
  end

  defp inline_user_type({:type, _line, :map, :any} = type, _module, _name), do: type

  defp inline_user_type({:type, line, :map, fields}, module, name) do
    inlined_fields =
      Enum.map(fields, fn {:type, l, field_type, field_args}
                          when field_type in [:map_field_exact, :map_field_assoc] ->
        inlined_field_args =
          field_args
          |> Enum.map(&inline_user_type(&1, module, name))

        {:type, l, field_type, inlined_field_args}
      end)

    {:type, line, :map, inlined_fields}
  end

  defp inline_user_type({:type, _, :tuple, :any} = t, _module, _name), do: t

  defp inline_user_type({:type, line, type, args}, module, name) when type in [:list, :tuple] do
    inlined_list_args = Enum.map(args, &inline_user_type(&1, module, name))
    {:type, line, type, inlined_list_args}
  end

  defp inline_user_type(type, _module, _name), do: type

  # Handle type generation/recursive/union types here.
  # Maybe module name should be passed.
  defp generate_from_type({name, {:type, _, :union, args}}) do
    {nodes, leaves} = nodes_and_leaves(name, args)
    leaves = generate_union(leaves)

    case nodes do
      [] ->
        leaves

      nodes ->
        generate_recursive(nodes, leaves)
    end
  end

  defp generate_from_type({name, type}) do
    if recursive_without_union?(type, name) do
      leaves =
        rewrite_recursive_type(type, name)
        |> generate()

      generate_recursive([type], leaves)
    else
      generate(type)
    end
  end

  defp generate_union(leaves) do
    leaves
    |> Enum.map(&generate/1)
    |> one_of
  end

  defp generate_recursive(nodes, leaves) do
    StreamData.tree(leaves, fn leaf ->
      nodes
      |> Enum.map(&map_user_type_to_leaf(&1, leaf))
      |> Enum.map(&generate_from_type({:anonymous, &1}))
      |> one_of
    end)
  end

  def nodes_and_leaves(name, args) do
    args
    |> Enum.split_with(&node?(&1, name))
  end

  defp map_user_type_to_leaf({:user_type, _line, _name, _args}, leaf), do: leaf

  defp map_user_type_to_leaf({:type, line, type, args}, leaf) do
    args = Enum.map(args, &map_user_type_to_leaf(&1, leaf))
    {:type, line, type, args}
  end

  defp map_user_type_to_leaf({_, _, _l} = type, _leaf), do: type

  defp recursive_without_union?({:type, _, _, :any}, _name), do: false

  defp recursive_without_union?({:type, _, :map, fields}, name) do
    Enum.any?(fields, fn {:type, _, _, key_value_pair} ->
      Enum.any?(key_value_pair, fn type -> recursive_without_union?(type, name) end)
    end)
  end

  defp recursive_without_union?({:type, _, _, args}, name) do
    List.foldr(args, false, fn elem, acc ->
      acc || recursive_without_union?(elem, name)
    end)
  end

  defp recursive_without_union?({:user_type, _, name, _}, name), do: true

  defp recursive_without_union?(_type, _name), do: false

  defp node?({:type, _, _, args}, name), do: Enum.any?(args, &node?(&1, name))

  defp node?({:user_type, _, name, _}, name) do
    true
  end

  defp node?(_, _), do: false

  defp generate(%StreamData{} = generator), do: generator

  defp generate({:type, _, type, _}) when type in [:any, :term] do
    term()
  end

  defp generate({:type, _, :atom, _}) do
    atom(:alphanumeric)
  end

  defp generate({:type, _, type, _}) when type in [:none, :no_return] do
    raise ArgumentError, "Cannot generate types of the none type."
  end

  defp generate({:type, _, type, _}) when type in [:pid, :port] do
    raise ArgumentError, """
    Pid/Port types are not supported.
    To create a StreamData generator for pids/ports use the following hack:
        pids = StreamData.map(
          StreamData.constant(:unused),
          fn _ -> spawn_pid/port() end
        )

    You can specify any zero arity function for spawning pids/ports.
    To have multiple types of pids, chain them together with `StreamData.one_of/1`
    """
  end

  defp generate({:type, _, :integer, _}) do
    integer()
  end

  defp generate({:type, _, :pos_integer, _}) do
    positive_integer()
  end

  defp generate({:type, _, :neg_integer, _}) do
    map(positive_integer(), &(-1 * &1))
  end

  defp generate({:type, _, :non_neg_integer, _}) do
    non_negative_integer()
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

  defp generate({type, _, literal}) when type in [:atom, :integer] do
    constant(literal)
  end

  defp generate({:type, _, :range, [{:integer, _, lower}, {:integer, _, upper}]}) do
    integer(lower..upper)
  end

  defp generate({:type, _, :binary, [{:integer, _, size}, {:integer, _, unit}]}) do
    rest_length_in_bits = map(non_negative_integer(), &(&1 * unit))

    bind(bitstring(length: size), fn prefix ->
      bind(rest_length_in_bits, fn rest_length ->
        map(bitstring(length: rest_length), &<<prefix::bitstring, &1::bitstring>>)
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

  defp generate({:remote_type, _, [{:atom, _, module}, {:atom, _, type}, args]}) do
    if protocol?(module) do
      raise ArgumentError, """
      You have specified a type which relies or is the protocol #{module}.
      Protocols are currently unsupported, instead try generating for the type which implements the protocol.
      """
    else
      from_type(module, type, args)
    end
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

  defp generate({:type, _, :union, args}) do
    generate_union(args)
  end

  defp char() do
    integer(0..0x10FFFF)
  end

  defp non_negative_integer() do
    map(integer(), &abs/1)
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

  defp rewrite_recursive_type({:type, _, _, :any} = t, _name), do: t

  defp rewrite_recursive_type({:type, line, :list, [{:user_type, _, name, _}]}, name) do
    {:type, line, nil, []}
  end

  defp rewrite_recursive_type({:type, line, :map, fields}, name) do
    rewritten_fields =
      Enum.reject(fields, fn
        {:type, _, :map_field_assoc, key_value_pair} ->
          Enum.any?(key_value_pair, fn
            {:user_type, _, ^name, _} -> true
            _ -> false
          end)

        _ ->
          false
      end)

    {:type, line, :map, rewritten_fields}
  end

  defp rewrite_recursive_type({:type, line, wrapper, args}, name) do
    {
      :type,
      line,
      wrapper,
      Enum.map(args, &rewrite_recursive_type(&1, name))
    }
  end

  defp rewrite_recursive_type(type, _name), do: type

  defp protocol?(module) do
    Code.ensure_loaded?(module) and function_exported?(module, :__protocol__, 1) and
      module.__protocol__(:module) == module
  end
end

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

    choose_type(module, name, args)
    |> generate_from_type(args)
  end


  @doc """
  Returns the type AST for a defined by a user type.
  This will search the .beam file for the module and choose the type
  based on the types contained.
  Afterwards the arguments and user defined types will be inlined to simplify the type AST to simple types.

  ## Examples

      defmodule MyModule do
        @type t :: {atom(), integer()}
      end

      choose_type(String, :t)
      #=> {:t, {:type, 206, :binary, []}}
  """
  def choose_type(module, name, args \\ []) do
    pick_type_from_beam(module, name, args)
    |> inline_user_type(module)
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

  defp inline_user_type({name, type}, module) do
    {name, inline_user_type(type, module, name)}
  end

  defp inline_user_type({:type, line, :union, types}, module, name) do
    inlined =
      types
      |> Enum.map(fn type -> inline_user_type(type, module, name) end)

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

  def generate_public(type), do: generate(type)

  # Handle type generation/recursive/union types here.
  # Maybe module name should be passed.
  defp generate_from_type({name, {:type, _, :union, args}}, _args) do
    {nodes, leaves} = nodes_and_leaves(name, args)
    leaves = generate_union(leaves)

    case nodes do
      [] ->
        leaves

      nodes ->
        generate_recursive(nodes, leaves)
    end
  end

  defp generate_from_type({name, type}, _args) do
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
      |> Enum.map(&generate_from_type({:anonymous, &1}, []))
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

  defp generate({:remote_type, _, [{:atom, _, module}, {:atom, _, type}, []]}) do
    if protocol?(module) do
      raise ArgumentError, """
            You have specified a type which relies or is the protocol #{module}.
            Protocols are currently unsupported, instead try generating for the type which implements the protocol.
            """
    else
      from_type(module, type)
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
        _ -> false
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

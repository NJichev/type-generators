defmodule StreamDataTypes do
  import StreamData

  @moduledoc """
  Functions for creating StreamData generators and type validators.

  This module provides simple functions for reading your type definitions
  and based on that generating a StreamData generator or type validator.

  For an example, to get a generator out of `@type t :: integer() | atom()`,
  you can use `from_type/3`:

      Enum.take(3, StreamDataTypes.from_type(YourModule, :t))
      #=> [1, 2, :afd]

  You can also generate functions that check whether a certain term
  belongs to a type family with `type_validator_for/3`.

      member_function = StreamDataTypes.type_validator_for(YourModule, :t)
      member_function.(1)
      #=> true
      member_function.(:afd)
      #=> true
      member_function.({})
      #=> false
  """

  @doc """
  Accepts a user type definition and returns a StreamData generator.
  The function parameters are:
      - module name
      - function name
      - list of data generators to be used for parameterized types -
      defaults to an empty list

  ## Examples

  Say you have a simple type that is a tuple of an atom and integer,
  you can use from_type to create a generator out of it.

      defmodule MyModule do
        @type t :: {atom(), integer()}
      end

      from_type(MyModule, :t) |> Enum.take(3)
      #=> [{:asdf, 3}, {:aub, -1}, {:fae, 0}]

  ## Parameterized Types

  Parameterized Types take in a third argument - a list of StreamData
  generators. There is no restriction on the used generators.
  You should expect every variable to be replaced with the types of the
  given generators. The order of the variables is as written in the
  type definition.


  ## Examples

      defmodule MyModule do
        @type simple(a) :: a
        @type dict(a, b) :: list({a, b})
      end

      import StreamData

      from_type(MyModule, :simple, [integer()])
      |> Enum.take(3)
      #=>  [1, 0, -1]

      from_type(MyModule, :simple, [list_of(list_of(integer()))])
      |> Enum.take(3)
      #=> [[], [], [[0, 2, -3], [0, 2, -1], []]]

      from_type(MyModule, :dict, [atom(:alphanumeric), integer()])
      |> Enum.take(3)
      #=> [[VE: 0], [], [h1K: 1]]


  ## Shrinking

  Your types will shrink as close as possible to `StreamData`'s' primitive
  data generators. You can expect that most of your types will shrink
  towards the "smallest" representitive of your type.

  Check `StreamData`'s documentation for more information on shrinking.

  ## Unsupported types

  The only unsupported types for which you will get a failure are pids and ports.
  """
  def from_type(module, name, args \\ [])
      when is_atom(module) and is_atom(name) and is_list(args) do
    validate_generators(args)

    pick_type_from_beam(module, name, args)
    |> inline_type_parameters(args)
    |> inline_user_type(module)
    |> generate_from_type()
  end

  @doc """
  Accepts a user type definition and returns a function with 1 arguments
  that checks whether a term belongs to the type definition.
  The function parameters are:
      - module name
      - function name
      - list of other member functions to be used for parameterized types -
      defaults to an empty list

  ## Examples

  Say you have a simple type that is a tuple of an atom and integer,
  you can use `validator_for_type/3` to create a member function for it.

      defmodule MyModule do
        @type t :: {atom(), integer()}
      end

      member = validator_for_type(MyModule, :t)
      member.({:asdf, 3})
      #=> true
      member.(:foo)
      #=> false

  ## Parameterized Types

  To create member functions for parameterized types you should pass in
  a list of other member function for the subtype you need.

  ## Examples

      defmodule MyModule do
        @type dict(a, b) :: list({a, b})
      end

      import StreamData

      member = validator_for_type(MyModule, :dict, [&is_atom/1, &is_integer/1])
      member.([[VE: 0], [], [h1K: 1]])
      #=> true
      member.([[atom: :atom]])
      #=> false
  """
  def type_validator_for(module, name, args \\ [])
      when is_atom(module) and is_atom(name) and is_list(args) do
    validate_functions(args)

    pick_type_from_beam(module, name, args)
    |> inline_type_parameters(args)
    |> inline_user_type(module)
    |> validator_for()
  end

  @doc """
  Combines both `from_type/3` and `type_validator_for/3`.

  Returns a tuple of a StreamData generator and a member function for
  a given type definition.

  The arguments passed in should be a list of 2 element tuples:
  A StreamData generator and a member function for a type.
  """
  def from_type_with_validator(module, name, args \\ [])
      when is_atom(module) and is_atom(name) and is_list(args) do
    validate_arguments(args)

    {
      from_type(module, name, Enum.map(args, &elem(&1, 0))),
      type_validator_for(module, name, Enum.map(args, &elem(&1, 1)))
    }
  end

  @doc """
  Validate a function type specification.

  The arguments are module name, function name and the arity of the function.

  `validate/3` will check each overloaded type signature because of
  that it returns a tuple of:
    - {:ok, [list of successful metadata]} - when everything passes
    - {:error, [list of error metadata]} - when anything fails

  Example:

      StreamDataTypes.validate(Kernel, is_integer, 1)

  For more information on the metadata - read the documentation of
  `StreamData.check_all/3`.
  """
  def validate(module, name, arity)
      when is_atom(module) and is_atom(name) and is_integer(arity) do
    function_to_validate = :erlang.make_fun(module, name, arity)

    read_function_spec(module, name, arity)
    |> Enum.map(fn {arguments, return_type} ->
      check_function_definition(function_to_validate, module, arguments, return_type)
    end)
    |> aggregate_results
  end

  defp aggregate_results(results) do
    if Enum.all?(results, &match?({:ok, %{}}, &1)) do
      {:ok, for({:ok, data} <- results, do: data)}
    else
      {:error, for({:error, metadata} <- results, do: metadata)}
    end
  end

  defp check_function_definition(function, module, arguments, return_type) do
    generator =
      arguments
      |> Enum.map(&expand_user_type(&1, module))
      |> List.to_tuple()
      |> tuple()
      |> map(&Tuple.to_list/1)

    member = expand_user_validator(return_type, module)

    has_no_return = has_no_return?(return_type)

    fun = build_check_all_function(function, member, has_no_return)

    check_all(generator, [initial_seed: :os.timestamp()], fun)
  end

  defp build_check_all_function(function, _member, true) do
    fn args ->
      try do
        apply(function, args)

        {:ok, :no_return}
      rescue
        _ ->
          {:ok, :no_return}
      end
    end
  end

  defp build_check_all_function(function, member, _) do
    fn args ->
      try do
        return_type = apply(function, args)

        if member.(return_type) do
          {:ok, nil}
        else
          {:error, {args, return_type}}
        end
      rescue
        _ ->
          {:ok, nil}
      end
    end
  end

  defp pick_type_from_beam(module, name, args) do
    type = for pair = {^name, _type} <- beam_types(module), do: pair

    case type do
      [] ->
        raise ArgumentError,
              "Module #{inspect(module)} does not define type #{name}/#{length(args)}."

      types when is_list(types) ->
        types
        |> pick_type(args)
    end
  end

  defp read_function_spec(module, name, arity) do
    with {^module, beam, _file} <- :code.get_object_code(module),
         {:ok, {^module, [abstract_code: {:raw_abstract_v1, abstract_code}]}} <-
           :beam_lib.chunks(beam, [:abstract_code]) do
      spec =
        for {:attribute, _line, :spec, {{^name, ^arity}, value}} <- abstract_code,
            do: Enum.map(value, &inline_bounded_vars/1)

      case spec do
        [] ->
          raise ArgumentError, """
          Missing type specification for function: &#{inspect(module)}.#{name}/#{arity}
          Are you sure you have the right function name and arity?
          """

        [spec] ->
          spec
      end
    else
      _ ->
        msg = """
        Could not find .beam file for Module #{inspect(module)}.
        Are you sure you have passed in the correct module name?
        """

        raise ArgumentError, msg
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

  defp validate_generators([]), do: :ok
  defp validate_generators([%StreamData{} | rest]), do: validate_generators(rest)

  defp validate_generators(argument) do
    raise ArgumentError, """
    Expected a StreamData generator, got #{inspect(argument)}.

    Try passing in a list of StreamData generators:
        - from_type(YourModule, function_name, [StreamData.integer()])
    """
  end

  defp validate_functions([]), do: :ok
  defp validate_functions([fun | rest]) when is_function(fun, 1), do: validate_functions(rest)

  defp validate_functions(argument) do
    raise ArgumentError, """
    Expected a member function, got #{inspect(argument)}.

    Try passing in a list of member functions:
        - validator_from_type(YourModule, type_name, [&is_integer/1])
    """
  end

  defp validate_arguments([]), do: :ok

  defp validate_arguments([{%StreamData{}, fun} | rest]) when is_function(fun, 1),
    do: validate_arguments(rest)

  defp validate_arguments(argument) do
    raise ArgumentError, """
    Expected a StreamData generator, got #{inspect(argument)}.

    Try passing in a list of tuples of StreamData generators and type member functions:
        - from_type(YourModule, type_name, [{StreamData.integer(), &is_integer/1}])
    """
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
  defp map_user_type_to_leaf(%StreamData{} = type, _leaf), do: type

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
      from_type(module, type, Enum.map(args, &generate/1))
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

  defp generate({:ann_type, _, [{:var, _, _name}, type]}), do: generate(type)

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

  # Handle recursive/unions here
  defp validator_for({name, {:type, _, :union, args}}) do
    {nodes, leaves} = nodes_and_leaves(name, args)

    is_leaf =
      Enum.map(leaves, &validator_for_type/1)
      |> is_one_of()

    case nodes do
      [] ->
        is_leaf

      nodes ->
        validator_for_recursive(nodes, is_leaf)
    end
  end

  defp validator_for({name, type}) do
    if recursive_without_union?(type, name) do
      is_leaf =
        rewrite_recursive_type(type, name)
        |> validator_for_type

      validator_for_recursive([type], is_leaf)
    else
      validator_for_type(type)
    end
  end

  defp validator_for_recursive(nodes, is_leaf) do
    is_node = fn member ->
      fn term ->
        if is_leaf.(term) do
          true
        else
          is_node =
            nodes
            |> Enum.map(&map_user_type_to_is_node(&1, member.(member)))
            |> Enum.map(&validator_for_type(&1))
            |> is_one_of

          is_node.(term)
        end
      end
    end

    is_node.(is_node)
  end

  defp map_user_type_to_is_node({:user_type, _line, _name, _args}, is_node), do: is_node

  defp map_user_type_to_is_node({:type, line, type, args}, is_node) do
    args = Enum.map(args, &map_user_type_to_is_node(&1, is_node))
    {:type, line, type, args}
  end

  defp map_user_type_to_is_node({_, _, _l} = type, _is_node), do: type

  defp map_user_type_to_is_node(is_node, _leaf) when is_function(is_node, 1), do: is_node

  defp validator_for_type(validator) when is_function(validator, 1) do
    validator
  end

  defp validator_for_type({:type, _, type, _}) when type in [:any, :term] do
    fn _x -> true end
  end

  defp validator_for_type({:type, _, :atom, _}) do
    &is_atom/1
  end

  defp validator_for_type({:type, _, type, _}) when type in [:none, :no_return] do
    & &1
  end

  defp validator_for_type({:type, _, :pid, _}) do
    &is_pid/1
  end

  defp validator_for_type({:type, _, :port, _}) do
    &is_port/1
  end

  defp validator_for_type({:type, _, :integer, _}) do
    &is_integer/1
  end

  defp validator_for_type({:type, _, :pos_integer, _}) do
    compose([&is_integer/1, &(&1 > 0)])
  end

  defp validator_for_type({:type, _, :neg_integer, _}) do
    compose([&is_integer/1, &(&1 < 0)])
  end

  defp validator_for_type({:type, _, :non_neg_integer, _}) do
    compose([&is_integer/1, &(&1 >= 0)])
  end

  defp validator_for_type({:type, _, :float, _}) do
    &is_float/1
  end

  defp validator_for_type({:type, _, :reference, _}) do
    &is_reference/1
  end

  defp validator_for_type({:type, _, :tuple, :any}) do
    &is_tuple/1
  end

  defp validator_for_type({:type, _, :tuple, []}) do
    &(&1 == {})
  end

  defp validator_for_type({:type, _, :tuple, types}) do
    validators =
      types
      |> Enum.map(&validator_for_type/1)

    tuple_element_count = length(validators)

    fn
      x when is_tuple(x) and tuple_size(x) == tuple_element_count ->
        x
        |> Tuple.to_list()
        |> Enum.zip(validators)
        |> Enum.all?(fn {member, fun} ->
          fun.(member)
        end)

      _ ->
        false
    end
  end

  defp validator_for_type({:type, _, :list, []}) do
    &is_list/1
  end

  defp validator_for_type({:type, _, :list, [type]}) do
    member = validator_for_type(type)

    &(is_list(&1) && Enum.all?(&1, member))
  end

  defp validator_for_type({:type, _, nil, []}) do
    &(&1 === [])
  end

  defp validator_for_type({:type, _, :nonempty_list, []}) do
    compose([&(&1 != []), &is_list/1])
  end

  defp validator_for_type({:type, _, :nonempty_list, [type]}) do
    member = validator_for_type(type)

    &(&1 != [] && is_list(&1) && Enum.all?(&1, member))
  end

  defp validator_for_type({:type, _, :maybe_improper_list, []}) do
    any = &is_any/1

    &is_improper_list(&1, any, any)
  end

  defp validator_for_type({:type, _, :maybe_improper_list, [type1, type2]}) do
    head_fun = validator_for_type(type1)
    member_fun = validator_for_type(type2)

    tail_fun = is_one_of([head_fun, member_fun])

    &is_improper_list(&1, head_fun, tail_fun)
  end

  defp validator_for_type({:type, _, :nonempty_improper_list, [type1, type2]}) do
    head_fun = validator_for_type(type1)
    member_fun = validator_for_type(type2)

    tail_fun = is_one_of([head_fun, member_fun])

    compose([&(&1 != []), &is_improper_list(&1, head_fun, tail_fun)])
  end

  defp validator_for_type({:type, _, :nonempty_maybe_improper_list, []}) do
    any = &is_any/1

    compose([&(&1 != []), &is_improper_list(&1, any, any)])
  end

  defp validator_for_type({:type, _, :nonempty_maybe_improper_list, [type1, type2]}) do
    head_fun = validator_for_type(type1)
    member_fun = validator_for_type(type2)

    tail_fun = is_one_of([head_fun, member_fun])

    &is_improper_list(&1, head_fun, tail_fun)
  end

  defp validator_for_type({:type, _, :map, :any}) do
    &is_map/1
  end

  defp validator_for_type({:type, _, :map, []}) do
    &(&1 == %{})
  end

  defp validator_for_type({:type, _, :map, field_types}) do
    functions = field_types |> Enum.map(&validate_map_field/1)

    exact = for {:exact, f} <- functions, do: f

    general = for {:general, f} <- functions, do: f
    general = compose(general)

    fn
      x when is_map(x) ->
        map =
          Enum.reduce(exact, x, fn current, acc ->
            current.(acc)
          end)

        if is_map(map) do
          general.(map)
        else
          false
        end

      _ ->
        false
    end
  end

  defp validator_for_type({type, _, literal}) when type in [:atom, :integer] do
    &(&1 == literal)
  end

  defp validator_for_type({:type, _, :range, [{:integer, _, lower}, {:integer, _, upper}]}) do
    compose([&is_integer/1, &(&1 in lower..upper)])
  end

  defp validator_for_type({:type, _, :binary, [{:integer, _, size}, {:integer, _, unit}]}) do
    case {size, unit} do
      {0, 0} ->
        &(&1 == <<>>)

      {_, _} ->
        fn
          x when is_bitstring(x) and rem(bit_size(x), unit) == size -> true
          _ -> false
        end
    end
  end

  ## Built-in types
  defp validator_for_type({:type, _, :arity, []}) do
    compose([&is_integer/1, &(&1 in 0..255)])
  end

  defp validator_for_type({:type, _, :boolean, []}) do
    &is_boolean/1
  end

  defp validator_for_type({:type, _, :byte, []}) do
    &(&1 in 0..255)
  end

  defp validator_for_type({:type, _, :char, []}) do
    &(&1 in 0..0x10FFFF)
  end

  defp validator_for_type({:type, _, :bitstring, []}) do
    &is_bitstring/1
  end

  defp validator_for_type({:type, _, :binary, []}) do
    &is_binary/1
  end

  # Note: This is the type we call charlist()
  defp validator_for_type({:type, _, :string, []}) do
    is_char = compose([&is_integer/1, &(&1 in 0..0x10FFFF)])

    fn
      x when is_list(x) -> Enum.all?(x, is_char)
      _ -> false
    end
  end

  defp validator_for_type({:type, _, :nonempty_string, []}) do
    is_char = compose([&is_integer/1, &(&1 in 0..0x10FFFF)])

    fn
      [] -> false
      x when is_list(x) -> Enum.all?(x, is_char)
      _ -> false
    end
  end

  defp validator_for_type({:remote_type, _, [{:atom, _, module}, {:atom, _, type}, args]}) do
    type_validator_for(module, type, Enum.map(args, &validator_for_type/1))
  end

  defp validator_for_type({:type, _, :iolist, []}) do
    &is_iolist/1
  end

  defp validator_for_type({:type, _, :iodata, []}) do
    is_one_of([&is_binary/1, &is_iolist/1])
  end

  defp validator_for_type({:type, _, :mfa, []}) do
    fn
      {m, f, a} ->
        is_atom(m) && is_atom(f) && a in 0..255

      _ ->
        false
    end
  end

  defp validator_for_type({:type, _, x, []}) when x in [:module, :node] do
    &is_atom/1
  end

  defp validator_for_type({:type, _, :number, []}) do
    &is_number/1
  end

  defp validator_for_type({:type, _, :timeout, []}) do
    is_one_of([
      &(&1 == :infinity),
      compose([&is_integer/1, &(&1 >= 0)])
    ])
  end

  defp validator_for_type({:type, _, :union, types}) do
    types
    |> Enum.map(&validator_for_type/1)
    |> is_one_of
  end

  defp validator_for_type({:ann_type, _, [{:var, _, _name}, type]}), do: validator_for_type(type)

  defp char() do
    integer(0..0x10FFFF)
  end

  defp non_negative_integer() do
    map(integer(), &abs/1)
  end

  defp validate_map_field({:type, _, :map_field_exact, [{_, _, key}, value]}) do
    member = validator_for_type(value)

    has_key = fn
      %{^key => value} = x -> member.(value) && Map.delete(x, key)
      _ -> false
    end

    {:exact, has_key}
  end

  defp validate_map_field({:type, _, :map_field_exact, [key, value]}) do
    key_fun = validator_for_type(key)
    value_fun = validator_for_type(value)

    member = fn
      x when x == %{} -> false
      x when is_map(x) -> Enum.all?(x, fn {k, v} -> key_fun.(k) && value_fun.(v) end)
      _ -> false
    end

    {:general, member}
  end

  defp validate_map_field({:type, _, :map_field_assoc, [key, value]}) do
    key_fun = validator_for_type(key)
    value_fun = validator_for_type(value)

    member = fn
      x when x == %{} -> true
      x when is_map(x) -> Enum.any?(x, fn {k, v} -> key_fun.(k) && value_fun.(v) end)
      _ -> false
    end

    {:general, member}
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

  defp compose([f]) when is_function(f, 1), do: f

  defp compose(functions) do
    fn x -> Enum.all?(functions, & &1.(x)) end
  end

  defp is_one_of([f]) when is_function(f, 1), do: f

  defp is_one_of(functions) do
    fn x -> Enum.any?(functions, & &1.(x)) end
  end

  defp is_improper_list([], _head_fun, _tail_fun), do: true

  defp is_improper_list([elem], _head_fun, tail_fun) do
    tail_fun.(elem)
  end

  defp is_improper_list([head | tail], head_fun, tail_fun) do
    head_fun.(head) &&
      if is_list(tail) do
        is_improper_list(tail, head_fun, tail_fun)
      else
        tail_fun.(tail)
      end
  end

  defp is_improper_list(_x, _head_fun, _tail_fun), do: false

  defp is_iolist([]), do: true
  defp is_iolist(x) when is_binary(x), do: true
  defp is_iolist([x | xs]) when x in 0..255, do: is_iolist(xs)
  defp is_iolist([x | xs]) when is_binary(x), do: is_iolist(xs)

  defp is_iolist([x | xs]) do
    is_iolist(x) && is_iolist(xs)
  end

  defp is_iolist(_), do: false

  defp is_any(_), do: true

  defp has_no_return?({:type, _, type, []}) when type in [:none, :no_return], do: true

  defp has_no_return?({:type, _, _, args}) when is_list(args), do: has_no_return?(args)

  defp has_no_return?({:user_type, _, _, args}), do: has_no_return?(args)

  defp has_no_return?({:remote_type, _, [_module, _name, args]}), do: has_no_return?(args)

  defp has_no_return?(types) when is_list(types) do
    types
    |> Enum.any?(&has_no_return?/1)
  end

  defp has_no_return?(_), do: false

  defp inline_bounded_vars({:type, _, :fun, [{:type, _, :product, argument_types}, return_type]}),
    do: {argument_types, return_type}

  defp inline_bounded_vars(
         {:type, _, :bounded_fun,
          [{:type, _, :fun, [{:type, _, :product, argument_types}, return_type]}, constraints]}
       ) do
    variables =
      for {:type, _, :constraint, [_, [{:var, _, name}, type]]} <- constraints, do: {name, type}

    {
      Enum.map(argument_types, &bind_vars(&1, variables)),
      bind_vars(return_type, variables)
    }
  end

  defp bind_vars({:var, _, name}, variables) do
    variables[name]
  end

  defp bind_vars({:type, line, type, args}, variables) do
    {:type, line, type, bind_vars(args, variables)}
  end

  defp bind_vars({:user_type, line, type, args}, variables) do
    {:user_type, line, type, bind_vars(args, variables)}
  end

  defp bind_vars({:remote_type, line, [module, name, args]}, variables) do
    {:remote_type, line, [module, name, bind_vars(args, variables)]}
  end

  defp bind_vars(types, variables) when is_list(types) do
    types
    |> Enum.map(&bind_vars(&1, variables))
  end

  defp bind_vars(t, _variables), do: t

  defp expand_user_type({:user_type, _, name, args}, module) do
    from_type(module, name, Enum.map(args, &expand_user_type(&1, module)))
  end

  defp expand_user_type(type, _module), do: generate(type)

  defp expand_user_validator({:user_type, _, name, args}, module) do
    type_validator_for(module, name, Enum.map(args, &expand_user_validator(&1, module)))
  end

  defp expand_user_validator(type, _module), do: validator_for_type(type)
end

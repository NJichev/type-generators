defmodule StreamDataTypes do
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
  def from_type(module, name, args \\ []) when is_atom(module) and is_atom(name) and is_list(args) do
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
  defp generate_from_type(type, _args) do
    type
  end
end

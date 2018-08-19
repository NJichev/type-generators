defmodule StreamDataTest.Functions do
  @type t(a) :: a
  @type dict(a) :: {atom(), a}

  @spec test_no_return(any) :: any | no_return
  def test_no_return(x) when is_integer(x) do
    raise ArgumentError
  end

  def test_no_return(x), do: x

  @spec test_names(year :: integer, month :: integer, day :: integer) :: integer
  def test_names(year, month, day), do: year + month + day

  @spec test_guards(arg) :: [arg] when arg: atom
  def test_guards(x), do: [x]

  @spec test_multiple_guards(x, y, z) :: {x, y, z} when x: integer, y: atom, z: float
  def test_multiple_guards(x, y, z), do: {x, y, z}

  @spec test_overloaded_spec(integer) :: atom
  def test_overloaded_spec(x) when is_integer(x), do: :foo
  @spec test_overloaded_spec(atom) :: integer
  def test_overloaded_spec(x) when is_atom(x), do: 1

  @spec test_sometime_raise(integer) :: integer
  def test_sometime_raise(x) when x > 0, do: raise("oops")
  def test_sometime_raise(x), do: x

  @spec test_wrong_return(integer) :: integer
  def test_wrong_return(_), do: :foo

  @spec test_overloaded_with_var(x :: integer, y :: integer) :: integer
  def test_overloaded_with_var(x, y) when is_integer(x) and is_integer(y), do: x + y
  @spec test_overloaded_with_var(x :: atom, y :: atom) :: atom
  def test_overloaded_with_var(x, y) when is_atom(x) and is_atom(y), do: x

  @spec test_type_variable(dict(integer)) :: dict(float)
  def test_type_variable({a, int}), do: {a, int / 1}

  @spec test_remote_type(Keyword.t(integer)) :: Keyword.t(integer)
  def test_remote_type(x), do: x

  @spec test_nested_user_types(t(t(integer))) :: t(t(t(integer)))
  def test_nested_user_types(x), do: x
end

defmodule StreamDataTest.Functions do
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

  @spec test_missing_no_return(integer) :: integer
  def test_missing_no_return(x) when x > 0, do: raise("oops")
  def test_missing_no_return(x), do: x

  @spec test_wrong_return(integer) :: integer
  def test_wrong_return(_), do: :foo
end

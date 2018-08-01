defmodule StreamDataTest.Functions do
  @spec test_no_return(any) :: any | no_return
  def test_no_return(x) when is_integer(x) do

  end
  def test_no_return(x), do: x
end

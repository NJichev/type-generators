defmodule StreamDataValidationsList do
  @spec foo(any()) :: boolean()
  def foo(x) when x in [false, nil], do: false
  def foo(_), do: true
end

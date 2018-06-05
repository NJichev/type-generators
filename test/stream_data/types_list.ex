defmodule StreamDataTest.TypesList do
  @type basic_atom :: atom()
  @type basic_none() :: none()

  # Numbers
  @type basic_float() :: float()
  @type basic_integer() :: integer()
  @type basic_neg_integer() :: neg_integer()
  @type basic_non_neg_integer() :: non_neg_integer()
  @type basic_pos_integer() :: pos_integer()

  ##Built-in
  @type builtin_no_return :: no_return()
end

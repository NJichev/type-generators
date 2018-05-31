defmodule StreamDataTest.TypesList do
  @type basic_atom :: atom()

  # Numbers
  @type basic_float() :: float()
  @type basic_integer() :: integer()
  @type basic_neg_integer() :: neg_integer()
  @type basic_non_neg_integer() :: non_neg_integer()
  @type basic_pos_integer() :: pos_integer()

  @type literal_function_arity_1 :: (any() -> integer())
end

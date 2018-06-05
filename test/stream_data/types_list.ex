defmodule StreamDataTest.TypesList do
  @type basic_atom :: atom()

  # Numbers
  @type basic_float() :: float()
  @type basic_integer() :: integer()
  @type basic_neg_integer() :: neg_integer()
  @type basic_non_neg_integer() :: non_neg_integer()
  @type basic_pos_integer() :: pos_integer()

  # Lists
  @type basic_list_type() :: list(integer())
  @type basic_nonempty_list_type() :: nonempty_list(integer())
  @type basic_maybe_improper_list_type() :: maybe_improper_list(integer(), float())
  @type basic_nonempty_improper_list_type() :: nonempty_improper_list(integer(), float())
  @type basic_nonempty_maybe_improper_list_type() ::
          nonempty_maybe_improper_list(integer(), float())

  ## Nested Lists
  @type nested_list_type :: list(list(integer()))
  @type nested_nonempty_list_type :: nonempty_list(list(integer()))
end

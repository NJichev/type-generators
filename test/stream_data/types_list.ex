defmodule StreamDataTest.TypesList do
  @type basic_any() :: any()
  @type basic_atom :: atom()
  @type basic_reference :: reference()
  @type basic_map :: map()

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

  ## Literals
  # Lists
  @type literal_list_type() :: [integer()]
  @type literal_empty_list() :: []
  @type literal_list_nonempty() :: [...]
  @type literal_nonempty_list_type() :: [float(), ...]
  @type literal_keyword_list_fixed_key() :: [key: integer()]
  @type literal_keyword_list_fixed_key2() :: [{:key, integer()}]
  @type literal_keyword_list_type_key() :: [{binary(), integer()}]

  # Map
  @type literal_empty_map() :: %{}
  @type literal_map_with_key() :: %{:key => integer()}
  @type literal_map_with_required_key() :: %{required(float()) => integer()}
  @type literal_map_with_optional_key() :: %{optional(float()) => integer()}
  @type literal_map_with_required_and_optional_key() :: %{:key => integer(), optional(float()) => integer()}

  ## Built-in
  @type builtin_term() :: term()

  # Lists
  @type builtin_list() :: list()
  @type builtin_nonempty_list() :: nonempty_list()
  @type builtin_maybe_improper_list() :: maybe_improper_list()
  @type builtin_nonempty_maybe_improper_list() :: nonempty_maybe_improper_list()

  ## Nested Lists
  @type nested_list_type :: list(list(integer()))
  @type nested_nonempty_list_type :: nonempty_list(list(integer()))
end
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

  ## Literals
  # Map
  @type literal_empty_map() :: %{}
  @type literal_map_with_key() :: %{:key => integer()}
  @type literal_map_with_required_key() :: %{required(float()) => integer()}
  @type literal_map_with_optional_key() :: %{optional(float()) => integer()}
  @type literal_map_with_required_and_optional_key() :: %{:key => integer(), optional(float()) => integer()}

  ## Built-in
  @type builtin_term() :: term()
end
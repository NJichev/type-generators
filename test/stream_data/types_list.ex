defmodule StreamDataTest.TypesList do
  defmodule SomeStruct do
    defstruct [:key]
  end

  ## Basic
  @type basic_any() :: any()
  @type basic_atom :: atom()
  @type basic_none() :: none()
  @type basic_reference :: reference()
  @type basic_tuple() :: tuple()
  @type basic_map :: map()
  @type basic_struct :: struct()
  @type basic_pid :: pid()
  @type basic_port :: port()

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
  @type literal_atom() :: :atom
  @type literal_special_atom() :: false
  @type literal_integer() :: 1
  @type literal_integers() :: 1..10
  @type literal_empty_bitstring() :: <<>>
  @type literal_size_0() :: <<_::0>>
  @type literal_unit_1() :: <<_::_*1>>
  @type literal_size_1_unit_8() :: <<_::1, _::_*8>>

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
  @type literal_map_with_required_and_optional_key() :: %{
          :key => integer(),
          optional(float()) => integer()
        }
  @type literal_struct_all_fields_any_type() :: %SomeStruct{}
  @type literal_struct_all_fields_key_type() :: %SomeStruct{key: integer()}

  # Tuple
  @type literal_empty_tuple() :: {}
  @type literal_2_element_tuple() :: {integer(), float()}

  ## Built-in
  @type builtin_term() :: term()
  @type builtin_no_return :: no_return()
  @type builtin_arity() :: arity()
  @type builtin_binary() :: binary()
  @type builtin_bitstring() :: bitstring()
  @type builtin_boolean() :: boolean()
  @type builtin_byte() :: byte()
  @type builtin_char() :: char()
  @type builtin_charlist :: charlist()
  @type builtin_nonempty_charlist() :: nonempty_charlist()
  @type builtin_iodata() :: iodata()
  @type builtin_iolist() :: iolist()
  @type builtin_mfa() :: mfa()
  @type builtin_module() :: module()
  @type builtin_node() :: node()
  @type builtin_number() :: number()
  @type builtin_timeout() :: timeout()

  # Lists
  @type builtin_list() :: list()
  @type builtin_nonempty_list() :: nonempty_list()
  @type builtin_maybe_improper_list() :: maybe_improper_list()
  @type builtin_nonempty_maybe_improper_list() :: nonempty_maybe_improper_list()

  ## Nested Lists
  @type nested_list_type :: list(list(integer()))
  @type nested_nonempty_list_type :: nonempty_list(list(integer()))
end

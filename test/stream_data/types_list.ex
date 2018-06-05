defmodule StreamDataTest.TypesList do
  @type basic_atom :: atom()

  # Numbers
  @type basic_float() :: float()
  @type basic_integer() :: integer()
  @type basic_neg_integer() :: neg_integer()
  @type basic_non_neg_integer() :: non_neg_integer()
  @type basic_pos_integer() :: pos_integer()

  ## Builti-in
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
end

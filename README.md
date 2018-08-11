# Type Generators

This is my google summer of code project for stream data creating
StreamData generators out of type specifications, generating type
member functions and validating function specifications.

You will be able to check out progress and play around with this
repository.

## Installation

To test things out add - add it to your `mix.exs` file as a dependency.

```elixir
def deps do
  [
    {:type_generators, git: "https://github.com/njichev/type-generators"}
  ]
end
```

## Quick start

Add a module with some types in it:

```
defmodule MyModule do
  @type t :: {atom(), integer()}
end
```

Create a generator out of your type:

```
StreamDataTypes.from_type(MyModule, :t) |> Enum.take(3)
#=> [f: -1, wn: 2, DM: 0]
```

You can also generate the member function for your type:

```
member = StreamDataTypes.validator_for_type(MyModule, :t)

member.({:f, -1})
#=> true

member.({1, -1})
#=> false
```

Validate function type specifications using `validate/3`:

```
{:ok, %{}} = validate(Kernel, :is_integer, 1)
```

We can see that the `&String.to_integer/1` type specification fails
for `""` as input.

```
{:error, metadata} = validate(String, :to_integer, 1)
```

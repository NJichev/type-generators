# TypeGenerators

This is my google summer of code project for stream data creating generators
out of type specifications. You will be able to check out progress and play
around with this repository.

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

StreamDataTypes.from_type(MyModule, :t) |> Enum.take(3)
#=> [f: -1, wn: 2, DM: 0]
```

## Progress

Here I'll be tracking my progress.

### Week 1

For week 1 I implemented part of the basic types, you can check this [branch out](https://github.com/NJichev/stream_data/blob/a11fea181986e5cc26920e33a25ea88484857476/lib/stream_data/types.ex).
You can check the test suite to check out all basic types or the all_types file to look at all the supported basic types implemented.

### Week 2

Setup this current project - easier work flow and more independent small branches can be reviewed at a time.
Start merging progress from week 1.
Work on recursive/union types and generating functions(mostly R&D).
[Check this commit](https://github.com/NJichev/stream_data/commit/a11fea181986e5cc26920e33a25ea88484857476)
and [this branch](https://github.com/NJichev/stream_data/tree/storm-recursives)


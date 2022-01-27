defmodule Statechart.Util.Inspect do
  @moduledoc """
  Functions for building more readable output with using `IO.inspect/2` and `IO.inspect/3`.
  """

  alias Inspect.Algebra

  @doc """
  Build a custom representation of a key-value data structure.
  Given the arguments "MyStruct" and [first: 1, second: 2],
  will build an algebra document that looks something like this
  when using `IO.inspect/2`:
  `#MyStruct<first: 1, second: 2>`
  """
  @spec custom_kv(String.t(), keyword(), Inspect.Opts.t()) :: Algebra.t()
  def custom_kv(name, fields, opts) when is_list(fields) do
    open = Algebra.color("##{name}<", :map, opts)
    sep = Algebra.color(",", :map, opts)
    close = Algebra.color(">", :map, opts)
    fun = fn {key, value}, opts -> Inspect.List.keyword({key, value}, opts) end
    Algebra.container_doc(open, fields, close, opts, fun, separator: sep, break: :strict)
  end

  @doc """
  Example usage:
      defmodule MyModule do
        use Redline.Util.Inspect, name: "CoolStruct", keys: ~w/third first/a
        defstruct [:first, :second, :third]
      end
  When inspected, will look something like:
      #CoolStruct<third: 3, first: 1>
  options:
  - `name` - optional. Defaults to last part of module name.
  - `keys` - optional. Defaults to all keys
  """
  defmacro __using__(using_opts) do
    quote do
      defimpl Inspect do
        def inspect(%_{} = struct, inspect_opts) do
          unquote(__MODULE__).__inspect__(struct, inspect_opts, unquote(using_opts))
        end
      end
    end
  end

  @doc false
  def __inspect__(%module{} = struct, inspect_opts, using_opts) do
    name = using_opts[:name] || module |> Module.split() |> List.last()

    fields =
      if keys = using_opts[:keys] do
        Enum.map(keys, fn key -> {key, Map.fetch!(struct, key)} end)
      else
        struct |> Map.from_struct() |> Enum.into([])
      end

    custom_kv(name, fields, inspect_opts)
  end
end

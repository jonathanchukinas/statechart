defmodule Statechart.Util.GetterStructPlugin do
  @moduledoc false

  use TypedStruct.Plugin

  @impl true
  def field(name, _type, _opts) do
    quote do
      def unquote(name)(%{unquote(name) => value}) do
        value
      end
    end
  end
end

defmodule Statechart.Util.GetterStruct do
  @moduledoc """
  Expose the `getter_struct/2` macro.
  """

  defmacro __using__(_) do
    quote do
      require unquote(__MODULE__)
      import unquote(__MODULE__)
    end
  end

  @doc """
  Generate an enforced `TypedStruct` with getter function for each field.

  Example:
  ```elixir
  defmodule MyModule do
    use Statechart.Util.GetterStruct
    getter_struct do
      field :hello, String.t
      field :world, String.t, enforce: false
    end
  end
  ```

  Translates to:
  ```elixir
  defmodule MyModule do
    use TypedStruct
    typedstruct, enforce: true do
      field :hello, String.t
      field :world, String.t, enforce: false
    end

    def hello(%__MODULE__{hello: value}), do: value
    def world(%__MODULE__{world: value}), do: value
  end
  ```
  """
  defmacro getter_struct(opts \\ [], do: block) do
    new_opts = Keyword.put_new(opts, :enforce, true)

    quote do
      use TypedStruct

      typedstruct unquote(new_opts) do
        # TODO is this unquote necessary?
        plugin(unquote(Statechart.Util.GetterStructPlugin))
        unquote(block)
      end
    end
  end
end

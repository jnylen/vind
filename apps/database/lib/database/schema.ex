defmodule Database.Schema do
  @moduledoc """
  Ecto Schema Module
  """

  defmacro __using__(_) do
    quote do
      use Ecto.Schema
      use Formex.Ecto.Schema
      @primary_key {:id, :binary_id, autogenerate: true}
      @foreign_key_type :binary_id
    end
  end
end

defmodule Database.Translation.Category do
  @moduledoc """
  Category translations between non-standard names to standardized names.
  """

  use Database.Schema
  import Ecto.Changeset

  @program_types [
    "movie",
    "series",
    "sports",
    "sports_event"
  ]

  schema "translations_category" do
    field(:type, :string)
    field(:original, :string)
    field(:category, {:array, :string}, default: [])
    field(:program_type, :string)

    timestamps()
  end

  def changeset(category, params \\ %{}) do
    category
    |> cast(params, [
      :type,
      :original,
      :category,
      :program_type
    ])
    |> validate_required([:type, :original])
    |> validate_inclusion(:program_type, @program_types)

    # |> validate_schema_types
  end
end
